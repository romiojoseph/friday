import { useEffect, useMemo, useState } from "react";
import { formatBytes } from "../../utils/formatters.js";
import Button from "../Button/Button.jsx";
import Spinner from "../Spinner/Spinner.jsx";
import Dropdown from "../Dropdown/Dropdown.jsx";
import styles from "./ProjectCard.module.css";
import { CheckCircle, GitDiff, WarningCircleIcon, ClockCounterClockwise, Gear, CloudArrowUpIcon, FolderOpen, Folder, Trash, Warning, Broom, CloudIcon, DatabaseIcon, FolderOpenIcon } from "@phosphor-icons/react";

export default function ProjectCard({
  project,
  index,
  busyAction,
  onBackup,
  onHistory,
  onEdit,
  onRemove,
  onRestore,
  onOpenDestination,
  onOpenSource,
  onRevealBackup,
  onPreview,
  showToast,
}) {
  const [retentionLimit, setRetentionLimit] = useState(project.limit || 5);
  const [backupNote, setBackupNote] = useState("");

  useEffect(() => {
    setRetentionLimit(project.limit || 5);
  }, [project.limit]);

  const lastBackup = project.last_backup || "Never";
  const version = project.version || 0;
  const fullHash = project.content_hash || "No backups yet";
  const shortHash = project.content_hash ? `${project.content_hash.slice(0, 8)}...` : "None";

  const lastZipHash = project.backup_hashes && project.last_zip_name ? project.backup_hashes[project.last_zip_name] : "";
  const shortZipHash = lastZipHash ? `${lastZipHash.slice(0, 8)}...` : "";

  const stats = useMemo(() => {
    return {
      srcSize: formatBytes(project.src_size || 0),
      dstSize: formatBytes(project.dst_size || 0),
      srcCount: project.src_count || 0,
      dstCount: project.dst_count || 0,
    };
  }, [project.dst_count, project.dst_size, project.src_count, project.src_size]);

  const copyHash = async (e) => {
    e.stopPropagation();
    try {
      if (fullHash === "No backups yet") return;
      await navigator.clipboard.writeText(fullHash);
      showToast("Copied content hash to clipboard!", "success");
    } catch {
      showToast("Failed to copy hash.", "error");
    }
  };

  const copyZipHash = async (e) => {
    e.stopPropagation();
    try {
      if (!lastZipHash) return;
      await navigator.clipboard.writeText(lastZipHash);
      showToast("Copied ZIP hash to clipboard!", "success");
    } catch {
      showToast("Failed to copy ZIP hash.", "error");
    }
  };

  const isBackingUp = busyAction === "backup";
  const isRestoring = busyAction === "restore";
  const isCleaning = busyAction === "cleanup";
  const disableCleanup = (project.dst_count || 0) === 0;

  const dropdownOptions = useMemo(() => [
    {
      label: "Edit Config",
      icon: <Gear size={18} weight="bold" />,
      onClick: () => onEdit(index),
    },
    {
      label: "Remove",
      icon: <Trash size={18} weight="bold" />,
      onClick: () => onRemove(index),
      variant: "danger",
    },
  ], [index, onEdit, onRemove]);

  return (
    <div className={[styles.card, isBackingUp ? styles.backingUp : ""].filter(Boolean).join(" ")}>
      {isBackingUp ? <div className={styles.backupGlow} /> : null}
      <div className={styles.cardTop}>
        <div>
          <div className={styles.cardNameRow}>
            <span className={styles.projectName}>{project.name}</span>
            {project.status === "modified" && (
              <span className={[styles.statusBadge, styles.statusModified].join(" ")}>
                <GitDiff size={16} weight="fill" /> Unsaved changes
              </span>
            )}
            {project.status === "clean" && (
              <span className={[styles.statusBadge, styles.statusClean].join(" ")}>
                <CheckCircle size={16} weight="fill" /> Up-to-date
              </span>
            )}
            {project.status === "new" && (
              <span className={[styles.statusBadge, styles.statusNew].join(" ")}>
                <WarningCircleIcon size={16} weight="fill" /> No backups
              </span>
            )}
          </div>
          <div className={styles.projMeta}>
            <span>v{version}</span>
            <span className={styles.dot}>•</span>
            <span>Last: {lastBackup}</span>
          </div>
        </div>
        <Dropdown options={dropdownOptions} />
      </div>

      <div className={styles.paths}>
        <div
          className={[styles.pathBlock, styles.clickablePath].join(" ")}
          onClick={() => onOpenSource(index)}
          title="Click to open source folder in File Explorer"
        >
          <div className={styles.pathHeader}>
            <div className={styles.pathLabel}><DatabaseIcon size={20} weight="fill" />Source</div>
          </div>
          <div className={styles.pathValue}>{project.source}</div>
          <div className={styles.pathSize}>
            {stats.srcSize} <span className={styles.pathSizeCount}>({stats.srcCount} files)</span>
          </div>
          {project.content_hash && (
            <button className={styles.pathHash} type="button" onClick={copyHash} title="Click to copy full hash">
              <span className={styles.hashShort}>{fullHash}</span>
            </button>
          )}
        </div>
        <div
          className={[styles.pathBlock, styles.clickablePath].join(" ")}
          onClick={() => onOpenDestination(index)}
          title="Click to open destination folder in File Explorer"
        >
          <div className={styles.pathHeader}>
            <div className={styles.pathLabel}><CloudIcon size={20} weight="fill" />Destination</div>
          </div>
          <div className={styles.pathValue}>{project.destination_effective || project.destination}</div>
          <div className={styles.pathSize}>
            {stats.dstSize} <span className={styles.pathSizeCount}>({stats.dstCount} zips)</span>
          </div>
          {lastZipHash && (
            <button className={styles.pathHash} type="button" onClick={copyZipHash} title="Click to copy full ZIP hash">
              <span className={styles.hashShort}>{lastZipHash}</span>
            </button>
          )}
        </div>
      </div>

      <div className={styles.hashAndRetention}>
        <div className={styles.exclusions}>
          {project.exclusion_rules ? (
            <>
              <span className={styles.exclusionsLabel}>Excluding:</span>
              <span className={styles.exclusionsValue} title={project.exclusion_rules}>
                {project.exclusion_rules}
              </span>
            </>
          ) : (
            <span className={styles.exclusionsNone}>No exclusion rules</span>
          )}
        </div>
        <div className={styles.retentionRow}>
          <span>Retention Limit:</span>
          <span className={styles.retentionValue}><strong>{retentionLimit}</strong></span>
        </div>
      </div>

      <div className={styles.actionsContainer}>
        <div className={styles.noteBox}>
          <textarea
            className={styles.noteArea}
            rows={2}
            value={backupNote}
            onChange={(e) => setBackupNote(e.target.value)}
            placeholder="Optional backup message... e.g. Before refactor / includes config change etc."
          />
        </div>

        {project.active_writes && (
          <div className={styles.warningBanner}>
            <Warning size={18} weight="fill" className={styles.warningIcon} />
            <div>
              {project.active_writes_reason
                ? `${project.active_writes_reason}. Recommended to close the local app before backing up.`
                : "Active writes detected (temp files or SQLite locks). Recommended to close the local app before backing up."}
            </div>
          </div>
        )}

        <div className={styles.actionsRow}>
          <Button variant="primary" onClick={() => onBackup(index, backupNote)} disabled={isBackingUp || isRestoring || isCleaning}>
            {isBackingUp ? (
              <>
                <Spinner />
                <span>Backing Up...</span>
              </>
            ) : (
              <>
                <CloudArrowUpIcon size={24} weight="fill" />
                <span>Backup Now</span>
              </>
            )}
          </Button>

          <Button variant="secondary" onClick={() => onHistory(index, retentionLimit)} disabled={isBackingUp || isRestoring || isCleaning}>
            <ClockCounterClockwise size={24} weight="fill" />
            <span>View History</span>
          </Button>
          <button
            type="button"
            className={styles.iconButton}
            onClick={() => onPreview(index)}
            disabled={isBackingUp || isRestoring || isCleaning}
            title="Preview current files"
          >
            <FolderOpenIcon size={20} weight="duotone" />
          </button>
        </div>
      </div>
    </div>
  );
}
