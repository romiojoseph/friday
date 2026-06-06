import { useEffect, useState } from "react";
import Button from "../Button/Button.jsx";
import styles from "./GlobalSettingsModal.module.css";
import { X, FolderOpen, CheckCircleIcon, Database } from "@phosphor-icons/react";

export default function GlobalSettingsModal({ open, settings, onClose, onBrowseFolder, onSave }) {
  const [globalDir, setGlobalDir] = useState("");

  useEffect(() => {
    if (!open) return;
    setGlobalDir(settings?.global_backup_dir || "");
  }, [open, settings]);

  const browse = async () => {
    const path = await onBrowseFolder();
    if (path && path.trim() !== "") setGlobalDir(path);
  };

  const save = async () => {
    await onSave({ global_backup_dir: globalDir.trim() });
  };

  return (
    <div className={[styles.backdrop, open ? styles.active : ""].filter(Boolean).join(" ")}>
      <div className={styles.modal}>
        <div className={styles.titleRow}>
          <span>Global Settings</span>
          <button className={styles.close} onClick={onClose} aria-label="Close">
            <X size={20} weight="bold" />
          </button>
        </div>

        <div className={styles.group}>
          <label className={styles.label}>Global backup folder (optional)</label>
          <div className={styles.row}>
            <input className={styles.textInput} value={globalDir} onChange={(e) => setGlobalDir(e.target.value)} placeholder="D:\\FridayBackups" />
            <Button variant="secondary" onClick={browse}>
              <FolderOpen size={18} weight="bold" /> Browse
            </Button>
          </div>
          <div className={styles.helper}>If set, projects can opt-in to store backups under this folder.</div>
        </div>

        <div className={styles.footer}>
          <div style={{ marginRight: "auto" }}>
            <Button variant="text" onClick={() => window.open('/api/projects', '_blank')}>
              <Database size={18} weight="fill" /> View Raw Database (JSON)
            </Button>
          </div>
          <Button variant="secondary" onClick={onClose}>
            Close
          </Button>
          <Button variant="primary" onClick={save}>
            <CheckCircleIcon size={24} weight="fill" /> Save
          </Button>
        </div>
      </div>
    </div>
  );
}

