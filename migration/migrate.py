#!/usr/bin/env python3
"""
Friday Database Migration Tool
Migrates Friday projects and settings from:
1) BoltDB (Go version `friday.db` via exported `app_state` JSON or extractor)
2) JSON dump (e.g. `friday_data.json` or exported `app_state.json`)

Generates a SQLite `friday.db` fully compatible with Friday Flutter (Schema v3).
Optionally inspects existing backup ZIP files in project destinations to automatically
populate the `backups` table with hashes, diffs, and metadata so you can continue
without missing a single backup or version history.
"""

import os
import sys
import json
import sqlite3
import hashlib
import zipfile
from datetime import datetime
from pathlib import Path

DEFAULT_EXCLUSIONS = (
    "*.bak, *.orig, *.log, *.etl, *.evtx, *.cache, *.autosave, "
    "thumbs.db, desktop.ini, .DS_Store, .git, node_modules, .idea, .vscode, vendor, .venv"
)

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS settings (
    id INTEGER PRIMARY KEY CHECK (id = 1),
    global_backup_dir TEXT NOT NULL DEFAULT '',
    use_project_subfolder_default INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS projects (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE,
    source TEXT NOT NULL,
    destination TEXT NOT NULL DEFAULT '',
    version INTEGER NOT NULL DEFAULT 0,
    max_limit INTEGER NOT NULL DEFAULT 5,
    use_global_destination INTEGER NOT NULL DEFAULT 0,
    use_project_subfolder INTEGER NOT NULL DEFAULT 0,
    exclusion_rules TEXT NOT NULL DEFAULT '',
    content_hash TEXT NOT NULL DEFAULT '',
    last_backup TEXT NOT NULL DEFAULT '',
    last_zip_name TEXT NOT NULL DEFAULT '',
    backup_hashes TEXT NOT NULL DEFAULT '{}'
);

CREATE TABLE IF NOT EXISTS backups (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    project_name TEXT NOT NULL,
    filename TEXT NOT NULL UNIQUE,
    version INTEGER NOT NULL,
    timestamp TEXT NOT NULL,
    size INTEGER NOT NULL,
    note TEXT NOT NULL DEFAULT '',
    zip_hash TEXT NOT NULL DEFAULT '',
    integrity TEXT NOT NULL DEFAULT 'verified',
    file_count INTEGER NOT NULL DEFAULT 0,
    folder_count INTEGER NOT NULL DEFAULT 0,
    excluded_count INTEGER NOT NULL DEFAULT 0,
    added_count INTEGER NOT NULL DEFAULT 0,
    modified_count INTEGER NOT NULL DEFAULT 0,
    deleted_count INTEGER NOT NULL DEFAULT 0,
    files TEXT NOT NULL DEFAULT '[]'
);

CREATE INDEX IF NOT EXISTS idx_backups_project_name ON backups (project_name);
CREATE INDEX IF NOT EXISTS idx_backups_filename ON backups (filename);
"""


def sanitize_filename(name: str) -> str:
    import re
    sanitized = re.sub(r'[^\w\-_ ]', '_', name)
    sanitized = sanitized.replace(' ', '_')
    sanitized = re.sub(r'^[_.\-]+|[_.\-]+$', '', sanitized)
    if not sanitized:
        return 'project'
    return sanitized


def format_timestamp(dt: datetime) -> str:
    # Matches Flutter Formatters.formatTimestamp: "19 Oct, 2026 02:13 PM"
    day = dt.day
    month_name = dt.strftime("%b")
    year = dt.year
    hour = dt.strftime("%I").lstrip("0") or "12"
    minute = dt.strftime("%M")
    ampm = dt.strftime("%p")
    return f"{day:02d} {month_name}, {year} {hour}:{minute} {ampm}"


def compute_file_sha256(filepath: str) -> str:
    hasher = hashlib.sha256()
    try:
        with open(filepath, "rb") as f:
            for chunk in iter(lambda: f.read(65536), b""):
                hasher.update(chunk)
        return hasher.hexdigest()
    except Exception:
        return ""


def scan_existing_zips(proj_name: str, dst_folder: str, backup_hashes: dict = None):
    """
    Finds existing backup zips (e.g. Project_v1_YYYY-MM-DD.zip) and
    reads metadata + entries directly from zip files.
    """
    if not os.path.exists(dst_folder):
        return []

    prefix = f"{sanitize_filename(proj_name)}_v"
    records = []
    backup_hashes = backup_hashes or {}

    try:
        entries = sorted(os.listdir(dst_folder))
    except Exception:
        return []

    for item in entries:
        if not (item.startswith(prefix) and item.endswith(".zip")):
            continue

        full_path = os.path.join(dst_folder, item)
        if not os.path.isfile(full_path):
            continue

        # Extract version
        suffix = item[len(prefix):-4]
        parts = suffix.split("_")
        try:
            version = int(parts[0])
        except Exception:
            version = 0

        stat = os.stat(full_path)
        mtime = datetime.fromtimestamp(stat.st_mtime)
        ts_str = format_timestamp(mtime)
        zip_hash = compute_file_sha256(full_path)

        file_count = 0
        folder_count = 0
        file_entries = []
        note = ""
        added_count = 0
        modified_count = 0
        deleted_count = 0
        excluded_count = 0

        # Check integrity against baseline hash or zip structure
        recorded_hash = backup_hashes.get(item, "")
        if recorded_hash:
            if recorded_hash.lower() == zip_hash.lower():
                integrity = "verified"
            else:
                integrity = "corrupted"
        else:
            integrity = "verified"

        try:
            with zipfile.ZipFile(full_path, "r") as zf:
                # Check for metadata embedded by previous Friday versions
                meta = {}
                if "backup_meta.json" in zf.namelist():
                    try:
                        meta = json.loads(zf.read("backup_meta.json").decode("utf-8"))
                    except Exception:
                        meta = {}

                if meta:
                    note = meta.get("note", "").strip()
                    if meta.get("created_local"):
                        ts_str = meta["created_local"]

                for info in zf.infolist():
                    if info.filename == "backup_meta.json":
                        continue
                    if info.is_dir():
                        folder_count += 1
                    else:
                        file_count += 1
                        try:
                            mod_time = int(datetime(*info.date_time).timestamp())
                        except Exception:
                            mod_time = int(stat.st_mtime)

                        file_entries.append({
                            "path": info.filename.replace("\\", "/"),
                            "size": info.file_size,
                            "mod_time": mod_time,
                            "status": "included",
                        })

                if meta.get("files"):
                    file_entries = meta["files"]
                    file_count = meta.get("file_count", file_count)
                    folder_count = meta.get("folder_count", folder_count)
                    added_count = meta.get("added_count", file_count)
                    modified_count = meta.get("modified_count", 0)
                    deleted_count = meta.get("deleted_count", 0)
                    excluded_count = meta.get("excluded_count", 0)
                else:
                    added_count = file_count
        except Exception:
            integrity = "corrupted"

        records.append({
            "project_name": proj_name,
            "filename": item,
            "version": version,
            "timestamp": ts_str,
            "size": stat.st_size,
            "note": note,
            "zip_hash": zip_hash,
            "integrity": integrity,
            "file_count": file_count,
            "folder_count": folder_count,
            "excluded_count": excluded_count,
            "added_count": added_count,
            "modified_count": modified_count,
            "deleted_count": deleted_count,
            "files": json.dumps(file_entries),
        })

    records.sort(key=lambda x: x["version"])
    return records


def migrate_to_sqlite(source_json_path: str, output_sqlite_path: str):
    """
    Reads app data from JSON file and generates a SQLite database.
    """
    if not os.path.isfile(source_json_path):
        print(f"[-] Source JSON file not found: {source_json_path}")
        return False

    with open(source_json_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    settings = data.get("settings", {})
    projects = data.get("projects", [])

    global_backup_dir = settings.get("global_backup_dir", "")
    use_project_subfolder_default = 1 if settings.get("use_project_subfolder_default", False) else 0

    # Ensure output dir exists
    out_dir = os.path.dirname(os.path.abspath(output_sqlite_path))
    if out_dir and not os.path.exists(out_dir):
        os.makedirs(out_dir, exist_ok=True)

    if os.path.exists(output_sqlite_path):
        backup_old = f"{output_sqlite_path}.bak"
        print(f"[*] Existing database found. Creating backup at: {backup_old}")
        try:
            if os.path.exists(backup_old):
                os.remove(backup_old)
            os.rename(output_sqlite_path, backup_old)
        except Exception as e:
            print(f"[!] Warning backing up old database: {e}")

    conn = sqlite3.connect(output_sqlite_path)
    cur = conn.cursor()
    cur.executescript(SCHEMA_SQL)
    cur.execute("PRAGMA user_version = 3;")

    # Insert settings
    cur.execute(
        """
        INSERT OR REPLACE INTO settings (id, global_backup_dir, use_project_subfolder_default)
        VALUES (1, ?, ?)
        """,
        (global_backup_dir, use_project_subfolder_default),
    )

    print(f"[*] Imported settings: global_backup_dir='{global_backup_dir}', default_subfolder={bool(use_project_subfolder_default)}")

    total_projects = 0
    total_backups = 0

    for p in projects:
        name = p.get("name", "").strip()
        if not name:
            continue

        source = p.get("source", "").strip()
        destination = p.get("destination", "").strip()
        version = int(p.get("version", 0))
        limit = int(p.get("limit", 5))
        use_global = 1 if p.get("use_global_destination", False) else 0
        use_subfolder = 1 if p.get("use_project_subfolder", False) else 0
        exclusions = p.get("exclusion_rules", "").strip() or DEFAULT_EXCLUSIONS
        content_hash = p.get("content_hash", "")
        last_backup = p.get("last_backup", "")
        last_zip_name = p.get("last_zip_name", "")
        backup_hashes = p.get("backup_hashes", {})
        if not isinstance(backup_hashes, dict):
            backup_hashes = {}

        cur.execute(
            """
            INSERT OR REPLACE INTO projects (
                name, source, destination, version, max_limit,
                use_global_destination, use_project_subfolder, exclusion_rules,
                content_hash, last_backup, last_zip_name, backup_hashes
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                name,
                source,
                destination,
                version,
                limit,
                use_global,
                use_subfolder,
                exclusions,
                content_hash,
                last_backup,
                last_zip_name,
                json.dumps(backup_hashes),
            ),
        )
        total_projects += 1

        # Scan for existing backups on disk
        effective_dest = global_backup_dir if use_global and global_backup_dir else destination
        if use_subfolder and effective_dest:
            effective_dest = os.path.join(effective_dest, sanitize_filename(name))

        if effective_dest and os.path.exists(effective_dest):
            zip_records = scan_existing_zips(name, effective_dest, backup_hashes)
            for z in zip_records:
                cur.execute(
                    """
                    INSERT OR IGNORE INTO backups (
                        project_name, filename, version, timestamp, size,
                        note, zip_hash, integrity, file_count, folder_count,
                        excluded_count, added_count, modified_count, deleted_count, files
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (
                        z["project_name"],
                        z["filename"],
                        z["version"],
                        z["timestamp"],
                        z["size"],
                        z["note"],
                        z["zip_hash"],
                        z["integrity"],
                        z["file_count"],
                        z["folder_count"],
                        z["excluded_count"],
                        z["added_count"],
                        z["modified_count"],
                        z["deleted_count"],
                        z["files"],
                    ),
                )
                total_backups += 1

    conn.commit()
    conn.close()

    print(f"\n[+] Migration completed successfully!")
    print(f"    - Projects migrated: {total_projects}")
    print(f"    - Backups indexed: {total_backups}")
    print(f"    - Output database: {output_sqlite_path}")
    return True


def main():
    script_dir = Path(__file__).resolve().parent
    default_json = script_dir / "source_app_state.json"
    default_output = script_dir / "friday.db"

    source = sys.argv[1] if len(sys.argv) > 1 else str(default_json)
    output = sys.argv[2] if len(sys.argv) > 2 else str(default_output)

    print("=" * 60)
    print(" Friday Migration Tool: Go/Rust Stack -> Flutter SQLite")
    print("=" * 60)
    print(f"Source JSON : {source}")
    print(f"Target DB   : {output}\n")

    if not os.path.isfile(source):
        print(f"[-] Input file not found: {source}")
        print("\nHow to use:")
        print(f"1. Save your previous source data JSON file as:")
        print(f"   {default_json}")
        print("   OR pass it as argument:")
        print(f"   python migrate.py <path_to_source.json> [path_to_output_friday.db]\n")
        sys.exit(1)

    success = migrate_to_sqlite(source, output)
    if success:
        appdata_target = os.path.expandvars(r"%APPDATA%\Instances\Friday\friday.db")
        print(f"\nTarget path for Friday Flutter app:")
        print(f"-> {appdata_target}")
        print(f"\nYou can now copy the generated '{output}' to that location.")


if __name__ == "__main__":
    main()
