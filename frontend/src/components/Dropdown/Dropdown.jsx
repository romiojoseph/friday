import { useState, useRef, useEffect } from "react";
import { DotsThreeOutlineIcon } from "@phosphor-icons/react";
import styles from "./Dropdown.module.css";

export default function Dropdown({ options = [] }) {
  const [isOpen, setIsOpen] = useState(false);
  const containerRef = useRef(null);

  useEffect(() => {
    const handleClickOutside = (event) => {
      if (containerRef.current && !containerRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    };

    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  return (
    <div className={styles.container} ref={containerRef}>
      <button
        className={styles.trigger}
        onClick={() => setIsOpen(!isOpen)}
        aria-label="More actions"
      >
        <DotsThreeOutlineIcon size={24} weight="fill" />
      </button>

      <div className={[styles.menu, isOpen ? styles.active : ""].join(" ")}>
        {options.map((option, idx) => {
          if (option.type === "divider") {
            return <div key={idx} className={styles.divider} />;
          }

          return (
            <button
              key={idx}
              className={[styles.item, option.variant === "danger" ? styles.danger : ""].join(" ")}
              onClick={() => {
                option.onClick();
                setIsOpen(false);
              }}
              disabled={option.disabled}
            >
              {option.icon}
              <span>{option.label}</span>
            </button>
          );
        })}
      </div>
    </div>
  );
}
