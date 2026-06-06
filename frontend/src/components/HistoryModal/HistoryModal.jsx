import React, { useState, useEffect } from "react";
import { formatBytes } from "../../utils/formatters.js";
import Button from "../Button/Button.jsx";
import Spinner from "../Spinner/Spinner.jsx";
import styles from "./HistoryModal.module.css";
import { CheckCircle, WarningOctagon, Warning, Lock, ArrowCounterClockwise, X, Eye, EyeSlash, Trash, Circle, Broom } from "@phosphor-icons/react";

export default function HistoryModal({ open, project, customLimit, autoSelect, rows, loading, onClose, onRestoreSpecific, onDeleteSpecific, onDeleteMultiple }) {
  const [expandedFilesZip, setExpandedFilesZip] = useState(null);
  const [selectedZipFiles, setSelectedZipFiles] = useState({});

  const keepLimit = customLimit !== undefined && customLimit !== null ? customLimit : (project?.limit || 5);

  const selectOverLimit = () => {
    const sortedRows = [...rows].sort((a, b) => (b.version || 0) - (a.version || 0));
    const newSelected = {};
    sortedRows.forEach((r, idx) => {
      if (idx >= keepLimit) {
        newSelected[r.filename] = true;
      }
    });
    setSelectedZipFiles(newSelected);
  };

  useEffect(() => {
    if (!open) {
      setExpandedFilesZip(null);
      setSelectedZipFiles({});
    } else if (autoSelect && rows.length > 0) {
      selectOverLimit();
    }
  }, [open, rows, autoSelect, keepLimit]);

  const toggleExpandFiles = (filename) => {
    setExpandedFilesZip((prev) => (prev === filename ? null : filename));
  };

  const selectedCount = Object.keys(selectedZipFiles).filter((f) => selectedZipFiles[f]).length;

  const handleDeleteSelected = () => {
    const filenames = Object.keys(selectedZipFiles).filter((f) => selectedZipFiles[f]);
    if (filenames.length === 0) return;
    onDeleteMultiple?.(filenames);
    setSelectedZipFiles({});
  };

  const toggleSelect = (filename) => {
    setSelectedZipFiles((prev) => ({
      ...prev,
      [filename]: !prev[filename],
    }));
  };

  const getIntegrityContent = (zip) => {
    if (zip.integrity === "corrupted") {
      return (
        <span className={styles.badgeCorrupted}>
          <WarningOctagon size={16} weight="fill" /> Corrupted
        </span>
      );
    } else if (zip.integrity === "untracked") {
      return (
        <span className={styles.badgeUntracked} title="Legacy backup without matching original hash record, but its zip structure is structurally valid.">
          <Warning size={16} weight="fill" /> Untracked
        </span>
      );
    }
    return (
      <span className={styles.badgeVerified}>
        <CheckCircle size={16} weight="fill" /> Verified
      </span>
    );
  };

  const renderFileList = (unifiedFiles) => {
    if (unifiedFiles.length === 0) {
      return <div className={styles.noFiles}>No files tracked.</div>;
    }
    return (
      <div className={styles.fileListTableWrapper}>
        <div className={styles.fileListHeader}>In this backup</div>
        {unifiedFiles.map((f, fIdx) => {
          let color = "#9ca3af";
          let prefix = "";
          let textDecoration = "none";

          if (f.status === "added") {
            color = "#4ade80";
            prefix = "+ ";
          } else if (f.status === "modified") {
            color = "#a855f7";
            prefix = "~ ";
          } else if (f.status === "deleted") {
            color = "#ef4444";
            prefix = "- ";
            textDecoration = "line-through";
          } else if (f.status === "skipped") {
            color = "#ffb366";
            prefix = "∅ ";
          }

          return (
            <div key={fIdx} className={styles.fileItem}>
              <span className={styles.filePath} style={{ color, textDecoration }}>
                {prefix}{f.path}
              </span>
              <span className={styles.fileSize} style={{ color, textDecoration }}>
                {f.size != null ? formatBytes(f.size) : "Skipped"}
              </span>
            </div>
          );
        })}
      </div>
    );
  };

  return (
    <div className={[styles.backdrop, open ? styles.active : ""].filter(Boolean).join(" ")}>
      <div className={styles.modal}>
        <div className={styles.titleRow}>
          <span>Backup History: {project?.name || ""}</span>
          <button className={styles.close} onClick={onClose} aria-label="Close">
            <X size={20} weight="bold" />
          </button>
        </div>

        <div className={styles.headerRow}>
          <span className={styles.headerSubtitle}>
            Retention Limit: <strong>{keepLimit} zips</strong>
          </span>
          {rows.length > keepLimit && (
            <Button variant="text" onClick={selectOverLimit}>
              <Broom size={16} weight="bold" /> Auto-Select Old Backups (&gt; {keepLimit})
            </Button>
          )}
        </div>

        <div className={styles.content}>
          {loading ? (
            <div className={styles.loadingState}>
              <Spinner className={styles.loadingSpinner} />
              <div className={styles.loadingText}>Loading history...</div>
            </div>
          ) : rows.length === 0 ? (
            <div className={styles.emptyState}>
              No backup versions recorded yet for this project.
            </div>
          ) : (
            <div className={styles.cardList}>
              {rows.map((zip, idx) => {
                const filesCount = zip.files_count !== undefined ? zip.files_count : (zip.file_count !== undefined ? zip.file_count : 0);
                const foldersCount = zip.folders_count !== undefined ? zip.folders_count : (zip.folder_count !== undefined ? zip.folder_count : 0);
                const excludedCount = zip.excluded_count !== undefined ? zip.excluded_count : 0;
                const filesAdded = zip.files_added !== undefined ? zip.files_added : (zip.added_count !== undefined ? zip.added_count : 0);
                const filesModified = zip.files_modified !== undefined ? zip.files_modified : (zip.modified_count !== undefined ? zip.modified_count : 0);
                const filesDeleted = zip.files_deleted !== undefined ? zip.files_deleted : (zip.deleted_count !== undefined ? zip.deleted_count : 0);

                const fileList = zip.files || [];
                const hasEmbeddedStatus = fileList.length > 0 && fileList[0].status !== undefined;

                let unifiedFiles = [];

                if (hasEmbeddedStatus) {
                  unifiedFiles = fileList.map((f) => ({
                    path: f.path,
                    size: f.size,
                    status: f.status || "unchanged"
                  }));
                } else {
                  const addedFilesSet = new Set(zip.added_files || []);
                  const modifiedFilesSet = new Set(zip.modified_files || []);
                  const deletedFilesList = zip.deleted_files || [];
                  const excludedFilesList = zip.excluded_files || [];

                  unifiedFiles = [
                    ...fileList.map((f) => {
                      let status = "unchanged";
                      if (addedFilesSet.has(f.path)) {
                        status = "added";
                      } else if (modifiedFilesSet.has(f.path)) {
                        status = "modified";
                      }
                      return { path: f.path, size: f.size, status };
                    }),
                    ...deletedFilesList.map((path) => ({
                      path,
                      size: 0,
                      status: "deleted"
                    })),
                    ...excludedFilesList.map((path) => ({
                      path,
                      size: null,
                      status: "skipped"
                    }))
                  ];
                }

                unifiedFiles.sort((a, b) => a.path.localeCompare(b.path));
                const isExpanded = expandedFilesZip === zip.filename;
                const isSelected = !!selectedZipFiles[zip.filename];

                const hasChanges = filesAdded > 0 || filesModified > 0 || filesDeleted > 0;

                return (
                  <div
                    key={zip.filename}
                    className={[styles.card, isSelected ? styles.cardSelected : ""].filter(Boolean).join(" ")}
                  >
                    <div className={styles.cardMain}>
                      <div className={styles.cardTopRow}>
                        <div
                          className={styles.checkbox}
                          onClick={() => toggleSelect(zip.filename)}
                        >
                          {isSelected ? (
                            <CheckCircle className={styles.checkedIcon} size={20} weight="fill" />
                          ) : (
                            <Circle className={styles.uncheckedIcon} size={20} weight="bold" />
                          )}
                        </div>
                        <span className={styles.verBadge}>v{zip.version}</span>
                        <span className={styles.dateText}>{zip.timestamp || ""}</span>
                        <div className={styles.topRowSpacer} />
                        <div className={styles.integrityGroup}>
                          {getIntegrityContent(zip)}
                          {zip.zip_hash ? (
                            <span
                              className={styles.hashChip}
                              onClick={async () => {
                                try {
                                  await navigator.clipboard.writeText(zip.zip_hash);
                                } catch { }
                              }}
                              title="Click to copy ZIP integrity SHA-256 hash"
                            >
                              {zip.zip_hash.slice(0, 8)}...
                            </span>
                          ) : null}
                        </div>
                        <span className={styles.sizeText}>{formatBytes(zip.size)}</span>
                      </div>

                      <div className={styles.cardStatsRow}>
                        <span className={styles.statsText}>
                          {foldersCount > 0
                            ? `${filesCount} Files, ${foldersCount} Folders`
                            : `${filesCount} Files`}
                        </span>
                        <span className={styles.statsDivider} />
                        {hasChanges ? (
                          <span className={styles.changesText} title={`${filesAdded} Added, ${filesModified} Modified, ${filesDeleted} Deleted`}>
                            <span className={styles.changeAdded}>+{filesAdded}</span>
                            <span className={styles.changeSep}>/</span>
                            <span className={styles.changeModified}>~{filesModified}</span>
                            <span className={styles.changeSep}>/</span>
                            <span className={styles.changeDeleted}>-{filesDeleted}</span>
                          </span>
                        ) : (
                          <span className={styles.noDiff}>No changes</span>
                        )}
                        {excludedCount > 0 && (
                          <>
                            <span className={styles.statsDivider} />
                            <span className={styles.excludedText}>{excludedCount} Skipped</span>
                          </>
                        )}
                      </div>

                      {zip.note ? (
                        <div className={styles.noteRow}>
                          <span className={styles.noteText}>{zip.note}</span>
                        </div>
                      ) : null}
                    </div>

                    <div className={styles.cardActions}>
                      <button className={styles.restoreBtn} onClick={() => onRestoreSpecific(zip.filename)} title="Restore this version">
                        <ArrowCounterClockwise size={16} weight="bold" /> Restore
                      </button>
                      {unifiedFiles.length > 0 && (
                        <button
                          type="button"
                          className={styles.viewFilesBtn}
                          onClick={() => toggleExpandFiles(zip.filename)}
                        >
                          {isExpanded ? (
                            <><EyeSlash size={16} weight="duotone" /> Hide Files</>
                          ) : (
                            <><Eye size={16} weight="fill" /> View Files</>
                          )}
                        </button>
                      )}
                    </div>

                    {isExpanded && (
                      <div className={styles.expandedSection}>
                        {renderFileList(unifiedFiles)}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          )}
        </div>

        <div className={styles.footer}>
          {selectedCount > 0 && (
            <Button variant="danger" style={{ marginRight: "auto" }} onClick={handleDeleteSelected}>
              <Trash size={20} weight="fill" /> Delete Selected ({selectedCount})
            </Button>
          )}
          <Button variant="secondary" onClick={onClose}>
            Close
          </Button>
        </div>
      </div>
    </div>
  );
}
