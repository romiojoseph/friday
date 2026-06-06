import styles from "./Button.module.css";

export default function Button({ variant = "secondary", className = "", disabled = false, children, ...props }) {
  const variantClass = styles[variant] || styles.secondary;
  const disabledClass = disabled ? styles.disabled : "";
  const merged = [styles.btn, variantClass, disabledClass, className].filter(Boolean).join(" ");
  return (
    <button className={merged} disabled={disabled} {...props}>
      {children}
    </button>
  );
}

