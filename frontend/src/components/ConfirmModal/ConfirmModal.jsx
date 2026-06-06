import { useEffect } from "react";
import Button from "../Button/Button.jsx";
import styles from "./ConfirmModal.module.css";
import { X, CheckCircleIcon } from "@phosphor-icons/react";

export default function ConfirmModal({ open, title, message, details, confirmText, cancelText, variant, onConfirm, onCancel }) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e) => {
      if (e.key === "Escape") onCancel?.();
      if (e.key === "Enter") onConfirm?.();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onCancel, onConfirm, open]);

  return (
    <div className={[styles.backdrop, open ? styles.active : ""].filter(Boolean).join(" ")} role="dialog" aria-modal="true">
      <div className={styles.modal}>
        <div className={styles.titleRow}>
          <div className={styles.title}>
            <span>{title || "Confirm action"}</span>
          </div>
          <button className={styles.close} onClick={onCancel} aria-label="Close">
            <X size={20} weight="bold" />
          </button>
        </div>

        {message ? <div className={styles.message}>{message}</div> : null}
        {details ? <div className={styles.details}>{details}</div> : null}

        <div className={styles.footer}>
          <Button variant="secondary" onClick={onCancel}>
            {cancelText || "Cancel"}
          </Button>
          <Button variant={variant || "primary"} onClick={onConfirm}>
            <CheckCircleIcon size={24} weight="fill" /> {confirmText || "Confirm"}
          </Button>
        </div>
      </div>
    </div>
  );
}

