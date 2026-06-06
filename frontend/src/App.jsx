import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import Header from "./components/Header/Header.jsx";
import ProjectCard from "./components/ProjectCard/ProjectCard.jsx";
import SettingsModal from "./components/SettingsModal/SettingsModal.jsx";
import HistoryModal from "./components/HistoryModal/HistoryModal.jsx";
import PreviewModal from "./components/PreviewModal/PreviewModal.jsx";
import Toasts from "./components/Toasts/Toasts.jsx";
import ConfirmModal from "./components/ConfirmModal/ConfirmModal.jsx";
import GlobalSettingsModal from "./components/GlobalSettingsModal/GlobalSettingsModal.jsx";
import {
  addProject,
  browseFile,
  browseFolder,
  deleteBackups,
  editProject,
  fetchBackups,
  fetchProjects,
  fetchPreview,
  openDestination,
  openSource,
  removeProject,
  revealBackup,
  triggerBackup,
  triggerCleanup,
  triggerRestore,
  fetchSettings,
  saveSettings,
} from "./api/friday.js";
import { Desktop } from "@phosphor-icons/react";
import styles from "./App.module.css";

export default function App() {
  const [projects, setProjects] = useState([]);
  const [toasts, setToasts] = useState([]);
  const [settings, setSettings] = useState({ open: false, editIndex: -1 });
  const [history, setHistory] = useState({ open: false, projectIndex: -1, rows: [], loading: false, customLimit: null });
  const [previewState, setPreviewState] = useState({ open: false, projectIndex: -1, loading: false, data: null });
  const [busy, setBusy] = useState({}); // index -> "backup" | "restore" | "cleanup"
  const [confirmState, setConfirmState] = useState({ open: false });
  const [globalSettingsOpen, setGlobalSettingsOpen] = useState(false);
  const [appSettings, setAppSettings] = useState(null);
  const [initialLoadAlerted, setInitialLoadAlerted] = useState(false);
  const [windowWidth, setWindowWidth] = useState(window.innerWidth);

  useEffect(() => {
    const onResize = () => setWindowWidth(window.innerWidth);
    window.addEventListener("resize", onResize);
    return () => window.removeEventListener("resize", onResize);
  }, []);

  const confirm = useCallback(({ title, message, details, confirmText, cancelText, variant }) => {
    return new Promise((resolve) => {
      setConfirmState({
        open: true,
        title,
        message,
        details,
        confirmText,
        cancelText,
        variant,
        resolve,
      });
    });
  }, []);

  const closeConfirm = useCallback((result) => {
    setConfirmState((s) => {
      s.resolve?.(result);
      return { open: false };
    });
  }, []);

  const toastTimers = useRef(new Map());

  const showToast = useCallback((text, type = "info") => {
    const id = crypto.randomUUID ? crypto.randomUUID() : String(Date.now() + Math.random());
    setToasts((prev) => [...prev, { id, text, type }]);
    const timerId = window.setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
      toastTimers.current.delete(id);
    }, 5000);
    toastTimers.current.set(id, timerId);
  }, []);

  useEffect(() => {
    return () => {
      // eslint-disable-next-line react-hooks/exhaustive-deps
      toastTimers.current.forEach((timerId) => clearTimeout(timerId));
    };
  }, []);

  const refreshProjects = useCallback(async () => {
    try {
      const data = await fetchProjects();
      const projList = data.projects || [];
      setProjects(projList);

      if (!initialLoadAlerted && projList.length > 0) {
        const modifiedCount = projList.filter((p) => p.status === "modified").length;
        if (modifiedCount > 0) {
          showToast(`${modifiedCount} project(s) have unsaved changes since last backup.`, "info");
        }
        setInitialLoadAlerted(true);
      }
    } catch {
      showToast("Failed to connect to the backend server.", "error");
    }
  }, [showToast, initialLoadAlerted]);

  const refreshSettings = useCallback(async () => {
    try {
      const res = await fetchSettings();
      setAppSettings(res.settings || {});
    } catch {
      setAppSettings({});
    }
  }, []);

  useEffect(() => {
    refreshSettings();
  }, [refreshSettings]);

  const isAnyModalOpen =
    settings.open ||
    previewState.open ||
    globalSettingsOpen ||
    history.open ||
    !!confirmState.open;

  useEffect(() => {
    if (isAnyModalOpen) return;
    refreshProjects();
    const interval = setInterval(() => {
      refreshProjects();
    }, 5000);
    return () => clearInterval(interval);
  }, [refreshProjects, isAnyModalOpen]);

  useEffect(() => {
    const onKey = (e) => {
      if (e.key !== "Escape") return;
      setSettings((s) => ({ ...s, open: false, editIndex: -1 }));
      setHistory((h) => ({ ...h, open: false, projectIndex: -1 }));
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, []);

  const onAdd = useCallback(() => setSettings({ open: true, editIndex: -1 }), []);
  const onEdit = useCallback((index) => setSettings({ open: true, editIndex: index }), []);
  const onCloseSettings = useCallback(() => setSettings({ open: false, editIndex: -1 }), []);
  const onClosePreview = useCallback(() => setPreviewState({ open: false, projectIndex: -1, loading: false, data: null }), []);

  const editProjectValue = useMemo(() => {
    if (settings.editIndex < 0) return null;
    return projects[settings.editIndex] || null;
  }, [projects, settings.editIndex]);

  const onPreview = useCallback(async (index) => {
    setPreviewState({ open: true, projectIndex: index, loading: true, data: null });
    try {
      const data = await fetchPreview(index);
      setPreviewState({ open: true, projectIndex: index, loading: false, data: data.preview || data });
    } catch {
      setPreviewState({ open: true, projectIndex: index, loading: false, data: null });
      showToast("Failed to load preview.", "error");
    }
  }, [showToast]);

  const onSaveProject = useCallback(
    async (payload) => {
      try {
        if (settings.editIndex < 0) {
          const res = await addProject(payload);
          if (res.status === "success") {
            showToast("Project added successfully!", "success");
            onCloseSettings();
            await refreshProjects();
          } else {
            showToast(res.message || "Failed to add project.", "error");
          }
          return;
        }

        const res = await editProject({ index: settings.editIndex, ...payload });
        if (res.status === "success") {
          showToast("Project updated successfully!", "success");
          onCloseSettings();
          await refreshProjects();
        } else {
          showToast(res.message || "Failed to update project.", "error");
        }
      } catch {
        showToast("Connection error while saving project.", "error");
      }
    },
    [onCloseSettings, refreshProjects, settings.editIndex, showToast],
  );

  const onRemove = useCallback(
    async (index) => {
      const ok = await confirm({
        title: "Remove project?",
        message: "This removes the project configuration from Friday.",
        details: `${projects[index]?.name || ""}`,
        confirmText: "Remove",
        cancelText: "Cancel",
        variant: "danger",
      });
      if (!ok) return;
      try {
        const res = await removeProject(index);
        if (res.status === "success") {
          showToast("Project removed successfully.", "success");
          await refreshProjects();
        } else {
          showToast(res.message || "Failed to remove project.", "error");
        }
      } catch {
        showToast("Connection error during project removal.", "error");
      }
    },
    [confirm, projects, refreshProjects, showToast],
  );

  const onBackup = useCallback(
    async (index, note) => {
      setBusy((b) => ({ ...b, [index]: "backup" }));
      try {
        const res = await triggerBackup(index, note);
        if (res.status === "success") showToast(res.message || "Backup completed successfully!", "success");
        else if (res.status === "skipped") showToast(res.message || "No changes detected. Backup skipped.", "info");
        else showToast(res.message || "Backup operation failed.", "error");
        await refreshProjects();
      } catch {
        showToast("Connection error during backup.", "error");
      } finally {
        setBusy((b) => {
          const { [index]: _ignored, ...rest } = b;
          return rest;
        });
      }
    },
    [refreshProjects, showToast],
  );

  const onDeleteSpecific = useCallback(
    async (index, filename) => {
      const ok = await confirm({
        title: "Delete backup version?",
        message: "This will permanently delete this backup zip file from your storage.",
        details: `Filename: ${filename}`,
        confirmText: "Delete",
        cancelText: "Cancel",
        variant: "danger",
      });
      if (!ok) return;
      try {
        const res = await deleteBackups(index, [filename]);
        if (res.status === "success") {
          showToast("Backup version deleted successfully.", "success");
          const data = await fetchBackups(index);
          setHistory((h) => ({ ...h, rows: data.backups || [] }));
          await refreshProjects();
        } else {
          showToast(res.message || "Failed to delete backup version.", "error");
        }
      } catch {
        showToast("Connection error while deleting backup version.", "error");
      }
    },
    [confirm, refreshProjects, showToast],
  );

  const onDeleteMultiple = useCallback(
    async (index, filenames) => {
      const ok = await confirm({
        title: `Delete ${filenames.length} backup version(s)?`,
        message: "This will permanently delete the selected backup zip files from Friday's database and storage.",
        details: filenames.join("\n"),
        confirmText: "Delete Selected",
        cancelText: "Cancel",
        variant: "danger",
      });
      if (!ok) return;
      try {
        const res = await deleteBackups(index, filenames);
        if (res.status === "success") {
          showToast(`${filenames.length} backup version(s) deleted successfully.`, "success");
          const data = await fetchBackups(index);
          setHistory((h) => ({ ...h, rows: data.backups || [] }));
          await refreshProjects();
        } else {
          showToast(res.message || "Failed to delete selected backup versions.", "error");
        }
      } catch {
        showToast("Connection error while deleting backup versions.", "error");
      }
    },
    [confirm, refreshProjects, showToast],
  );

  const onRestoreLatest = useCallback(
    async (index) => {
      const proj = projects[index];
      const ok = await confirm({
        title: "Quick restore?",
        message: "This will completely overwrite and replace the source contents with the latest backup zip.",
        details: `Source:\n${proj?.source || ""}\n\nBackup:\n${proj?.last_zip_name || "Latest Zip"}`,
        confirmText: "Restore",
        cancelText: "Cancel",
        variant: "primary",
      });
      if (!ok) return;
      setBusy((b) => ({ ...b, [index]: "restore" }));
      try {
        const res = await triggerRestore(index);
        if (res.status === "success") showToast(res.message || "Restore completed successfully!", "success");
        else showToast(res.message || "Restore operation failed.", "error");
        await refreshProjects();
      } catch {
        showToast("Connection error during restore.", "error");
      } finally {
        setBusy((b) => {
          const { [index]: _ignored, ...rest } = b;
          return rest;
        });
      }
    },
    [confirm, projects, refreshProjects, showToast],
  );

  const onOpenHistory = useCallback(
    async (index, customLimit, autoSelect) => {
      setHistory({ open: true, projectIndex: index, rows: [], loading: true, customLimit, autoSelect });
      try {
        const data = await fetchBackups(index);
        setHistory({ open: true, projectIndex: index, rows: data.backups || [], loading: false, customLimit, autoSelect });
      } catch {
        setHistory({ open: true, projectIndex: index, rows: [], loading: false, customLimit, autoSelect });
      }
    },
    [],
  );

  const onOpenDestination = useCallback(
    async (index) => {
      try {
        const res = await openDestination(index);
        if (res.status !== "success") showToast(res.message || "Failed to open destination.", "error");
      } catch {
        showToast("Failed to open destination.", "error");
      }
    },
    [showToast],
  );

  const onOpenSource = useCallback(
    async (index) => {
      try {
        const res = await openSource(index);
        if (res.status !== "success") showToast(res.message || "Failed to open source.", "error");
      } catch {
        showToast("Failed to open source.", "error");
      }
    },
    [showToast],
  );

  const onRevealBackup = useCallback(
    async (index, filename) => {
      try {
        const res = await revealBackup(index, filename);
        if (res.status !== "success") showToast(res.message || "Failed to reveal backup.", "error");
      } catch {
        showToast("Failed to reveal backup.", "error");
      }
    },
    [showToast],
  );

  const onCloseHistory = useCallback(() => setHistory((h) => ({ ...h, open: false, projectIndex: -1 })), []);

  const onRestoreSpecific = useCallback(
    async (index, filename) => {
      const proj = projects[index];
      const ok = await confirm({
        title: "Restore this version?",
        message: "This will completely overwrite and replace the source contents with the selected backup zip.",
        details: `Source:\n${proj?.source || ""}\n\nBackup:\n${filename}`,
        confirmText: "Restore",
        cancelText: "Cancel",
        variant: "primary",
      });
      if (!ok) return;
      onCloseHistory();
      showToast("Selective restore initiated...", "info");
      try {
        const res = await triggerRestore(index, filename);
        if (res.status === "success") showToast(res.message || "Specific backup version restored successfully!", "success");
        else showToast(res.message || "Selective restore failed.", "error");
        await refreshProjects();
      } catch {
        showToast("Connection error during selective restore.", "error");
      }
    },
    [confirm, onCloseHistory, projects, refreshProjects, showToast],
  );

  const isTooSmall = windowWidth < 800;

  return (
    <>
      {isTooSmall ? (
        <div className={styles.sizeWarning}>
          <Desktop className={styles.sizeWarningIcon} size={64} weight="duotone" />
          <h2 className={styles.sizeWarningTitle}>Window Too Small</h2>
          <p className={styles.sizeWarningText}>Friday requires a wider viewport. Please maximize your browser window or use a larger screen.</p>
        </div>
      ) : (
        <>
      <Header
        onAddProject={onAdd}
        onOpenGlobalSettings={async () => {
          await refreshSettings();
          setGlobalSettingsOpen(true);
        }}
      />
      <main className={styles.main}>
        <div className={styles.cardsGrid} id="projects-container">
          {projects.length === 0 ? (
            <div className={styles.emptyState}>
              <p>Click "+ Add Project" to set up your first folder backup!</p>
            </div>
          ) : (
            projects.map((p, idx) => (
              <ProjectCard
                key={idx}
                project={p}
                index={idx}
                busyAction={busy[idx] || null}
                onBackup={onBackup}
                onHistory={onOpenHistory}
                onEdit={onEdit}
                onPreview={onPreview}
                onRemove={onRemove}
                onRestore={onRestoreLatest}
                onOpenDestination={onOpenDestination}
                onOpenSource={onOpenSource}
                onRevealBackup={onRevealBackup}
                showToast={showToast}
              />
            ))
          )}
        </div>
      </main>

      <SettingsModal
        open={settings.open}
        editIndex={settings.editIndex}
        project={editProjectValue}
        appSettings={appSettings}
        onClose={onCloseSettings}
        onSave={onSaveProject}
        onBrowseFolder={browseFolder}
        onBrowseFile={browseFile}
        showToast={showToast}
      />

      <PreviewModal
        open={previewState.open}
        project={previewState.projectIndex >= 0 ? projects[previewState.projectIndex] : null}
        loading={previewState.loading}
        preview={previewState.data}
        onClose={onClosePreview}
      />

      <HistoryModal
        open={history.open}
        projectIndex={history.projectIndex}
        project={history.projectIndex >= 0 ? projects[history.projectIndex] : null}
        customLimit={history.customLimit}
        autoSelect={history.autoSelect}
        rows={history.rows}
        loading={history.loading}
        onClose={onCloseHistory}
        onRestoreSpecific={(filename) => onRestoreSpecific(history.projectIndex, filename)}
        onDeleteSpecific={(filename) => onDeleteSpecific(history.projectIndex, filename)}
        onDeleteMultiple={(filenames) => onDeleteMultiple(history.projectIndex, filenames)}
      />

      <Toasts toasts={toasts} />

      <ConfirmModal
        open={!!confirmState.open}
        title={confirmState.title}
        message={confirmState.message}
        details={confirmState.details}
        confirmText={confirmState.confirmText}
        cancelText={confirmState.cancelText}
        variant={confirmState.variant}
        onCancel={() => closeConfirm(false)}
        onConfirm={() => closeConfirm(true)}
      />

      <GlobalSettingsModal
        open={globalSettingsOpen}
        settings={appSettings}
        onClose={() => setGlobalSettingsOpen(false)}
        onBrowseFolder={browseFolder}
        onSave={async (payload) => {
          try {
            const res = await saveSettings(payload);
            if (res.status === "success") {
              showToast("Settings saved.", "success");
              setGlobalSettingsOpen(false);
              await refreshSettings();
              await refreshProjects();
            } else {
              showToast(res.message || "Failed to save settings.", "error");
            }
          } catch {
            showToast("Failed to save settings.", "error");
          }
        }}
      />
        </>
      )}
    </>
  );
}
