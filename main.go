package main

import (
	"archive/zip"
	"crypto/sha256"
	"embed"
	"encoding/json"
	"fmt"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/energye/systray"
	"github.com/ncruces/zenity"
	bolt "go.etcd.io/bbolt"
)

//go:embed frontend/dist/*
var frontendFS embed.FS

// ── Models ───────────────────────────────────────────────────────────────────

type Settings struct {
	GlobalBackupDir            string `json:"global_backup_dir"`
	UseProjectSubfolderDefault bool   `json:"use_project_subfolder_default"`
}

type Project struct {
	Name                 string            `json:"name"`
	Source               string            `json:"source"`
	Destination          string            `json:"destination"`
	Version              int               `json:"version"`
	Limit                int               `json:"limit"`
	UseGlobalDestination bool              `json:"use_global_destination"`
	UseProjectSubfolder  bool              `json:"use_project_subfolder"`
	ExclusionRules       string            `json:"exclusion_rules"`
	ContentHash          string            `json:"content_hash,omitempty"`
	LastBackup           string            `json:"last_backup,omitempty"`
	LastZipName          string            `json:"last_zip_name,omitempty"`
	BackupHashes         map[string]string `json:"backup_hashes,omitempty"`
}

type AppData struct {
	Version  int       `json:"version"`
	Settings Settings  `json:"settings"`
	Projects []Project `json:"projects"`
}

// ── Globals ──────────────────────────────────────────────────────────────────

const SchemaVersion = 2
const Port = 2468

var db *bolt.DB
var dbPath string
var logger *log.Logger
var logFile *os.File                                 // Global log file handle to allow clean closing onExit
var sanitizeRegexp = regexp.MustCompile(`[^\w\-_ ]`) // Compiled once for performance

// Concurrency globals
var dataMutex sync.Mutex // Mutex protecting load-modify-save state sequences

// Tray globals
var trayMutex sync.Mutex
var quickBackupMenu *systray.MenuItem
var projectMenuItems = make(map[string]*systray.MenuItem)

//go:embed icon.ico
var iconIcoBytes []byte

const defaultExclusionRules = "*.bak, *.orig, *.log, *.etl, *.evtx, *.cache, *.autosave, thumbs.db, desktop.ini, .DS_Store, .git, node_modules, .idea, .vscode, vendor, .venv"

// ── Helpers ──────────────────────────────────────────────────────────────────

// Prefix long paths with extended-length marker for Windows compatibility
func longPath(p string) string {
	if len(p) >= 240 && !strings.HasPrefix(p, `\\?\`) {
		if abs, err := filepath.Abs(p); err == nil {
			return `\\?\` + abs
		}
		return `\\?\` + p
	}
	return p
}

// Sanitize all special PowerShell characters to prevent command injection
func sanitizePowerShell(s string) string {
	s = strings.ReplaceAll(s, "'", "''")
	s = strings.ReplaceAll(s, "`", "``")
	s = strings.ReplaceAll(s, "$", "`$")
	s = strings.ReplaceAll(s, ";", "`;")
	s = strings.ReplaceAll(s, "|", "`|")
	s = strings.ReplaceAll(s, "(", "`(")
	s = strings.ReplaceAll(s, ")", "`)")
	return s
}

func init() {
	execPath, err := os.Executable()
	var dir string
	if err != nil {
		dir = "."
	} else {
		dir = filepath.Dir(execPath)
	}
	dbPath = filepath.Join(dir, "friday.db")

	var logErr error
	logFile, logErr = os.OpenFile(longPath(filepath.Join(dir, "friday.log")), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if logErr == nil {
		logger = log.New(logFile, "Friday: ", log.LstdFlags)
	} else {
		logger = log.New(os.Stdout, "Friday: ", log.LstdFlags)
	}

	db, err = bolt.Open(longPath(dbPath), 0600, &bolt.Options{Timeout: 2 * time.Second})
	if err != nil {
		logger.Fatalf("Failed to open database: %v", err)
	}

	err = db.Update(func(tx *bolt.Tx) error {
		_, err := tx.CreateBucketIfNotExists([]byte("FridayBucket"))
		return err
	})
	if err != nil {
		logger.Fatalf("Failed to create bucket: %v", err)
	}
}

func loadData() AppData {
	var data AppData
	_ = db.View(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("FridayBucket"))
		if b == nil {
			return nil
		}
		val := b.Get([]byte("app_state"))
		if val != nil {
			_ = json.Unmarshal(val, &data)
		}
		return nil
	})

	if data.Version == 0 {
		data.Version = SchemaVersion
	}
	if data.Projects == nil {
		data.Projects = []Project{}
	}
	for idx := range data.Projects {
		if data.Projects[idx].BackupHashes == nil {
			data.Projects[idx].BackupHashes = make(map[string]string)
		}
	}
	return data
}

func saveData(data AppData) error {
	bytes, err := json.Marshal(data)
	if err != nil {
		logger.Printf("Failed to marshal AppData: %v", err)
		return err
	}

	return db.Update(func(tx *bolt.Tx) error {
		b := tx.Bucket([]byte("FridayBucket"))
		if b == nil {
			return fmt.Errorf("bucket not found")
		}
		return b.Put([]byte("app_state"), bytes)
	})
}

func sanitizeFilename(name string) string {
	sanitized := sanitizeRegexp.ReplaceAllString(name, "_")
	sanitized = strings.ReplaceAll(sanitized, " ", "_")
	sanitized = strings.Trim(sanitized, "_.-")
	if sanitized == "" {
		return "project"
	}
	return sanitized
}

func resolveDestination(proj Project, settings Settings) string {
	var base string
	if proj.UseGlobalDestination && settings.GlobalBackupDir != "" {
		base = settings.GlobalBackupDir
	} else {
		base = proj.Destination
	}

	if proj.UseProjectSubfolder && base != "" {
		return filepath.Join(base, sanitizeFilename(proj.Name))
	}
	return base
}

func formatTimestamp(t time.Time) string {
	return t.Format("02 Jan, 2006 03:04 PM")
}

// ── Exclusion & Active Scan Logic ─────────────────────────────────────────────

func parseExclusionRules(rulesStr string) []string {
	var patterns []string
	parts := strings.FieldsFunc(rulesStr, func(c rune) bool {
		return c == '\n' || c == ','
	})
	for _, p := range parts {
		clean := strings.TrimSpace(p)
		if clean != "" {
			patterns = append(patterns, clean)
		}
	}
	return patterns
}

func isPathExcluded(relPath string, patterns []string) bool {
	slashPath := filepath.ToSlash(relPath)
	parts := strings.Split(slashPath, "/")
	for _, pattern := range patterns {
		cleanPattern := filepath.ToSlash(strings.TrimSpace(pattern))
		if cleanPattern == "" {
			continue
		}

		if strings.HasSuffix(cleanPattern, "/") {
			dirPattern := strings.TrimSuffix(cleanPattern, "/")
			if slashPath == dirPattern || strings.HasPrefix(slashPath, dirPattern+"/") {
				return true
			}
		}

		match, _ := filepath.Match(cleanPattern, slashPath)
		if match {
			return true
		}
		for _, part := range parts {
			partMatch, _ := filepath.Match(cleanPattern, part)
			if partMatch {
				return true
			}
			if part == cleanPattern {
				return true
			}
		}
	}
	return false
}

func isFileActive(name string, modTime time.Time) (bool, string) {
	lowerName := strings.ToLower(name)

	if strings.HasPrefix(lowerName, "~$") {
		return true, "Microsoft Office temporary file detected"
	}

	if strings.HasPrefix(lowerName, "#") && strings.HasSuffix(lowerName, "#") {
		return true, "Auto-save temporary file detected"
	}

	if strings.HasPrefix(lowerName, ".~lock.") {
		return true, "Open file lock detected"
	}

	suffixes := []string{
		".db-wal", ".db-shm", ".db-journal", ".db-wal2",
		".crdownload", ".part", ".download", ".opdownload", ".partial",
		".lock", ".lck", ".lockfile", ".flock",
		".tmp", ".temp",
		".swp", ".swo",
		".staging", ".unpacked", ".extracting",
		".rendering",
	}

	for _, suff := range suffixes {
		if strings.HasSuffix(lowerName, suff) {
			return true, "Temporary database or lock file detected"
		}
	}

	if time.Since(modTime) < 15*time.Second {
		return true, "Recently modified file detected"
	}

	return false, ""
}

func scanProject(srcPath string, rules string) (int64, int, bool, string, string, error) {
	size, count, hasActive, activeReason, currentHash, _, err := buildProjectSnapshot(srcPath, rules, "")
	return size, count, hasActive, activeReason, currentHash, err
}

func buildProjectSnapshot(srcPath string, rules string, lastZipPath string) (int64, int, bool, string, string, []map[string]interface{}, error) {
	info, err := os.Stat(longPath(srcPath))
	if err != nil {
		return 0, 0, false, "", "", nil, err
	}

	hasher := sha256.New()
	var size int64
	var count int
	var hasActive bool
	var activeReason string

	if !info.IsDir() {
		hasActive, activeReason = isFileActive(info.Name(), info.ModTime())
		file, err := os.Open(longPath(srcPath))
		if err == nil {
			defer file.Close()
			_, _ = io.Copy(hasher, file)
		}
		files := []map[string]interface{}{{
			"path":     filepath.Base(srcPath),
			"size":     info.Size(),
			"mod_time": info.ModTime().Unix(),
			"status":   "included",
		}}
		if hasActive {
			files[0]["active"] = true
			files[0]["active_reason"] = activeReason
		}
		return info.Size(), 1, hasActive, activeReason, fmt.Sprintf("%x", hasher.Sum(nil)), files, nil
	}

	patterns := parseExclusionRules(rules)
	var files []string
	var includedFiles []map[string]interface{}

	_ = filepath.WalkDir(longPath(srcPath), func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return nil
		}
		rel, _ := filepath.Rel(srcPath, path)
		if rel == "." {
			return nil
		}
		if isPathExcluded(rel, patterns) {
			includedFiles = append(includedFiles, map[string]interface{}{
				"path":     filepath.ToSlash(rel),
				"size":     nil,
				"mod_time": int64(0),
				"status":   "skipped",
			})
			if d.IsDir() {
				return filepath.SkipDir
			}
			return nil
		}
		if !d.IsDir() {
			if fileInfo, err := d.Info(); err == nil {
				size += fileInfo.Size()
				count++
				if !hasActive {
					fileActive, fileReason := isFileActive(fileInfo.Name(), fileInfo.ModTime())
					if fileActive {
						hasActive = true
						activeReason = fileReason
					}
				}
				entry := map[string]interface{}{
					"path":     filepath.ToSlash(rel),
					"size":     fileInfo.Size(),
					"mod_time": fileInfo.ModTime().Unix(),
					"status":   "included",
				}
				if fileActive, fileReason := isFileActive(fileInfo.Name(), fileInfo.ModTime()); fileActive {
					entry["active"] = true
					entry["active_reason"] = fileReason
				}
				includedFiles = append(includedFiles, entry)
			}
			files = append(files, rel)
		}
		return nil
	})

	sort.Strings(files)

	for _, rel := range files {
		hasher.Write([]byte(rel))
		func() {
			file, err := os.Open(longPath(filepath.Join(srcPath, rel)))
			if err != nil {
				return
			}
			defer file.Close()
			_, _ = io.Copy(hasher, file)
		}()
	}

	var oldFilesMap = make(map[string]map[string]interface{})
	if lastZipPath != "" {
		if zr, err := zip.OpenReader(longPath(lastZipPath)); err == nil {
			for _, zf := range zr.File {
				if zf.Name == "backup_meta.json" {
					if rc, err := zf.Open(); err == nil {
						var meta map[string]interface{}
						if err := json.NewDecoder(rc).Decode(&meta); err == nil {
							if oldFilesList, ok := meta["files"].([]interface{}); ok {
								for _, fItem := range oldFilesList {
									if fMap, ok := fItem.(map[string]interface{}); ok {
										if pathStr, ok := fMap["path"].(string); ok {
											oldFilesMap[pathStr] = fMap
										}
									}
								}
							}
						}
						rc.Close()
					}
					break
				}
			}
			zr.Close()
		}
	}

	var addedCount int
	var modifiedCount int
	var deletedCount int
	visitedOldFiles := make(map[string]bool)
	for _, currentFile := range includedFiles {
		if currentFile["status"] == "skipped" {
			continue
		}
		relPath, _ := currentFile["path"].(string)
		currentSize, _ := currentFile["size"].(int64)
		currentModTime, _ := currentFile["mod_time"].(int64)
		if oldFile, exists := oldFilesMap[relPath]; exists {
			visitedOldFiles[relPath] = true
			var oldSize int64
			if sizeVal, ok := oldFile["size"].(float64); ok {
				oldSize = int64(sizeVal)
			}
			var oldModTime int64
			if modVal, ok := oldFile["mod_time"].(float64); ok {
				oldModTime = int64(modVal)
			}
			if currentSize != oldSize || currentModTime != oldModTime {
				modifiedCount++
				currentFile["status"] = "modified"
			} else {
				currentFile["status"] = "unchanged"
			}
		} else {
			addedCount++
			currentFile["status"] = "added"
		}
	}
	for oldPath, oldFile := range oldFilesMap {
		if !visitedOldFiles[oldPath] {
			deletedCount++
			oldFile["status"] = "deleted"
			includedFiles = append(includedFiles, oldFile)
		}
	}

	return size, count, hasActive, activeReason, fmt.Sprintf("%x", hasher.Sum(nil)), includedFiles, nil
}

func calculateDestStats(dstPath string, projName string) (int64, int) {
	prefix := fmt.Sprintf("%s_v", sanitizeFilename(projName))
	var size int64
	var count int

	files, err := os.ReadDir(longPath(dstPath))
	if err != nil {
		return 0, 0
	}

	for _, f := range files {
		if !f.IsDir() && strings.HasPrefix(f.Name(), prefix) && strings.HasSuffix(f.Name(), ".zip") {
			if info, err := f.Info(); err == nil {
				size += info.Size()
				count++
			}
		}
	}

	return size, count
}

func checkZipIntegrity(filePath string, originalHash string) (string, string) {
	hasher := sha256.New()
	file, err := os.Open(longPath(filePath))
	if err != nil {
		return "", "corrupted"
	}
	defer file.Close()

	if _, err := io.Copy(hasher, file); err != nil {
		return "", "corrupted"
	}
	currentHash := fmt.Sprintf("%x", hasher.Sum(nil))

	if originalHash != "" {
		if originalHash == currentHash {
			return currentHash, "matching"
		}
		return currentHash, "corrupted"
	}

	zr, err := zip.OpenReader(longPath(filePath))
	if err != nil {
		return currentHash, "corrupted"
	}
	defer zr.Close()

	for _, f := range zr.File {
		rc, err := f.Open()
		if err != nil {
			return currentHash, "corrupted"
		}
		rc.Close()
	}

	return currentHash, "untracked"
}

func syncProjectStateAfterDeletion(proj *Project, settings Settings) {
	dst := resolveDestination(*proj, settings)
	prefix := fmt.Sprintf("%s_v", sanitizeFilename(proj.Name))

	files, err := os.ReadDir(longPath(dst))
	if err != nil {
		proj.Version = 0
		proj.LastBackup = ""
		proj.LastZipName = ""
		proj.ContentHash = ""
		return
	}

	latestVersion := -1
	var latestFile os.DirEntry

	for _, f := range files {
		if f.IsDir() || !strings.HasPrefix(f.Name(), prefix) || !strings.HasSuffix(f.Name(), ".zip") {
			continue
		}

		suffix := strings.TrimSuffix(strings.TrimPrefix(f.Name(), prefix), ".zip")
		parts := strings.Split(suffix, "_")
		if len(parts) > 0 {
			v, err := strconv.Atoi(parts[0])
			if err == nil && v > latestVersion {
				latestVersion = v
				latestFile = f
			}
		}
	}

	if latestVersion == -1 {
		proj.Version = 0
		proj.LastBackup = ""
		proj.LastZipName = ""
		proj.ContentHash = ""
		return
	}

	info, err := latestFile.Info()
	if err != nil {
		proj.Version = latestVersion
		proj.LastBackup = ""
		proj.LastZipName = latestFile.Name()
		proj.ContentHash = ""
		return
	}

	createdLocal := formatTimestamp(info.ModTime())
	zipPath := filepath.Join(dst, latestFile.Name())
	if zr, err := zip.OpenReader(longPath(zipPath)); err == nil {
		for _, zf := range zr.File {
			if zf.Name == "backup_meta.json" {
				if rc, err := zf.Open(); err == nil {
					var meta map[string]interface{}
					if err := json.NewDecoder(rc).Decode(&meta); err == nil {
						if meta["created_local"] != nil {
							if val, ok := meta["created_local"].(string); ok {
								createdLocal = val
							}
						}
					}
					rc.Close()
				}
				break
			}
		}
		zr.Close()
	}

	proj.Version = latestVersion
	proj.LastBackup = createdLocal
	proj.LastZipName = latestFile.Name()
	proj.ContentHash = "" // Force recalculation on next scan
}

func listProjectBackups(proj Project, settings Settings) []map[string]interface{} {
	dst := resolveDestination(proj, settings)
	prefix := fmt.Sprintf("%s_v", sanitizeFilename(proj.Name))
	backups := []map[string]interface{}{}

	files, err := os.ReadDir(longPath(dst))
	if err != nil {
		return backups
	}

	for _, f := range files {
		if f.IsDir() || !strings.HasPrefix(f.Name(), prefix) || !strings.HasSuffix(f.Name(), ".zip") {
			continue
		}

		info, err := f.Info()
		if err != nil {
			continue
		}

		versionVal := 0
		suffix := strings.TrimSuffix(strings.TrimPrefix(f.Name(), prefix), ".zip")
		parts := strings.Split(suffix, "_")
		if len(parts) > 0 {
			versionVal, _ = strconv.Atoi(parts[0])
		}

		createdLocal := formatTimestamp(info.ModTime())
		note := ""
		fileCount := 0
		folderCount := 0
		excludedCount := 0
		addedCount := 0
		modifiedCount := 0
		deletedCount := 0
		var filesList []interface{}

		zipPath := filepath.Join(dst, f.Name())
		if zr, err := zip.OpenReader(longPath(zipPath)); err == nil {
			for _, zf := range zr.File {
				if zf.Name == "backup_meta.json" {
					if rc, err := zf.Open(); err == nil {
						var meta map[string]interface{}
						if err := json.NewDecoder(rc).Decode(&meta); err == nil {
							if meta["created_local"] != nil {
								if val, ok := meta["created_local"].(string); ok {
									createdLocal = val
								}
							}
							if meta["note"] != nil {
								if val, ok := meta["note"].(string); ok {
									note = val
								}
							}
							if val, ok := meta["file_count"].(float64); ok {
								fileCount = int(val)
							}
							if val, ok := meta["folder_count"].(float64); ok {
								folderCount = int(val)
							}
							if val, ok := meta["excluded_count"].(float64); ok {
								excludedCount = int(val)
							}
							if val, ok := meta["added_count"].(float64); ok {
								addedCount = int(val)
							}
							if val, ok := meta["modified_count"].(float64); ok {
								modifiedCount = int(val)
							}
							if val, ok := meta["deleted_count"].(float64); ok {
								deletedCount = int(val)
							}
							if meta["files"] != nil {
								filesList, _ = meta["files"].([]interface{})
							}
						}
						rc.Close()
					}
					break
				}
			}
			zr.Close()
		}

		origHash := ""
		if proj.BackupHashes != nil {
			origHash = proj.BackupHashes[f.Name()]
		}
		zipHash, integrity := checkZipIntegrity(zipPath, origHash)

		backups = append(backups, map[string]interface{}{
			"filename":       f.Name(),
			"version":        versionVal,
			"timestamp":      createdLocal,
			"size":           info.Size(),
			"modified":       createdLocal,
			"note":           note,
			"zip_hash":       zipHash,
			"integrity":      integrity,
			"file_count":     fileCount,
			"folder_count":   folderCount,
			"excluded_count": excludedCount,
			"added_count":    addedCount,
			"modified_count": modifiedCount,
			"deleted_count":  deletedCount,
			"files":          filesList,
		})
	}

	sort.Slice(backups, func(i, j int) bool {
		vI, _ := backups[i]["version"].(int)
		vJ, _ := backups[j]["version"].(int)
		return vI > vJ
	})

	return backups
}

func doBackup(proj *Project, settings Settings, note string) (bool, string, map[string]interface{}) {
	src := strings.TrimSpace(proj.Source)
	dst := resolveDestination(*proj, settings)

	if src == "" {
		return false, "Source path is empty.", nil
	}
	if !filepath.IsAbs(src) {
		return false, "Source path must be an absolute path.", nil
	}
	if dst == "" {
		return false, "Destination path is empty.", nil
	}
	if !filepath.IsAbs(dst) {
		return false, "Destination path must be an absolute path.", nil
	}
	dstParent := filepath.Dir(dst)
	if _, err := os.Stat(longPath(dstParent)); err != nil {
		return false, "Destination drive or parent folder does not exist.", nil
	}

	_, _, _, _, currentHash, err := scanProject(src, proj.ExclusionRules)
	if err != nil {
		return false, "Cannot read source: " + err.Error(), nil
	}
	srcInfo, err := os.Stat(longPath(src))
	if err != nil {
		return false, "Source path is not accessible: " + err.Error(), nil
	}

	zipMissing := false
	if proj.LastZipName != "" {
		if _, err := os.Stat(longPath(filepath.Join(dst, proj.LastZipName))); err != nil {
			zipMissing = true
		}
	}

	if !zipMissing && currentHash == proj.ContentHash {
		return false, "No changes detected, backup skipped.", nil
	}

	_ = os.MkdirAll(longPath(dst), 0755)
	now := time.Now()
	version := proj.Version + 1
	zipName := fmt.Sprintf("%s_v%d_%s.zip", sanitizeFilename(proj.Name), version, now.Format("2006-01-02"))
	zipPath := filepath.Join(dst, zipName)

	zipFile, err := os.Create(longPath(zipPath))
	if err != nil {
		return false, err.Error(), nil
	}
	defer zipFile.Close()

	archive := zip.NewWriter(zipFile)
	defer archive.Close()

	// ── 1. Combined Manifest & Compression Walk (Walk #2 is now the only backup walk) ──
	var fileCount int
	var folderCount int
	var excludedCount int
	var includedFiles []map[string]interface{}

	if !srcInfo.IsDir() {
		fileCount = 1
		folderCount = 0
		excludedCount = 0
		includedFiles = append(includedFiles, map[string]interface{}{
			"path":     filepath.Base(src),
			"size":     srcInfo.Size(),
			"mod_time": srcInfo.ModTime().Unix(),
		})

		file, err := os.Open(longPath(src))
		if err != nil {
			return false, err.Error(), nil
		}
		defer file.Close()
		w, err := archive.Create(filepath.Base(src))
		if err != nil {
			return false, "Failed to prep single file compression: " + err.Error(), nil
		}
		if _, err := io.Copy(w, file); err != nil {
			return false, "Failed to write file into zip archive: " + err.Error(), nil
		}
	} else {
		patterns := parseExclusionRules(proj.ExclusionRules)
		err = filepath.WalkDir(longPath(src), func(path string, d fs.DirEntry, e error) error {
			if e != nil {
				return nil
			}
			rel, _ := filepath.Rel(src, path)
			if rel == "." {
				return nil
			}

			if isPathExcluded(rel, patterns) {
				excludedCount++
				includedFiles = append(includedFiles, map[string]interface{}{
					"path":     filepath.ToSlash(rel),
					"size":     nil,
					"mod_time": int64(0),
					"status":   "skipped",
				})
				if d.IsDir() {
					return filepath.SkipDir
				}
				return nil
			}

			if d.IsDir() {
				folderCount++
			} else {
				fileCount++
				info, err := d.Info()
				if err == nil {
					includedFiles = append(includedFiles, map[string]interface{}{
						"path":     filepath.ToSlash(rel),
						"size":     info.Size(),
						"mod_time": info.ModTime().Unix(),
					})

					// Write the file into zip writer inside WalkDir directly
					func() {
						file, err := os.Open(longPath(path))
						if err != nil {
							return
						}
						defer file.Close()
						w, err := archive.Create(filepath.ToSlash(rel))
						if err == nil {
							_, _ = io.Copy(w, file)
						}
					}()
				}
			}
			return nil
		})
		if err != nil {
			return false, "Error building archive: " + err.Error(), nil
		}
	}

	// ── 2. Calculate Diffs (Added, Modified, Deleted) ─────────────────────────
	var oldFilesMap = make(map[string]map[string]interface{})
	if proj.LastZipName != "" {
		oldZipPath := filepath.Join(dst, proj.LastZipName)
		if zr, err := zip.OpenReader(longPath(oldZipPath)); err == nil {
			for _, zf := range zr.File {
				if zf.Name == "backup_meta.json" {
					if rc, err := zf.Open(); err == nil {
						var meta map[string]interface{}
						if err := json.NewDecoder(rc).Decode(&meta); err == nil {
							if oldFilesList, ok := meta["files"].([]interface{}); ok {
								for _, fItem := range oldFilesList {
									if fMap, ok := fItem.(map[string]interface{}); ok {
										if pathStr, ok := fMap["path"].(string); ok {
											oldFilesMap[pathStr] = fMap
										}
									}
								}
							}
						}
						rc.Close()
					}
					break
				}
			}
			zr.Close()
		}
	}

	var addedCount int
	var modifiedCount int
	var deletedCount int

	visitedOldFiles := make(map[string]bool)

	for _, currentFile := range includedFiles {
		relPath := currentFile["path"].(string)

		if currentFile["status"] == "skipped" {
			continue // Skip calculating diffs for excluded files
		}

		currentSize := currentFile["size"].(int64)
		currentModTime := currentFile["mod_time"].(int64)

		if oldFile, exists := oldFilesMap[relPath]; exists {
			visitedOldFiles[relPath] = true

			var oldSize int64
			if sizeVal, ok := oldFile["size"].(float64); ok {
				oldSize = int64(sizeVal)
			} else if sizeValInt, ok := oldFile["size"].(int64); ok {
				oldSize = sizeValInt
			}

			var oldModTime int64
			if modVal, ok := oldFile["mod_time"].(float64); ok {
				oldModTime = int64(modVal)
			} else if modValInt, ok := oldFile["mod_time"].(int64); ok {
				oldModTime = modValInt
			}

			if currentSize != oldSize || currentModTime != oldModTime {
				modifiedCount++
				currentFile["status"] = "modified"
			} else {
				currentFile["status"] = "unchanged"
			}
		} else {
			addedCount++
			currentFile["status"] = "added"
		}
	}

	for oldPath, oldFile := range oldFilesMap {
		if !visitedOldFiles[oldPath] {
			deletedCount++
			oldFile["status"] = "deleted"
			includedFiles = append(includedFiles, oldFile)
		}
	}

	meta := map[string]interface{}{
		"version":        version,
		"project":        proj.Name,
		"created_local":  formatTimestamp(now),
		"note":           strings.TrimSpace(note),
		"file_count":     fileCount,
		"folder_count":   folderCount,
		"excluded_count": excludedCount,
		"added_count":    addedCount,
		"modified_count": modifiedCount,
		"deleted_count":  deletedCount,
		"files":          includedFiles, // Status natively embedded
	}
	metaBytes, _ := json.MarshalIndent(meta, "", "  ")
	w, err := archive.Create("backup_meta.json")
	if err == nil {
		_, _ = w.Write(metaBytes)
	}

	archive.Close()
	zipFile.Close()

	hasher := sha256.New()
	zf, err := os.Open(longPath(zipPath))
	if err == nil {
		_, _ = io.Copy(hasher, zf)
		zf.Close()
	}
	zipHash := fmt.Sprintf("%x", hasher.Sum(nil))

	updates := map[string]interface{}{
		"version":       version,
		"last_backup":   formatTimestamp(now),
		"content_hash":  currentHash,
		"last_zip_name": zipName,
		"new_zip_hash":  zipHash,
	}

	return true, zipName, updates
}

func cleanOldBackups(proj *Project, settings Settings, limit int) (bool, string, int) {
	dst := resolveDestination(*proj, settings)
	if _, err := os.Stat(dst); err != nil || limit <= 0 {
		return false, "Destination directory missing.", 0
	}

	prefix := fmt.Sprintf("%s_v", sanitizeFilename(proj.Name))
	type bItem struct {
		version int
		path    string
		name    string
	}
	backups := []bItem{}

	files, err := os.ReadDir(dst)
	if err != nil {
		return false, err.Error(), 0
	}

	for _, f := range files {
		if !f.IsDir() && strings.HasPrefix(f.Name(), prefix) && strings.HasSuffix(f.Name(), ".zip") {
			suffix := strings.TrimSuffix(strings.TrimPrefix(f.Name(), prefix), ".zip")
			parts := strings.Split(suffix, "_")
			if len(parts) > 0 {
				v, _ := strconv.Atoi(parts[0])
				backups = append(backups, bItem{version: v, path: filepath.Join(dst, f.Name()), name: f.Name()})
			}
		}
	}

	sort.Slice(backups, func(i, j int) bool {
		return backups[i].version < backups[j].version
	})

	if len(backups) <= limit {
		return true, "All copies are within the retention limit.", 0
	}

	deleted := 0
	toDelete := backups[:len(backups)-limit]
	for _, b := range toDelete {
		if err := os.Remove(b.path); err == nil {
			deleted++
			if proj.BackupHashes != nil {
				delete(proj.BackupHashes, b.name)
			}
		}
	}

	return true, "Purged old backup copies cleanly.", deleted
}

func performRestore(proj Project, settings Settings, filename string) (bool, string) {
	src := proj.Source
	dst := resolveDestination(proj, settings)

	zipToRestore := filename
	if zipToRestore == "" {
		zipToRestore = proj.LastZipName
	}
	if zipToRestore == "" {
		return false, "No backup copies available."
	}

	zipPath := filepath.Join(dst, zipToRestore)
	if _, err := os.Stat(longPath(zipPath)); err != nil {
		return false, "Backup ZIP file not found."
	}

	zr, err := zip.OpenReader(longPath(zipPath))
	if err != nil {
		return false, err.Error()
	}
	defer zr.Close()

	srcInfo, _ := os.Stat(longPath(src))
	isSingleFileRestore := false
	if len(zr.File) == 2 {
		hasMeta := false
		for _, f := range zr.File {
			if f.Name == "backup_meta.json" {
				hasMeta = true
			}
		}
		if hasMeta {
			isSingleFileRestore = true
		}
	}

	if srcInfo != nil && srcInfo.IsDir() {
		files, _ := os.ReadDir(longPath(src))
		for _, f := range files {
			path := filepath.Join(src, f.Name())
			if f.IsDir() {
				_ = os.RemoveAll(longPath(path))
			} else {
				_ = os.Remove(longPath(path))
			}
		}
	} else if isSingleFileRestore {
		_ = os.Remove(longPath(src))
	}

	restoreBase := src
	if isSingleFileRestore {
		restoreBase = filepath.Dir(src)
	}
	_ = os.MkdirAll(longPath(restoreBase), 0755)

	for _, f := range zr.File {
		if f.Name == "backup_meta.json" {
			continue
		}

		targetPath := filepath.Join(src, f.Name)
		if isSingleFileRestore {
			if strings.Contains(f.Name, "/") || strings.Contains(f.Name, "\\") {
				continue // Skip directory entries in single-file restore
			}
			targetPath = src
		} else {
			cleanSrc := filepath.Clean(src)
			cleanTarget := filepath.Clean(targetPath)
			if !strings.HasPrefix(cleanTarget, cleanSrc+string(os.PathSeparator)) && cleanTarget != cleanSrc {
				logger.Printf("ZIP Slip blocked: %s -> %s", f.Name, cleanTarget)
				continue
			}
		}

		if f.FileInfo().IsDir() {
			_ = os.MkdirAll(longPath(targetPath), 0755)
			continue
		}

		_ = os.MkdirAll(longPath(filepath.Dir(targetPath)), 0755)
		outFile, err := os.OpenFile(longPath(targetPath), os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			return false, err.Error()
		}

		rc, err := f.Open()
		if err == nil {
			_, _ = io.Copy(outFile, rc)
			rc.Close()
		}
		outFile.Close()
	}

	return true, "Restored cleanly."
}

// ── Windows Toast Notifications ──────────────────────────────────────────────

func sendWindowsNotification(title, message string, launchPath ...string) {
	title = sanitizePowerShell(title)
	message = sanitizePowerShell(message)

	path := ""
	if len(launchPath) > 0 && launchPath[0] != "" {
		path = sanitizePowerShell(launchPath[0])
		path = strings.ReplaceAll(path, `\`, "/")
		if !strings.HasPrefix(path, "/") {
			path = "/" + path
		}
		path = "file://" + path
	}

	if path != "" {
		ps := `[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$textNodes = $template.GetElementsByTagName("text")
$textNodes.Item(0).AppendChild($template.CreateTextNode('` + title + `')) | Out-Null
$textNodes.Item(1).AppendChild($template.CreateTextNode('` + message + `')) | Out-Null
$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
$xml.LoadXml($template.GetXml())
$toastEl = $xml.SelectSingleNode("/toast")
$actions = $xml.CreateElement("actions")
$action = $xml.CreateElement("action")
$action.SetAttribute("content", "Open Destination")
$action.SetAttribute("arguments", '` + path + `')
$action.SetAttribute("activationType", "protocol")
$actions.AppendChild($action) | Out-Null
$toastEl.AppendChild($actions) | Out-Null
$toast = [Windows.UI.Notifications.ToastNotification]::new($xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("explorer.exe").Show($toast)`
		cmd := exec.Command("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Command", ps)
		cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
		_ = cmd.Start()
		return
	}

	ps := `[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
$textNodes = $template.GetElementsByTagName("text")
$textNodes.Item(0).AppendChild($template.CreateTextNode('` + title + `')) | Out-Null
$textNodes.Item(1).AppendChild($template.CreateTextNode('` + message + `')) | Out-Null
$toast = [Windows.UI.Notifications.ToastNotification]::new($template)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("explorer.exe").Show($toast)`

	cmd := exec.Command("powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-Command", ps)
	cmd.SysProcAttr = &syscall.SysProcAttr{HideWindow: true}
	_ = cmd.Start()
}

// ── Native Dialog & UI Invokers ──────────────────────────────────────────────

func browseDirectory() string {
	res, err := zenity.SelectFile(zenity.Title("Select Backup Directory"), zenity.Directory())
	if err != nil {
		return ""
	}
	return res
}

func browseFile() string {
	res, err := zenity.SelectFile(zenity.Title("Select Source File"))
	if err != nil {
		return ""
	}
	return res
}

func openInExplorer(path string) bool {
	if _, err := os.Stat(path); err != nil {
		return false
	}
	_ = exec.Command("explorer", path).Start()
	return true
}

func revealInExplorer(filePath string) bool {
	if _, err := os.Stat(filePath); err != nil {
		return false
	}
	_ = exec.Command("explorer", "/select,", filePath).Start()
	return true
}

// ── HTTP API Handlers ────────────────────────────────────────────────────────

func sendJSON(w http.ResponseWriter, statusCode int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0")
	w.Header().Set("Pragma", "no-cache")
	w.Header().Set("Expires", "0")
	w.WriteHeader(statusCode)
	_ = json.NewEncoder(w).Encode(data)
}

func startServer() {
	strippedFS, err := fs.Sub(frontendFS, "frontend/dist")
	if err != nil {
		log.Fatal("Failed to build sub-filesystem for frontend distribution.")
	}
	fileServer := http.FileServer(http.FS(strippedFS))

	http.HandleFunc("/api/", func(w http.ResponseWriter, r *http.Request) {
		origin := r.Header.Get("Origin")
		if origin != "" && (strings.HasPrefix(origin, "http://localhost:") || strings.HasPrefix(origin, "http://127.0.0.1:")) {
			w.Header().Set("Access-Control-Allow-Origin", origin)
		}

		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}

		path := r.URL.Path
		switch path {
		case "/api/projects":
			if r.Method == "GET" {
				dataMutex.Lock()
				dataParsed := loadData()
				dataMutex.Unlock()

				type CustomProj struct {
					Project
					SrcSize              int64  `json:"src_size"`
					SrcCount             int    `json:"src_count"`
					DstSize              int64  `json:"dst_size"`
					DstCount             int    `json:"dst_count"`
					DestinationEffective string `json:"destination_effective"`
					Status               string `json:"status"`
					ActiveWrites         bool   `json:"active_writes"`
					ActiveWritesReason   string `json:"active_writes_reason"`
				}

				customList := make([]CustomProj, len(dataParsed.Projects))
				var wg sync.WaitGroup

				for i, proj := range dataParsed.Projects {
					wg.Add(1)
					go func(idx int, p Project) {
						defer wg.Done()
						src_size, src_count, hasActiveWrites, activeWritesReason, curHash, _ := scanProject(p.Source, p.ExclusionRules)
						dstEffective := resolveDestination(p, dataParsed.Settings)
						dst_size, dst_count := calculateDestStats(dstEffective, p.Name)

						status := "clean"
						if p.Version == 0 {
							status = "new"
						} else if curHash != p.ContentHash {
							status = "modified"
						}

						customList[idx] = CustomProj{
							Project:              p,
							SrcSize:              src_size,
							SrcCount:             src_count,
							DstSize:              dst_size,
							DstCount:             dst_count,
							DestinationEffective: dstEffective,
							Status:               status,
							ActiveWrites:         hasActiveWrites,
							ActiveWritesReason:   activeWritesReason,
						}
					}(i, proj)
				}
				wg.Wait()

				sendJSON(w, http.StatusOK, map[string]interface{}{
					"version":  dataParsed.Version,
					"settings": dataParsed.Settings,
					"projects": customList,
				})
			}

		case "/api/settings":
			switch r.Method {
			case http.MethodGet:
				dataMutex.Lock()
				data := loadData()
				dataMutex.Unlock()
				sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success", "settings": data.Settings})
			case http.MethodPost:
				var req Settings
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					dataMutex.Lock()
					data := loadData()
					data.Settings.GlobalBackupDir = strings.TrimSpace(req.GlobalBackupDir)
					data.Settings.UseProjectSubfolderDefault = req.UseProjectSubfolderDefault
					saveErr := saveData(data)
					dataMutex.Unlock()

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Failed to save settings: " + saveErr.Error()})
					} else {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/browse":
			if r.Method == "GET" {
				folder := browseDirectory()
				w.Header().Set("Content-Type", "text/plain; charset=utf-8")
				_, _ = w.Write([]byte(folder))
			}

		case "/api/browse_file":
			if r.Method == "GET" {
				file := browseFile()
				w.Header().Set("Content-Type", "text/plain; charset=utf-8")
				_, _ = w.Write([]byte(file))
			}

		case "/api/add":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					name, _ := req["name"].(string)
					source, _ := req["source"].(string)
					destination, _ := req["destination"].(string)
					limitVal, _ := req["limit"].(float64)
					useGlobal, _ := req["use_global_destination"].(bool)
					useSub, _ := req["use_project_subfolder"].(bool)
					excRules, _ := req["exclusion_rules"].(string)
					excRules = strings.TrimSpace(excRules)
					if excRules == "" {
						excRules = defaultExclusionRules
					}

					name = strings.TrimSpace(name)
					source = strings.TrimSpace(source)
					destination = strings.TrimSpace(destination)

					dataMutex.Lock()
					data := loadData()
					if name == "" || source == "" || (!useGlobal && destination == "") {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "All fields are required"})
						return
					}

					data.Projects = append(data.Projects, Project{
						Name:                 name,
						Source:               source,
						Destination:          destination,
						Version:              0,
						Limit:                int(limitVal),
						UseGlobalDestination: useGlobal,
						UseProjectSubfolder:  useSub,
						ExclusionRules:       excRules,
						BackupHashes:         make(map[string]string),
					})
					saveErr := saveData(data)
					dataMutex.Unlock()

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Failed to add project: " + saveErr.Error()})
						return
					}

					updateTray() // Refresh Tray Menu
					sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/edit":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					idx := int(idxVal)
					name, _ := req["name"].(string)
					source, _ := req["source"].(string)
					destination, _ := req["destination"].(string)
					limitVal, _ := req["limit"].(float64)
					useGlobal, _ := req["use_global_destination"].(bool)
					useSub, _ := req["use_project_subfolder"].(bool)
					excRules, _ := req["exclusion_rules"].(string)
					excRules = strings.TrimSpace(excRules)

					name = strings.TrimSpace(name)
					source = strings.TrimSpace(source)
					destination = strings.TrimSpace(destination)

					dataMutex.Lock()
					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					if name == "" || source == "" || (!useGlobal && destination == "") {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "All fields are required"})
						return
					}

					proj := &data.Projects[idx]
					proj.Name = name
					proj.Source = source
					proj.Destination = destination
					proj.Limit = int(limitVal)
					proj.UseGlobalDestination = useGlobal
					proj.UseProjectSubfolder = useSub
					proj.ExclusionRules = excRules

					saveErr := saveData(data)
					dataMutex.Unlock()

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Failed to save project edits: " + saveErr.Error()})
						return
					}

					updateTray() // Refresh Tray Menu
					sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/remove":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					idx := int(idxVal)

					dataMutex.Lock()
					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}
					data.Projects = append(data.Projects[:idx], data.Projects[idx+1:]...)
					saveErr := saveData(data)
					dataMutex.Unlock()

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Failed to remove project: " + saveErr.Error()})
						return
					}

					updateTray() // Refresh Tray Menu
					sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/backups":
			if r.Method == "GET" {
				query := r.URL.Query()
				idxStr := query.Get("index")
				idx, err := strconv.Atoi(idxStr)

				dataMutex.Lock()
				data := loadData()
				dataMutex.Unlock()

				if err != nil || idx < 0 || idx >= len(data.Projects) {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
					return
				}
				backups := listProjectBackups(data.Projects[idx], data.Settings)
				sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success", "backups": backups})
			}

		case "/api/preview":
			if r.Method == "GET" {
				query := r.URL.Query()
				idxStr := query.Get("index")
				idx, err := strconv.Atoi(idxStr)

				dataMutex.Lock()
				data := loadData()
				dataMutex.Unlock()

				if err != nil || idx < 0 || idx >= len(data.Projects) {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
					return
				}

				proj := data.Projects[idx]
				dst := resolveDestination(proj, data.Settings)
				lastZipPath := ""
				if proj.LastZipName != "" && dst != "" {
					lastZipPath = filepath.Join(dst, proj.LastZipName)
				}

				_, _, hasActive, activeReason, _, files, err := buildProjectSnapshot(proj.Source, proj.ExclusionRules, lastZipPath)
				if err != nil {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": err.Error()})
					return
				}
				sendJSON(w, http.StatusOK, map[string]interface{}{
					"status": "success",
					"preview": map[string]interface{}{
						"files":                files,
						"active_writes":        hasActive,
						"active_writes_reason": activeReason,
					},
				})
			}

		case "/api/backup":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					note, _ := req["note"].(string)
					idx := int(idxVal)

					dataMutex.Lock()
					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := data.Projects[idx]
					settings := data.Settings
					dataMutex.Unlock()

					ok, msg, updates := doBackup(&proj, settings, note)
					if !ok {
						if msg == "No changes detected, backup skipped." {
							sendJSON(w, http.StatusOK, map[string]interface{}{"status": "skipped", "message": msg})
						} else {
							sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": msg})
						}
						return
					}

					var saveErr error
					dataMutex.Lock()
					freshData := loadData()
					var foundIdx = -1
					for i, p := range freshData.Projects {
						if p.Name == proj.Name {
							foundIdx = i
							break
						}
					}
					if foundIdx != -1 {
						freshProj := &freshData.Projects[foundIdx]
						freshProj.Version = updates["version"].(int)
						freshProj.LastBackup = updates["last_backup"].(string)
						freshProj.ContentHash = updates["content_hash"].(string)
						freshProj.LastZipName = updates["last_zip_name"].(string)

						if freshProj.BackupHashes == nil {
							freshProj.BackupHashes = make(map[string]string)
						}
						freshProj.BackupHashes[updates["last_zip_name"].(string)] = updates["new_zip_hash"].(string)

						saveErr = saveData(freshData)
					}
					dataMutex.Unlock()

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Backup succeeded, but failed to save metadata: " + saveErr.Error()})
					} else {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success", "message": "Backup completed successfully!"})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/cleanup":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					limitVal, _ := req["limit"].(float64)
					idx := int(idxVal)

					dataMutex.Lock()
					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := &data.Projects[idx]
					if limitVal > 0 {
						proj.Limit = int(limitVal)
					}

					ok, msg, count := cleanOldBackups(proj, data.Settings, proj.Limit)
					var saveErr error
					if ok {
						if limitVal > 0 || count > 0 {
							saveErr = saveData(data)
						}
					}
					dataMutex.Unlock()

					if !ok {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": msg})
						return
					}

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Cleanup completed, but failed to save settings: " + saveErr.Error()})
					} else {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success", "message": fmt.Sprintf("%s (Purged: %d copies)", msg, count)})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/delete_backups":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					filenamesVal, _ := req["filenames"].([]interface{})
					idx := int(idxVal)

					dataMutex.Lock()
					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := &data.Projects[idx]
					dst := resolveDestination(*proj, data.Settings)
					prefix := fmt.Sprintf("%s_v", sanitizeFilename(proj.Name))

					deleted := 0
					deletedLatest := false
					for _, fVal := range filenamesVal {
						name, _ := fVal.(string)
						if !strings.HasPrefix(name, prefix) || !strings.HasSuffix(name, ".zip") {
							continue
						}
						target := filepath.Join(dst, name)
						// REL-07: Path traversal protection
						if !strings.HasPrefix(filepath.Clean(target), filepath.Clean(dst)+string(os.PathSeparator)) {
							continue
						}
						// REL-05: Windows longPath protection
						if err := os.Remove(longPath(target)); err == nil {
							deleted++
							if proj.BackupHashes != nil {
								delete(proj.BackupHashes, name)
							}
							if name == proj.LastZipName {
								deletedLatest = true
							}
						}
					}

					if deletedLatest {
						syncProjectStateAfterDeletion(proj, data.Settings)
					}

					saveErr := saveData(data)
					dataMutex.Unlock()

					if saveErr != nil {
						sendJSON(w, http.StatusInternalServerError, map[string]interface{}{"status": "error", "message": "Deleted backup(s), but failed to save metadata: " + saveErr.Error()})
					} else {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success", "message": fmt.Sprintf("Successfully deleted %d backup copy/copies.", deleted)})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/restore":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					filename, _ := req["filename"].(string)
					idx := int(idxVal)

					dataMutex.Lock()
					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						dataMutex.Unlock()
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := data.Projects[idx]
					settings := data.Settings
					dataMutex.Unlock()

					ok, msg := performRestore(proj, settings, filename)
					if ok {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success", "message": msg})
					} else {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": msg})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/open_destination":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					idx := int(idxVal)

					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := data.Projects[idx]
					dst := resolveDestination(proj, data.Settings)
					if openInExplorer(dst) {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
					} else {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Destination folder not found."})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/open_source":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					idx := int(idxVal)

					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := data.Projects[idx]
					src := proj.Source
					if info, err := os.Stat(src); err == nil && !info.IsDir() {
						src = filepath.Dir(src)
					}
					if openInExplorer(src) {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
					} else {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Source path not found."})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}

		case "/api/reveal_backup":
			if r.Method == "POST" {
				var req map[string]interface{}
				if err := json.NewDecoder(r.Body).Decode(&req); err == nil {
					idxVal, _ := req["index"].(float64)
					filename, _ := req["filename"].(string)
					idx := int(idxVal)

					data := loadData()
					if idx < 0 || idx >= len(data.Projects) {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid index"})
						return
					}

					proj := data.Projects[idx]
					if filename == "" {
						filename = proj.LastZipName
					}
					if filename == "" {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "No backup file found."})
						return
					}

					target := filepath.Join(resolveDestination(proj, data.Settings), filename)
					if revealInExplorer(target) {
						sendJSON(w, http.StatusOK, map[string]interface{}{"status": "success"})
					} else {
						sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "ZIP file not found."})
					}
				} else {
					sendJSON(w, http.StatusBadRequest, map[string]interface{}{"status": "error", "message": "Invalid JSON payload"})
				}
			}
		}
	})

	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if strings.HasPrefix(r.URL.Path, "/api/") {
			return
		}

		path := strings.TrimPrefix(r.URL.Path, "/")
		if path == "" {
			path = "index.html"
		}

		ext := strings.ToLower(filepath.Ext(path))
		mime := mimeTypes[ext]
		if mime != "" {
			w.Header().Set("Content-Type", mime)
		}

		f, err := strippedFS.Open(path)
		if err == nil {
			f.Close()
			fileServer.ServeHTTP(w, r)
			return
		}

		indexFile, err := strippedFS.Open("index.html")
		if err == nil {
			defer indexFile.Close()
			w.Header().Set("Content-Type", "text/html; charset=utf-8")
			_, _ = io.Copy(w, indexFile)
			return
		}

		http.NotFound(w, r)
	})

	logger.Printf("Starting local Go server on http://127.0.0.1:%d\n", Port)
	_ = http.ListenAndServe(fmt.Sprintf("127.0.0.1:%d", Port), nil)
}

var mimeTypes = map[string]string{
	".html":        "text/html; charset=utf-8",
	".css":         "text/css",
	".js":          "application/javascript",
	".json":        "application/json",
	".svg":         "image/svg+xml",
	".png":         "image/png",
	".ico":         "image/x-icon",
	".woff2":       "font/woff2",
	".woff":        "font/woff",
	".ttf":         "font/ttf",
	".webmanifest": "application/manifest+json",
}

func openBrowser(targetUrl string) {
	// Look for Chrome
	chromePaths := []string{
		`C:\Program Files\Google\Chrome\Application\chrome.exe`,
		`C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`,
		filepath.Join(os.Getenv("USERPROFILE"), `AppData\Local\Google\Chrome\Application\chrome.exe`),
	}

	for _, path := range chromePaths {
		if _, err := os.Stat(path); err == nil {
			cmd := exec.Command(path, "--app="+targetUrl)
			if err := cmd.Start(); err == nil {
				return
			}
		}
	}

	// Look for Microsoft Edge (Chromium based)
	edgePaths := []string{
		`C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`,
		`C:\Program Files\Microsoft\Edge\Application\msedge.exe`,
		filepath.Join(os.Getenv("USERPROFILE"), `AppData\Local\Microsoft\Edge\Application\msedge.exe`),
	}

	for _, path := range edgePaths {
		if _, err := os.Stat(path); err == nil {
			cmd := exec.Command(path, "--app="+targetUrl)
			if err := cmd.Start(); err == nil {
				return
			}
		}
	}

	// Fallback to default browser protocol handler
	cmd := exec.Command("rundll32", "url.dll,FileProtocolHandler", targetUrl)
	_ = cmd.Start()
}

// ── System Tray Management ───────────────────────────────────────────────────

func updateTray() {
	trayMutex.Lock()
	defer trayMutex.Unlock()

	data := loadData()
	validNames := make(map[string]bool)

	for _, p := range data.Projects {
		validNames[p.Name] = true
		item, exists := projectMenuItems[p.Name]

		if !exists {
			// Create new project in the tray submenu
			item = quickBackupMenu.AddSubMenuItem(p.Name, "Backup "+p.Name)
			projectMenuItems[p.Name] = item

			// Listen for clicks in the background
			go func(projName string, menuItem *systray.MenuItem) {
				menuItem.Click(func() {
					runTrayBackup(projName)
				})
			}(p.Name, item)
		} else {
			// Show if it was previously hidden
			item.Show()
		}
	}

	// Hide removed projects
	for name, item := range projectMenuItems {
		if !validNames[name] {
			item.Hide()
		}
	}
}

func runTrayBackup(targetName string) {
	dataMutex.Lock()
	data := loadData()
	targetIdx := -1
	for i, p := range data.Projects {
		if p.Name == targetName {
			targetIdx = i
			break
		}
	}

	if targetIdx == -1 {
		dataMutex.Unlock()
		return // Project removed
	}

	proj := data.Projects[targetIdx]
	settings := data.Settings
	dataMutex.Unlock()

	logger.Printf("Tray Quick Backup initiated for: %s", proj.Name)

	ok, msg, updates := doBackup(&proj, settings, "Triggered via Quick Backup")
	if !ok {
		if strings.Contains(msg, "No changes detected") {
			logger.Printf("Tray Backup skipped for %s: %s", proj.Name, msg)
			go sendWindowsNotification("Friday Backup Skipped", "No changes detected in "+proj.Name+".")
		} else {
			logger.Printf("Tray Backup failed for %s: %s", proj.Name, msg)
			go sendWindowsNotification("Friday Backup Failed", "Failed to back up "+proj.Name+": "+msg)
		}
		return
	}

	dataMutex.Lock()
	freshData := loadData()
	var foundIdx = -1
	for i, p := range freshData.Projects {
		if p.Name == proj.Name {
			foundIdx = i
			break
		}
	}
	if foundIdx != -1 {
		freshProj := &freshData.Projects[foundIdx]
		freshProj.Version = updates["version"].(int)
		freshProj.LastBackup = updates["last_backup"].(string)
		freshProj.ContentHash = updates["content_hash"].(string)
		freshProj.LastZipName = updates["last_zip_name"].(string)

		if freshProj.BackupHashes == nil {
			freshProj.BackupHashes = make(map[string]string)
		}
		freshProj.BackupHashes[updates["last_zip_name"].(string)] = updates["new_zip_hash"].(string)

		_ = saveData(freshData)
		version := updates["version"].(int)
		dst := resolveDestination(proj, settings)
		logger.Printf("Tray Backup successful for: %s (v%d)", proj.Name, version)
		go sendWindowsNotification("Friday Backup Completed", "Successfully backed up "+proj.Name+" (v"+strconv.Itoa(version)+").", dst)
	}
	dataMutex.Unlock()
}

func onReady() {
	systray.SetIcon(iconIcoBytes)

	systray.SetTitle("Friday")
	systray.SetTooltip("Friday Backup Manager")
	systray.SetOnDClick(func(menu systray.IMenu) {
		openBrowser(fmt.Sprintf("http://127.0.0.1:%d", Port))
	})

	mOpen := systray.AddMenuItem("Open Friday UI", "Open Friday in your browser")
	systray.AddSeparator()

	// Create the Quick Backup Submenu
	quickBackupMenu = systray.AddMenuItem("Quick Backup", "Run an instant background backup")
	updateTray() // Populate it with current projects

	systray.AddSeparator()
	mQuit := systray.AddMenuItem("Exit Friday", "Exit the application")

	openBrowser(fmt.Sprintf("http://127.0.0.1:%d", Port))
	mOpen.Click(func() {
		openBrowser(fmt.Sprintf("http://127.0.0.1:%d", Port))
	})
	mQuit.Click(func() {
		systray.Quit()
	})

	select {}
}

func onExit() {
	// Crucial: Release the database lock when exiting!
	if db != nil {
		db.Close()
	}
	logger.Println("Friday background service shut down cleanly.")
	if logFile != nil {
		_ = logFile.Close()
	}
}

func main() {
	logger.Println("Friday starting local Go background service.")

	client := http.Client{Timeout: 500 * time.Millisecond}
	resp, err := client.Get(fmt.Sprintf("http://127.0.0.1:%d/api/projects", Port))
	if err == nil {
		resp.Body.Close()
		openBrowser(fmt.Sprintf("http://127.0.0.1:%d", Port))
		os.Exit(0)
	}

	go startServer()
	systray.Run(onReady, onExit)
}
