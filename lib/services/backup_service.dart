import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import '../models/backup_item.dart';
import '../models/exclusions_config.dart';
import '../models/file_diff_entry.dart';
import '../models/project.dart';
import '../models/settings.dart';
import '../utils/formatters.dart';

class BackupResult {
  final bool success;
  final bool skipped;
  final String message;
  final String? zipName;
  final int? newVersion;
  final String? lastBackup;
  final String? contentHash;
  final String? zipHash;
  final BackupItem? backupItem;

  const BackupResult({
    required this.success,
    this.skipped = false,
    required this.message,
    this.zipName,
    this.newVersion,
    this.lastBackup,
    this.contentHash,
    this.zipHash,
    this.backupItem,
  });
}


class ProjectScanResult {
  final int size;
  final int count;
  final bool hasActive;
  final String activeReason;
  final String currentHash;
  final List<FileDiffEntry> files;

  const ProjectScanResult({
    required this.size,
    required this.count,
    required this.hasActive,
    required this.activeReason,
    required this.currentHash,
    required this.files,
  });
}

class CompiledExclusionRule {
  final RegExp fullPathRegex;
  final RegExp segmentRegex;
  final String rawRule;
  final bool isDirOnly;

  CompiledExclusionRule({
    required this.fullPathRegex,
    required this.segmentRegex,
    required this.rawRule,
    required this.isDirOnly,
  });
}

class BackupService {
  const BackupService();

  String resolveDestination(Project proj, Settings settings) {
    String base = '';
    if (proj.useGlobalDestination && settings.globalBackupDir.trim().isNotEmpty) {
      base = settings.globalBackupDir.trim();
    } else {
      base = proj.destination.trim();
    }

    if (proj.useProjectSubfolder && base.isNotEmpty) {
      return p.join(base, Formatters.sanitizeFilename(proj.name));
    }
    return base;
  }

  List<String> parseExclusionRules(String rulesStr) {
    final patterns = <String>[];
    final parts = rulesStr.split(RegExp(r'[\n,]'));
    for (final part in parts) {
      final clean = part.trim();
      if (clean.isNotEmpty) {
        patterns.add(clean);
      }
    }
    return patterns;
  }

  List<CompiledExclusionRule> parseCompiledRules(String rulesStr) {
    final patterns = parseExclusionRules(rulesStr);
    final compiled = <CompiledExclusionRule>[];

    for (final pattern in patterns) {
      final cleanPattern = p.posix.normalize(pattern.replaceAll(r'\', '/').trim());
      if (cleanPattern.isEmpty) continue;

      final isDirPattern = cleanPattern.endsWith('/');
      final rule = isDirPattern
          ? cleanPattern.substring(0, cleanPattern.length - 1)
          : cleanPattern;

      final escaped = RegExp.escape(rule).replaceAll(r'\*', '.*').replaceAll(r'\?', '.');
      final regex = RegExp('^$escaped\$', caseSensitive: false);

      compiled.add(CompiledExclusionRule(
        fullPathRegex: regex,
        segmentRegex: regex,
        rawRule: rule.toLowerCase(),
        isDirOnly: isDirPattern,
      ));
    }

    return compiled;
  }

  bool isPathExcluded(String relPath, List<String> patterns) {
    final config = ExclusionsConfig(patterns: patterns);
    return config.isExcluded(p.basename(relPath), relativePath: relPath.replaceAll(r'\', '/'));
  }

  bool isPathExcludedCompiled(String relPath, List<CompiledExclusionRule> rules) {
    final slashPath = p.posix.normalize(relPath.replaceAll(r'\', '/'));
    final parts = slashPath.split('/');

    for (final rule in rules) {
      // Match full path exactly or by glob
      if (rule.fullPathRegex.hasMatch(slashPath)) {
        return true;
      }

      // Check each path segment
      for (int i = 0; i < parts.length; i++) {
        final part = parts[i];
        final isLastPart = i == parts.length - 1;

        if (rule.segmentRegex.hasMatch(part) || part.toLowerCase() == rule.rawRule) {
          if (rule.isDirOnly && isLastPart) {
            continue;
          }
          return true;
        }
      }
    }
    return false;
  }

  List<FileDiffEntry> computeDiffs(
    List<FileDiffEntry> currentEntries,
    List<FileDiffEntry>? previousFiles,
  ) {
    final oldFilesMap = <String, FileDiffEntry>{};
    if (previousFiles != null) {
      for (final f in previousFiles) {
        if (f.status != 'skipped' && f.status != 'deleted') {
          oldFilesMap[f.path] = f;
        }
      }
    }

    final visitedOld = <String>{};
    final result = <FileDiffEntry>[];

    for (final current in currentEntries) {
      if (current.status == 'skipped') {
        visitedOld.add(current.path);
        result.add(current);
        continue;
      }

      final old = oldFilesMap[current.path];
      if (old != null) {
        visitedOld.add(current.path);
        final isModified = (current.size ?? 0) != (old.size ?? 0) ||
            current.modTime != old.modTime;
        result.add(current.copyWith(
          status: isModified ? 'modified' : 'unchanged',
        ));
      } else {
        result.add(current.copyWith(status: 'added'));
      }
    }

    for (final entry in oldFilesMap.entries) {
      if (!visitedOld.contains(entry.key)) {
        result.add(entry.value.copyWith(status: 'deleted'));
      }
    }

    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }

  int? parseVersionFromFilename(String filename, String prefix) {
    if (!filename.startsWith(prefix) || !filename.endsWith('.zip')) return null;
    final suffix = filename.substring(prefix.length, filename.length - 4);
    final parts = suffix.split('_');
    if (parts.isNotEmpty) {
      return int.tryParse(parts[0]);
    }
    return null;
  }

  (bool, String) isFileActive(String name, DateTime modTime) {
    final lowerName = name.toLowerCase();

    if (lowerName.startsWith(r'~$')) {
      return (true, 'Microsoft Office temporary file detected');
    }
    if (lowerName.startsWith('#') && lowerName.endsWith('#')) {
      return (true, 'Auto-save temporary file detected');
    }
    if (lowerName.startsWith('.~lock.')) {
      return (true, 'Open file lock detected');
    }

    const suffixes = [
      '.db-wal', '.db-shm', '.db-journal', '.db-wal2',
      '.crdownload', '.part', '.download', '.opdownload', '.partial',
      '.lock', '.lck', '.lockfile', '.flock',
      '.tmp', '.temp',
      '.swp', '.swo',
      '.staging', '.unpacked', '.extracting',
      '.rendering',
    ];

    for (final suff in suffixes) {
      if (lowerName.endsWith(suff)) {
        return (true, 'Temporary database or lock file detected');
      }
    }

    if (DateTime.now().difference(modTime).inSeconds < 15) {
      return (true, 'Recently modified file detected');
    }

    return (false, '');
  }

  Future<ProjectScanResult> scanProject(
    String srcPath,
    String rules, {
    String? lastZipPath,
    List<FileDiffEntry>? previousFiles,
  }) async {
    final trimmedSrc = srcPath.trim();
    if (trimmedSrc.isEmpty) {
      return const ProjectScanResult(
        size: 0,
        count: 0,
        hasActive: false,
        activeReason: '',
        currentHash: '',
        files: [],
      );
    }

    final isDir = await Directory(trimmedSrc).exists();
    final isFile = await File(trimmedSrc).exists();

    if (!isDir && !isFile) {
      return const ProjectScanResult(
        size: 0,
        count: 0,
        hasActive: false,
        activeReason: '',
        currentHash: '',
        files: [],
      );
    }

    if (isFile) {
      final file = File(trimmedSrc);
      final stat = await file.stat();
      final (hasActive, activeReason) = isFileActive(p.basename(trimmedSrc), stat.modified);
      final hash = (await sha256.bind(file.openRead()).first).toString();

      final entries = [
        FileDiffEntry(
          path: p.basename(trimmedSrc),
          size: stat.size,
          modTime: stat.modified.millisecondsSinceEpoch ~/ 1000,
          status: 'included',
          active: hasActive,
          activeReason: activeReason,
        ),
      ];

      final diffFiles = computeDiffs(entries, previousFiles);

      return ProjectScanResult(
        size: stat.size,
        count: 1,
        hasActive: hasActive,
        activeReason: activeReason,
        currentHash: hash,
        files: diffFiles,
      );
    }

    final gitignoreFile = File(p.join(trimmedSrc, '.gitignore'));
    final gitPatterns = gitignoreFile.existsSync()
        ? ExclusionsConfig.parseGitignoreFile(gitignoreFile)
        : const <String>[];
    final exclusionsConfig = ExclusionsConfig.fromRulesString(
      rules,
      gitignorePatterns: gitPatterns,
    );
    final dir = Directory(trimmedSrc);
    int totalSize = 0;
    int totalCount = 0;
    bool hasActive = false;
    String activeReason = '';
    final List<FileDiffEntry> includedFiles = [];
    final List<(String, File, int, int)> fileItems = [];

    // Safeguard: If destination directory is within source directory, automatically exclude it
    String? relDstExcluded;
    if (lastZipPath != null && lastZipPath.isNotEmpty) {
      final dstDir = p.dirname(lastZipPath);
      if (p.isWithin(trimmedSrc, dstDir)) {
        relDstExcluded = p.relative(dstDir, from: trimmedSrc).replaceAll(r'\', '/');
      }
    }

    final queue = <Directory>[dir];
    while (queue.isNotEmpty) {
      final currentDir = queue.removeLast();
      List<FileSystemEntity> entities;
      try {
        entities = await currentDir.list(followLinks: false).toList();
      } catch (_) {
        continue;
      }

      for (final entity in entities) {
        final rel = p.relative(entity.path, from: trimmedSrc);
        if (rel == '.') continue;
        final slashRel = rel.replaceAll(r'\', '/');
        final name = p.basename(entity.path);

        // Auto-exclude self-backup destination path if located inside source
        if (relDstExcluded != null &&
            (slashRel == relDstExcluded || slashRel.startsWith('$relDstExcluded/'))) {
          includedFiles.add(FileDiffEntry(
            path: slashRel,
            size: null,
            modTime: 0,
            status: 'skipped',
          ));
          continue;
        }

        if (exclusionsConfig.isExcluded(name, relativePath: slashRel)) {
          includedFiles.add(FileDiffEntry(
            path: slashRel,
            size: null,
            modTime: 0,
            status: 'skipped',
          ));
          continue; // Early directory pruning: skips entire subdirectory
        }

        if (entity is Directory) {
          queue.add(entity);
        } else if (entity is File) {
          try {
            final stat = await entity.stat();
            totalSize += stat.size;
            totalCount++;

            final (fileActive, fileReason) = isFileActive(name, stat.modified);
            if (!hasActive && fileActive) {
              hasActive = true;
              activeReason = fileReason;
            }

            final modSecs = stat.modified.millisecondsSinceEpoch ~/ 1000;
            includedFiles.add(FileDiffEntry(
              path: slashRel,
              size: stat.size,
              modTime: modSecs,
              status: 'included',
              active: fileActive,
              activeReason: fileReason,
            ));

            fileItems.add((slashRel, entity, stat.size, modSecs));
          } catch (_) {}
        }
      }
    }

    // Sort files deterministically for hashing
    fileItems.sort((a, b) => a.$1.compareTo(b.$1));

    // Calculate deterministic content hash with length-prefix & null delimiter to prevent boundary collisions
    final controller = StreamController<List<int>>();
    final digestFuture = sha256.bind(controller.stream).first;

    for (final item in fileItems) {
      controller.add(utf8.encode(item.$1));
      try {
        await for (final chunk in item.$2.openRead()) {
          controller.add(chunk);
        }
      } catch (_) {}
    }
    await controller.close();
    final digest = await digestFuture;
    final contentHash = digest.toString();

    final diffResultFiles = computeDiffs(includedFiles, previousFiles);

    return ProjectScanResult(
      size: totalSize,
      count: totalCount,
      hasActive: hasActive,
      activeReason: activeReason,
      currentHash: contentHash,
      files: diffResultFiles,
    );
  }

  (int, int) calculateDestStats(String dstPath, String projName) {
    if (dstPath.isEmpty) return (0, 0);
    final dir = Directory(dstPath);
    if (!dir.existsSync()) return (0, 0);

    final prefix = '${Formatters.sanitizeFilename(projName)}_v';
    int totalSize = 0;
    int totalCount = 0;

    try {
      final list = dir.listSync();
      for (final entity in list) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name.startsWith(prefix) && name.endsWith('.zip')) {
            totalSize += entity.lengthSync();
            totalCount++;
          }
        }
      }
    } catch (_) {}

    return (totalSize, totalCount);
  }

  Future<(String, String)> checkZipIntegrity(String filePath, String originalHash) async {
    final file = File(filePath);
    if (!await file.exists()) return ('', 'corrupted');

    try {
      final currentHash = (await sha256.bind(file.openRead()).first).toString();

      if (originalHash.isNotEmpty) {
        if (originalHash.toLowerCase() == currentHash.toLowerCase()) {
          return (currentHash, 'verified');
        }
        return (currentHash, 'corrupted');
      }

      // Check structural zip integrity if no baseline hash was recorded
      try {
        final inputStream = InputFileStream(filePath);
        try {
          final archive = ZipDecoder().decodeStream(inputStream);
          if (archive.isNotEmpty) {
            return (currentHash, 'untracked');
          }
        } finally {
          inputStream.close();
        }
      } catch (_) {
        return (currentHash, 'corrupted');
      }

      return (currentHash, 'untracked');
    } catch (_) {
      return ('', 'corrupted');
    }
  }

  Future<List<BackupItem>> listProjectBackups(
    Project proj,
    Settings settings, {
    Map<String, BackupItem> dbBackups = const {},
  }) async {
    final dst = resolveDestination(proj, settings);
    if (dst.isEmpty) return [];

    final dir = Directory(dst);
    if (!dir.existsSync()) return [];

    final prefix = '${Formatters.sanitizeFilename(proj.name)}_v';
    final backups = <BackupItem>[];

    try {
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final name = p.basename(entity.path);
          final parsedVersion = parseVersionFromFilename(name, prefix);
          if (parsedVersion != null) {
            final stat = entity.statSync();
            final versionVal = parsedVersion;

            final dbItem = dbBackups[name];
            String createdLocal = dbItem?.timestamp ?? Formatters.formatTimestamp(stat.modified);
            String note = dbItem?.note ?? '';
            int fileCount = dbItem?.fileCount ?? 0;
            int folderCount = dbItem?.folderCount ?? 0;
            int excludedCount = dbItem?.excludedCount ?? 0;
            int addedCount = dbItem?.addedCount ?? 0;
            int modifiedCount = dbItem?.modifiedCount ?? 0;
            int deletedCount = dbItem?.deletedCount ?? 0;
            List<FileDiffEntry> filesList = dbItem?.files ?? [];

            final origHash = proj.backupHashes[name] ?? (dbItem?.zipHash ?? '');
            String zipHash = origHash;
            String integrity = dbItem?.integrity ?? 'verified';

            if (filesList.isEmpty || note.isEmpty) {
              try {
                final inputStream = InputFileStream(entity.path);
                try {
                  final archive = ZipDecoder().decodeStream(inputStream);
                  final metaFile = archive.findFile('backup_meta.json');
                  if (metaFile != null) {
                    try {
                      final metaContent = metaFile.content as List<int>;
                      final metaJson = jsonDecode(utf8.decode(metaContent)) as Map<String, dynamic>;
                      if (note.isEmpty && metaJson['note'] != null) {
                        note = metaJson['note'].toString();
                      }
                      if (metaJson['created_local'] != null && (dbItem == null || dbItem.timestamp.isEmpty)) {
                        createdLocal = metaJson['created_local'].toString();
                      }
                      if (metaJson['added_count'] != null && addedCount == 0) addedCount = metaJson['added_count'] as int;
                      if (metaJson['modified_count'] != null && modifiedCount == 0) modifiedCount = metaJson['modified_count'] as int;
                      if (metaJson['deleted_count'] != null && deletedCount == 0) deletedCount = metaJson['deleted_count'] as int;
                      if (metaJson['excluded_count'] != null && excludedCount == 0) excludedCount = metaJson['excluded_count'] as int;
                      if (metaJson['files'] != null && filesList.isEmpty) {
                        filesList = (metaJson['files'] as List)
                            .map((f) => FileDiffEntry.fromJson(f as Map<String, dynamic>))
                            .toList();
                      }
                    } catch (_) {}
                  }

                  if (filesList.isEmpty) {
                    final dynamicEntries = <FileDiffEntry>[];
                    int fCount = 0;
                    int dCount = 0;
                    for (final file in archive) {
                      if (file.name == 'backup_meta.json') continue;
                      if (file.isFile) {
                        fCount++;
                        dynamicEntries.add(FileDiffEntry(
                          path: file.name.replaceAll(r'\', '/'),
                          size: file.size,
                          modTime: file.lastModTime,
                          status: 'included',
                        ));
                      } else {
                        dCount++;
                      }
                    }
                    if (fileCount == 0) fileCount = fCount;
                    if (folderCount == 0) folderCount = dCount;
                    filesList = dynamicEntries;
                  }
                } finally {
                  inputStream.close();
                }
              } catch (_) {}
            }

            if (dbItem == null || dbItem.integrity == 'corrupted' || origHash.isEmpty) {
              final check = await checkZipIntegrity(entity.path, origHash);
              zipHash = check.$1.isNotEmpty ? check.$1 : zipHash;
              integrity = check.$2;
            } else if (origHash.isNotEmpty) {
              integrity = 'verified';
            }

            backups.add(BackupItem(
              filename: name,
              version: versionVal != 0 ? versionVal : (dbItem?.version ?? 0),
              timestamp: createdLocal,
              size: stat.size,
              note: note,
              zipHash: zipHash,
              integrity: integrity,
              fileCount: fileCount,
              folderCount: folderCount,
              excludedCount: excludedCount,
              addedCount: addedCount,
              modifiedCount: modifiedCount,
              deletedCount: deletedCount,
              files: filesList,
            ));
          }
        }
      }
    } catch (_) {}

    backups.sort((a, b) => b.version.compareTo(a.version));
    return backups;
  }

  Future<BackupResult> doBackup(
    Project proj,
    Settings settings,
    String note, {
    List<FileDiffEntry>? previousFiles,
  }) async {
    final src = proj.source.trim();
    final dst = resolveDestination(proj, settings);

    if (src.isEmpty) {
      return const BackupResult(success: false, message: 'Source path is empty.');
    }
    if (!p.isAbsolute(src)) {
      return const BackupResult(success: false, message: 'Source path must be an absolute path.');
    }
    if (dst.isEmpty) {
      return const BackupResult(success: false, message: 'Destination path is empty.');
    }
    if (!p.isAbsolute(dst)) {
      return const BackupResult(success: false, message: 'Destination path must be an absolute path.');
    }

    final isDir = await Directory(src).exists();
    final isFile = await File(src).exists();
    if (!isDir && !isFile) {
      return const BackupResult(success: false, message: 'Source path is not accessible.');
    }

    final dstDir = Directory(dst);
    if (!await dstDir.exists()) {
      await dstDir.create(recursive: true);
    }

    String lastZipPath = '';
    if (proj.lastZipName.isNotEmpty) {
      lastZipPath = p.join(dst, proj.lastZipName);
    }

    final scan = await scanProject(
      src,
      proj.exclusionRules,
      lastZipPath: lastZipPath,
      previousFiles: previousFiles,
    );
    bool zipMissing = false;
    if (proj.lastZipName.isNotEmpty) {
      if (!await File(p.join(dst, proj.lastZipName)).exists()) {
        zipMissing = true;
      }
    }

    if (!zipMissing && scan.currentHash == proj.contentHash && proj.version > 0) {
      return const BackupResult(
        success: false,
        skipped: true,
        message: 'No changes detected, backup skipped.',
      );
    }

    final now = DateTime.now();
    final version = proj.version + 1;
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final zipName = '${Formatters.sanitizeFilename(proj.name)}_v${version}_$dateStr.zip';
    final zipPath = p.join(dst, zipName);
    final tempZipPath = '$zipPath.tmp';

    // Auto-exclude destination directory if it is located inside source
    String? relDstExcluded;
    if (p.isWithin(src, dst)) {
      relDstExcluded = p.relative(dst, from: src).replaceAll(r'\', '/');
    }

    final zipEncoder = ZipFileEncoder();
    zipEncoder.create(tempZipPath);
    int fileCount = 0;
    int folderCount = 0;
    int excludedCount = 0;

    final List<FileDiffEntry> includedFilesMeta = [];

    try {
      if (isFile) {
        final file = File(src);
        final stat = await file.stat();
        await zipEncoder.addFile(file, p.basename(src));
        fileCount = 1;

        includedFilesMeta.add(FileDiffEntry(
          path: p.basename(src),
          size: stat.size,
          modTime: stat.modified.millisecondsSinceEpoch ~/ 1000,
          status: 'included',
        ));
      } else {
        final gitignoreFile = File(p.join(src, '.gitignore'));
        final gitPatterns = gitignoreFile.existsSync()
            ? ExclusionsConfig.parseGitignoreFile(gitignoreFile)
            : const <String>[];
        final exclusionsConfig = ExclusionsConfig.fromRulesString(
          proj.exclusionRules,
          gitignorePatterns: gitPatterns,
        );
        final dir = Directory(src);
        final queue = <Directory>[dir];

        while (queue.isNotEmpty) {
          final currentDir = queue.removeLast();
          List<FileSystemEntity> entities;
          try {
            entities = await currentDir.list(followLinks: false).toList();
          } catch (_) {
            continue;
          }

          for (final entity in entities) {
            final rel = p.relative(entity.path, from: src);
            if (rel == '.') continue;
            final slashRel = rel.replaceAll(r'\', '/');
            final name = p.basename(entity.path);

            // Auto-exclude destination directory from archiving
            if (relDstExcluded != null &&
                (slashRel == relDstExcluded || slashRel.startsWith('$relDstExcluded/'))) {
              excludedCount++;
              includedFilesMeta.add(FileDiffEntry(
                path: slashRel,
                size: null,
                modTime: 0,
                status: 'skipped',
              ));
              continue;
            }

            if (exclusionsConfig.isExcluded(name, relativePath: slashRel)) {
              excludedCount++;
              includedFilesMeta.add(FileDiffEntry(
                path: slashRel,
                size: null,
                modTime: 0,
                status: 'skipped',
              ));
              continue; // Early directory pruning: skips entire subdirectory
            }

            if (entity is Directory) {
              folderCount++;
              queue.add(entity);
            } else if (entity is File) {
              try {
                final stat = await entity.stat();
                await zipEncoder.addFile(entity, slashRel);
                fileCount++; // Increment only after addFile succeeds

                includedFilesMeta.add(FileDiffEntry(
                  path: slashRel,
                  size: stat.size,
                  modTime: stat.modified.millisecondsSinceEpoch ~/ 1000,
                  status: 'included',
                ));
              } catch (_) {}
            }
          }
        }
      }

      await zipEncoder.close();

      // Atomically move the completed archive to the final filename
      final tempFile = File(tempZipPath);
      await tempFile.rename(zipPath);
    } catch (e) {
      try {
        await zipEncoder.close();
      } catch (_) {}
      final tempFile = File(tempZipPath);
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
      return BackupResult(
        success: false,
        message: 'Backup failed during compression: $e',
      );
    }

    final finalFilesMeta = computeDiffs(includedFilesMeta, previousFiles);
    int addedCount = finalFilesMeta.where((f) => f.status == 'added').length;
    int modifiedCount = finalFilesMeta.where((f) => f.status == 'modified').length;
    int deletedCount = finalFilesMeta.where((f) => f.status == 'deleted').length;

    final zipHash = (await sha256.bind(File(zipPath).openRead()).first).toString();
    final createdLocal = Formatters.formatTimestamp(now);
    final zipStat = await File(zipPath).stat();

    final backupItem = BackupItem(
      filename: zipName,
      version: version,
      timestamp: createdLocal,
      size: zipStat.size,
      note: note.trim(),
      zipHash: zipHash,
      integrity: 'verified',
      fileCount: fileCount,
      folderCount: folderCount,
      excludedCount: excludedCount,
      addedCount: addedCount,
      modifiedCount: modifiedCount,
      deletedCount: deletedCount,
      files: finalFilesMeta,
    );

    return BackupResult(
      success: true,
      message: 'Backup completed successfully!',
      zipName: zipName,
      newVersion: version,
      lastBackup: createdLocal,
      contentHash: scan.currentHash,
      zipHash: zipHash,
      backupItem: backupItem,
    );
  }

  (bool, String, int) cleanOldBackups(
    Project proj,
    Settings settings,
    int limit,
  ) {
    final dst = resolveDestination(proj, settings);
    if (dst.isEmpty || limit <= 0) {
      return (false, 'Destination directory missing.', 0);
    }

    final dir = Directory(dst);
    if (!dir.existsSync()) {
      return (false, 'Destination directory does not exist.', 0);
    }

    final prefix = '${Formatters.sanitizeFilename(proj.name)}_v';
    final backups = <(int, File, String)>[];

    try {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          final v = parseVersionFromFilename(name, prefix);
          if (v != null) {
            backups.add((v, entity, name));
          }
        }
      }
    } catch (e) {
      return (false, e.toString(), 0);
    }

    backups.sort((a, b) => a.$1.compareTo(b.$1));

    if (backups.length <= limit) {
      return (true, 'All copies are within the retention limit.', 0);
    }

    int deleted = 0;
    final toDelete = backups.sublist(0, backups.length - limit);
    for (final item in toDelete) {
      try {
        item.$2.deleteSync();
        deleted++;
      } catch (_) {}
    }

    return (true, 'Purged old backup copies cleanly.', deleted);
  }

  Future<int> deleteBackups(
    Project proj,
    Settings settings,
    List<String> filenames,
  ) async {
    final dst = resolveDestination(proj, settings);
    if (dst.isEmpty) return 0;

    final prefix = '${Formatters.sanitizeFilename(proj.name)}_v';
    int deleted = 0;

    for (final name in filenames) {
      if (!name.startsWith(prefix) || !name.endsWith('.zip')) continue;
      final target = p.join(dst, name);
      // Path traversal security check
      if (!p.isWithin(dst, target) && target != dst) continue;

      final file = File(target);
      if (await file.exists()) {
        try {
          await file.delete();
          deleted++;
        } catch (_) {}
      }
    }

    return deleted;
  }

  void syncProjectStateAfterDeletion(Project proj, Settings settings, {required Function(Project) onUpdate}) {
    final dst = resolveDestination(proj, settings);
    final dir = Directory(dst);
    if (!dir.existsSync()) {
      onUpdate(proj.copyWith(
        version: 0,
        lastBackup: '',
        lastZipName: '',
        contentHash: '',
      ));
      return;
    }

    final prefix = '${Formatters.sanitizeFilename(proj.name)}_v';
    int latestVersion = -1;
    File? latestFile;

    try {
      for (final entity in dir.listSync()) {
        if (entity is File) {
          final name = p.basename(entity.path);
          final v = parseVersionFromFilename(name, prefix);
          if (v != null && v > latestVersion) {
            latestVersion = v;
            latestFile = entity;
          }
        }
      }
    } catch (_) {}

    if (latestVersion == -1 || latestFile == null) {
      onUpdate(proj.copyWith(
        version: 0,
        lastBackup: '',
        lastZipName: '',
        contentHash: '',
      ));
      return;
    }

    final stat = latestFile.statSync();
    String createdLocal = Formatters.formatTimestamp(stat.modified);

    onUpdate(proj.copyWith(
      version: latestVersion,
      lastBackup: createdLocal,
      lastZipName: p.basename(latestFile.path),
      contentHash: '', // Recalculate on next scan
    ));
  }
}
