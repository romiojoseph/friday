import React from "react";
import { formatBytes } from "../../utils/formatters.js";
import Spinner from "../Spinner/Spinner.jsx";
import styles from "../HistoryModal/HistoryModal.module.css";
import { X } from "@phosphor-icons/react";

export default function PreviewModal({ open, project, loading, preview, onClose }) {
  const files = preview?.files || [];

  const renderStatus = (status) => {
    if (status === "added") return { color: "#4ade80", prefix: "+ ", label: "Added" };
    if (status === "modified") return { color: "#a855f7", prefix: "~ ", label: "Modified" };
    if (status === "deleted") return { color: "#ef4444", prefix: "- ", label: "Deleted" };
    if (status === "skipped") return { color: "#ffb366", prefix: "∅ ", label: "Skipped" };
    return { color: "#9ca3af", prefix: "", label: "Unchanged" };
  };

  return (
    <div className={[styles.backdrop, open ? styles.active : ""].filter(Boolean).join(" ")}>
      <div className={styles.modal}>
        <div className={styles.titleRow}>
          <span>Backup Preview</span>
          <button className={styles.close} onClick={onClose} aria-label="Close">
            <X size={20} weight="bold" />
          </button>
        </div>

        <div className={styles.headerRow}>
          <div className={styles.headerSubtitle}>
            <strong>{project?.name || "Project"}</strong> · Current state before backup
          </div>
        </div>

        <div className={styles.content}>
          {loading ? (
            <div className={styles.loadingState}>
              <Spinner className={styles.loadingSpinner} />
              <div className={styles.loadingText}>Loading preview...</div>
            </div>
          ) : files.length === 0 ? (
            <div className={styles.emptyState}>No files found for this source.</div>
          ) : (
            <div className={styles.fileListTableWrapper}>
              <div className={styles.fileListHeader}>
                Current backup state
              </div>
              {files.map((f, idx) => {
                const s = renderStatus(f.status);
                return (
                  <div key={idx} className={styles.fileItem}>
                    <span className={styles.filePath} style={{ color: s.color, textDecoration: f.status === "deleted" ? "line-through" : "none" }}>
                      {s.prefix}{f.path}
                    </span>
                    <span className={styles.fileSize} style={{ color: s.color }}>
                      {f.status === "skipped" ? "Skipped" : f.size != null ? formatBytes(f.size) : s.label}
                    </span>
                  </div>
                );
              })}
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
