import styles from "./Spinner.module.css";

export default function Spinner({ className = "", style }) {
  return <div className={[styles.spinner, className].filter(Boolean).join(" ")} style={style} />;
}

