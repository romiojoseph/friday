# Friday Database Migration Guide

This directory contains `migrate.py` to migrate projects, settings, and backup history from previous Friday versions into Friday Flutter's SQLite database (`friday.db`).

> [!NOTE]
> This is only applicable if you are migrating data from the previous Go · React · Vite version (commit `f1f0f7d`) to Friday Flutter. If you are starting fresh, no migration is required.

---

## Prerequisites
- **Python 3.8+** (standard library only: `json`, `sqlite3`, `hashlib`, `zipfile`, `datetime`, `pathlib`).
- **Source JSON file**: Exported data file (Click the "View RAW Database" button in the Global Settings Modal) from previous Friday installation (e.g. `source_app_state.json` or `friday_data.json`).
- **Disk Access**: Ensure the backup destination folders are accessible so existing `.zip` archives can be scanned and verified.

---

## Source JSON Schema & Expected Types

The migration script expects a JSON object matching this structure:

```json
{
  "version": 2,
  "settings": {
    "global_backup_dir": "string",
    "use_project_subfolder_default": true
  },
  "projects": [
    {
      "name": "string",
      "source": "string",
      "destination": "string",
      "version": 0,
      "limit": 5,
      "use_global_destination": true,
      "use_project_subfolder": true,
      "exclusion_rules": "string",
      "content_hash": "string",
      "last_backup": "string",
      "last_zip_name": "string",
      "backup_hashes": {
        "string": "string"
      }
    }
  ]
}
```

## What It Migrates & Generates
1. **`settings` Table**: Preserves global backup directory and subfolder defaults.
2. **`projects` Table**: Populates project definitions, paths, exclusion rules, limits, and version counters.
3. **`backups` Table**:
   - Inspects existing `.zip` archives in destination folders.
   - Computes SHA-256 hashes and cross-references `backup_hashes`.
   - Reads archive metadata to recover file counts, folder counts, and timestamps.
   - Sets integrity status to `'verified'`.

---

## How To Run

From the `migration/` directory:

```powershell
python migrate.py
```

*Default: looks for source_app_state.json and generates friday.db*


After generating `friday.db`, copy it to Friday's application data directory:

```powershell
Copy-Item friday.db "$env:APPDATA\Instances\Friday\friday.db" -Force
```
