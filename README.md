# Friday: Desktop Backup Manager
A lightweight backup manager for Windows. Create versioned snapshots of your projects.

If you are already using the previous version (commit `f1f0f7d`) which was built with Go · React · Vite, check out the [Migration Guide](migration/README.md) to migrate your existing projects, settings, and verified backup history. The application was migrated to Flutter for simplicity and native desktop appearance. I hadn't considered Flutter initially and wanted to keep it light, but as I used it regularly, Flutter proved to be the right choice for this tool.

> This is a vibe-coded project, built entirely with AI assistance. I handled the design, while the logic was AI-generated and refined through iterative prompting. Use it or fork it.

---

## Features

- **Versioned Snapshots**: Automatic incremental backup versioning (`_v1`, `_v2`, etc.) with ZIP compression and content hashing.
- **Diff Visualization**: Live tracking of project file changes (`+` added, `~` modified, `-` deleted, `∅` excluded) before and after creating backups.
- **Smart Exclusion Engine**:
  - Filter out unnecessary files and folders.
  - Stack preset templates for **Web** (`node_modules`, `.next`, `dist`, etc.), **Flutter**, **Python**, **Rust**, **Go**, **Kotlin**, and **Docker**.
  - **Early Directory Pruning**: Prunes excluded directories at root level during scanning so heavy vendor directories (`node_modules`, `.next`) never cause UI freezing or lag.
- **Pre-backup Preview**: Inspect files and their status before committing a backup.
- **Backup History & Integrity**:
  - Inspect files inside any past backup.
  - SHA-256 ZIP checksum verification and corrupted archive detection.
  - Single or multi-select deletion of previous backup snapshots.
- **Flexible Destinations**: Save backups directly into project-specific destination folders or route them into a centralized global backup directory.

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/install/quick) 3.12+ with Windows desktop support enabled
- Windows 10 or 11
- Visual Studio 2022 (with the **"Desktop development with C++"** workload installed)

---

## Build

### Using the Build Script (Recommended)

Run the interactive build assistant from PowerShell:

```powershell
.\build.ps1
```

- Select option `2` to build the Windows Release executable.
- The script automatically compiles the release build and prompts to open the output directory in Explorer.

### Using Flutter CLI

Build a Windows Release standalone bundle directly:

```powershell
flutter build windows --release
```

The output executable and required runner libraries will be generated at:
```
build\windows\x64\runner\Release\
```