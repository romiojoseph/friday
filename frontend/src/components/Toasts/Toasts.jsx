import styles from "./Toasts.module.css";
import { CheckCircle, XCircle, Info } from "@phosphor-icons/react";

export default function Toasts({ toasts }) {
  return (
    <div className={styles.container}>
      {toasts.map((t) => {
        const Icon = t.type === "success" ? CheckCircle : t.type === "error" ? XCircle : Info;
        const typeClass = t.type === "success" ? styles.success : t.type === "error" ? styles.error : styles.info;
        return (
          <div key={t.id} className={[styles.toast, typeClass].join(" ")}>
            <div className={styles.content}>
              <span className={styles.icon}>
                <Icon size={20} weight="bold" />
              </span>
              <span className={styles.text}>{t.text}</span>
            </div>
            <div className={styles.progressBar} />
          </div>
        );
      })}
    </div>
  );
}
