import Button from "../Button/Button.jsx";
import styles from "./Header.module.css";
import { Lightning, Gear, Plus } from "@phosphor-icons/react";

export default function Header({ onAddProject, onOpenGlobalSettings }) {
  return (
    <header className={styles.header}>
      <div className={styles.container}>
        <img src="/logo.svg" alt="Friday" className={styles.brand} />
        <div className={styles.actions}>
          <Button variant="secondary" className={styles.headerButton} onClick={onOpenGlobalSettings}>
            <Gear size={18} weight="bold" /> Settings
          </Button>
          <Button variant="primary" className={styles.headerButton} onClick={onAddProject}>
            <Plus size={18} weight="bold" /> Add Project
          </Button>
        </div>
      </div>
    </header>
  );
}
