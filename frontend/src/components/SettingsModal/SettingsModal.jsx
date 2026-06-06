import { useEffect, useMemo, useState } from "react";
import Button from "../Button/Button.jsx";
import styles from "./SettingsModal.module.css";
import { X, Folder, File, CheckCircleIcon, Circle, CheckCircle } from "@phosphor-icons/react";

const DEFAULT_EXCLUSION_RULES = [
  "*.bak",
  "*.orig",
  "*.log",
  "*.etl",
  "*.evtx",
  "*.cache",
  "*.autosave",
  "thumbs.db",
  "desktop.ini",
  ".DS_Store",
  ".git",
  "node_modules",
  ".idea",
  ".vscode",
  "vendor",
  ".venv",
].join(", ");

function sanitizeFilename(name) {
  if (!name) return "project";
  let sanitized = name.replace(/[^\w\-_ ]/g, "_");
  sanitized = sanitized.replace(/ /g, "_");
  sanitized = sanitized.replace(/^[_.-]+|[_.-]+$/g, "");
  if (!sanitized) return "project";
  return sanitized;
}

export default function SettingsModal({
  open,
  editIndex,
  project,
  appSettings,
  onClose,
  onSave,
  onBrowseFolder,
  onBrowseFile,
  showToast,
}) {
  const isEdit = editIndex >= 0;
  const [name, setName] = useState("");
  const [source, setSource] = useState("");
  const [destination, setDestination] = useState("");
  const [limit, setLimit] = useState(5);
  const [exclusionRules, setExclusionRules] = useState("");
  const [useGlobalDestination, setUseGlobalDestination] = useState(false);
  const [useProjectSubfolder, setUseProjectSubfolder] = useState(false);
  const [hoverGlobal, setHoverGlobal] = useState(false);
  const [hoverSubfolder, setHoverSubfolder] = useState(false);

  useEffect(() => {
    if (!open) return;
    setName(project?.name || "");
    setSource(project?.source || "");
    setDestination(project?.destination || "");
    setLimit(project?.limit || 5);
    setExclusionRules(project ? (project.exclusion_rules || "") : DEFAULT_EXCLUSION_RULES);
    setUseGlobalDestination(!!project?.use_global_destination);
    setUseProjectSubfolder(!!project?.use_project_subfolder);
  }, [open, project]);

  const title = useMemo(() => (isEdit ? "Edit Friday Project" : "Add Friday Project"), [isEdit]);
  const actionText = useMemo(() => (isEdit ? "Update Project" : "Save Project"), [isEdit]);

  const resolvedPreview = useMemo(() => {
    let base = "";
    if (useGlobalDestination) {
      base = appSettings?.global_backup_dir || "";
      if (!base) return "(Global backup folder not configured)";
    } else {
      base = destination || "";
      if (!base) return "";
    }

    let separator = "\\";
    if (base.includes("/")) {
      separator = "/";
    }

    let path = base;
    if (useProjectSubfolder) {
      const folderName = sanitizeFilename(name);
      if (path.endsWith(separator)) {
        path = path + folderName;
      } else {
        path = path + separator + folderName;
      }
    }
    return path;
  }, [useGlobalDestination, appSettings, useProjectSubfolder, name, destination]);

  const browseDst = async () => {
    const path = await onBrowseFolder();
    if (path && path.trim() !== "") setDestination(path);
  };

  const browseSrcFolder = async () => {
    const path = await onBrowseFolder();
    if (path && path.trim() !== "") setSource(path);
  };

  const browseSrcFile = async () => {
    const path = await onBrowseFile();
    if (path && path.trim() !== "") setSource(path);
  };

  const save = async () => {
    if (!name.trim() || !source.trim() || (!useGlobalDestination && !destination.trim())) {
      showToast?.("All fields are required.", "error");
      return;
    }
    await onSave({
      name: name.trim(),
      source: source.trim(),
      destination: useGlobalDestination ? "" : destination.trim(),
      limit: Number(limit) || 5,
      exclusion_rules: exclusionRules.trim(),
      use_global_destination: useGlobalDestination,
      use_project_subfolder: useProjectSubfolder,
    });
  };

  return (
    <div className={[styles.backdrop, open ? styles.active : ""].filter(Boolean).join(" ")}>
      <div className={styles.modal}>
        <div className={styles.titleRow}>
          <span>{title}</span>
          <button className={styles.close} onClick={onClose} aria-label="Close">
            <X size={20} weight="bold" />
          </button>
        </div>

        <div className={styles.group}>
          <label className={styles.label}>Project Name</label>
          <input className={styles.textInput} type="text" value={name} onChange={(e) => setName(e.target.value)} placeholder="e.g. My Website Development" />
        </div>

        <div className={styles.group}>
          <label className={styles.label}>Source File or Folder</label>
          <div className={styles.row}>
            <input className={styles.textInput} type="text" value={source} onChange={(e) => setSource(e.target.value)} placeholder="C:\\path\\to\\source" />
            <Button variant="secondary" onClick={browseSrcFolder}>
              <Folder size={18} weight="bold" /> Folder
            </Button>
            <Button variant="secondary" onClick={browseSrcFile}>
              <File size={18} weight="bold" /> File
            </Button>
          </div>
        </div>

        <div className={styles.group}>
          <label className={styles.label}>Destination Folder</label>
          <div className={styles.row}>
            <input
              className={styles.textInput}
              type="text"
              value={useGlobalDestination ? resolvedPreview : destination}
              onChange={(e) => setDestination(e.target.value)}
              placeholder={useGlobalDestination ? "Global Backup Path" : "D:\\backups"}
              disabled={useGlobalDestination}
            />
            <Button variant="secondary" onClick={browseDst} disabled={useGlobalDestination}>
              <Folder size={18} weight="bold" /> Folder
            </Button>
          </div>
          {resolvedPreview && (
            <span className={styles.helper}>
              Live Preview: {resolvedPreview}
            </span>
          )}
        </div>

        <div className={styles.checkboxGroup}>
          <div
            className={styles.checkboxRow}
            onClick={() => setUseGlobalDestination(!useGlobalDestination)}
            onMouseEnter={() => setHoverGlobal(true)}
            onMouseLeave={() => setHoverGlobal(false)}
          >
            <div className={styles.checkboxIconWrapper}>
              {useGlobalDestination ? (
                <CheckCircle className={styles.checkedIcon} size={24} weight="fill" />
              ) : hoverGlobal ? (
                <Circle className={styles.uncheckedIconHover} size={24} weight="duotone" />
              ) : (
                <Circle className={styles.uncheckedIcon} size={24} weight="bold" />
              )}
            </div>
            <span className={styles.checkboxLabel}>Use global backup folder (if configured)</span>
          </div>

          <div
            className={styles.checkboxRow}
            onClick={() => setUseProjectSubfolder(!useProjectSubfolder)}
            onMouseEnter={() => setHoverSubfolder(true)}
            onMouseLeave={() => setHoverSubfolder(false)}
          >
            <div className={styles.checkboxIconWrapper}>
              {useProjectSubfolder ? (
                <CheckCircle className={styles.checkedIcon} size={24} weight="fill" />
              ) : hoverSubfolder ? (
                <Circle className={styles.uncheckedIconHover} size={24} weight="duotone" />
              ) : (
                <Circle className={styles.uncheckedIcon} size={24} weight="bold" />
              )}
            </div>
            <span className={styles.checkboxLabel}>Create subfolder with project name</span>
          </div>
        </div>

        <div className={styles.group}>
          <label className={styles.label}>Keep Latest N Backups</label>
          <div className={styles.retentionContainer}>
            <div className={styles.pillContainer}>
              {[2, 3, 4, 5, 6, 7, 8, 9, 10].map((num) => (
                <button
                  key={num}
                  type="button"
                  className={[
                    styles.pillButton,
                    Number(limit) === num ? styles.pillButtonActive : "",
                  ].filter(Boolean).join(" ")}
                  onClick={() => setLimit(num)}
                >
                  {num}
                </button>
              ))}
            </div>
          </div>
        </div>

        <div className={styles.group}>
          <label className={styles.label}>Exclusion Rules (Optional)</label>
          <textarea
            className={styles.textArea}
            value={exclusionRules}
            onChange={(e) => setExclusionRules(e.target.value)}
            placeholder="*.log, node_modules/, dist/, build/, *.tmp, cache/, folder/subfolder/"
          />
          <span className={styles.helper}>
            Use file names, folder names, or wildcards. Examples: <code>node_modules/</code>, <code>dist/</code>, <code>*.log</code>, <code>cache/</code>, <code>folder/subfolder/</code>.
          </span>
        </div>

        <div className={styles.footer}>
          <Button variant="secondary" onClick={onClose}>
            Cancel
          </Button>
          <Button variant="primary" onClick={save}>
            <CheckCircleIcon size={24} weight="fill" /> {actionText}
          </Button>
        </div>
      </div>
    </div>
  );
}
