import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../models/app_data.dart';
import '../models/backup_item.dart';
import '../models/project.dart';
import '../models/settings.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    sqfliteFfiInit();

    String dbDirectory;
    try {
      final appSupportDir = await getApplicationSupportDirectory();
      dbDirectory = appSupportDir.path;
    } catch (_) {
      dbDirectory = Directory.current.path;
    }

    final dbDir = Directory(dbDirectory);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final dbPath = p.join(dbDirectory, 'friday.db');

    return await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS settings (
              id INTEGER PRIMARY KEY CHECK (id = 1),
              global_backup_dir TEXT NOT NULL DEFAULT '',
              use_project_subfolder_default INTEGER NOT NULL DEFAULT 0
            )
          ''');

          await db.insert('settings', {
            'id': 1,
            'global_backup_dir': '',
            'use_project_subfolder_default': 0,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);

          await db.execute('''
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
            )
          ''');

          await db.execute('''
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
            )
          ''');

          try {
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_backups_project_name ON backups (project_name);',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_backups_filename ON backups (filename);',
            );
          } catch (_) {}
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute('''
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
              )
            ''');
          }
          if (oldVersion < 3) {
            try {
              await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_backups_project_name ON backups (project_name);',
              );
              await db.execute(
                'CREATE INDEX IF NOT EXISTS idx_backups_filename ON backups (filename);',
              );
            } catch (_) {}
          }
        },
      ),
    );
  }

  Future<AppData> loadData() async {
    try {
      final db = await database;

      Settings settings = const Settings();
      final settingsRows = await db.query('settings', where: 'id = ?', whereArgs: [1]);
      if (settingsRows.isNotEmpty) {
        final row = settingsRows.first;
        settings = Settings(
          globalBackupDir: row['global_backup_dir'] as String? ?? '',
          useProjectSubfolderDefault: (row['use_project_subfolder_default'] as int? ?? 0) == 1,
        );
      }

      final projectRows = await db.query('projects', orderBy: 'id ASC');
      final projects = projectRows.map((row) {
        Map<String, String> hashes = {};
        final rawHashes = row['backup_hashes'] as String? ?? '{}';
        try {
          final decoded = jsonDecode(rawHashes);
          if (decoded is Map) {
            decoded.forEach((k, v) {
              if (k is String && v is String) hashes[k] = v;
            });
          }
        } catch (_) {}

        return Project(
          name: row['name'] as String? ?? '',
          source: row['source'] as String? ?? '',
          destination: row['destination'] as String? ?? '',
          version: row['version'] as int? ?? 0,
          limit: row['max_limit'] as int? ?? 5,
          useGlobalDestination: (row['use_global_destination'] as int? ?? 0) == 1,
          useProjectSubfolder: (row['use_project_subfolder'] as int? ?? 0) == 1,
          exclusionRules: row['exclusion_rules'] as String? ?? '',
          contentHash: row['content_hash'] as String? ?? '',
          lastBackup: row['last_backup'] as String? ?? '',
          lastZipName: row['last_zip_name'] as String? ?? '',
          backupHashes: hashes,
        );
      }).toList();

      return AppData(
        version: 3,
        settings: settings,
        projects: projects,
      );
    } catch (e, st) {
      debugPrint('[DatabaseService] Error loading data: $e\n$st');
      return const AppData();
    }
  }

  Future<void> saveSettings(Settings settings) async {
    final db = await database;
    await db.insert(
      'settings',
      {
        'id': 1,
        'global_backup_dir': settings.globalBackupDir,
        'use_project_subfolder_default': settings.useProjectSubfolderDefault ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> saveProjects(List<Project> projects) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('projects');
      final batch = txn.batch();
      for (final p in projects) {
        batch.insert('projects', {
          'name': p.name,
          'source': p.source,
          'destination': p.destination,
          'version': p.version,
          'max_limit': p.limit,
          'use_global_destination': p.useGlobalDestination ? 1 : 0,
          'use_project_subfolder': p.useProjectSubfolder ? 1 : 0,
          'exclusion_rules': p.exclusionRules,
          'content_hash': p.contentHash,
          'last_backup': p.lastBackup,
          'last_zip_name': p.lastZipName,
          'backup_hashes': jsonEncode(p.backupHashes),
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> insertBackupRecord(String projectName, BackupItem item) async {
    final db = await database;
    await db.insert(
      'backups',
      {
        'project_name': projectName,
        'filename': item.filename,
        'version': item.version,
        'timestamp': item.timestamp,
        'size': item.size,
        'note': item.note,
        'zip_hash': item.zipHash,
        'integrity': item.integrity,
        'file_count': item.fileCount,
        'folder_count': item.folderCount,
        'excluded_count': item.excludedCount,
        'added_count': item.addedCount,
        'modified_count': item.modifiedCount,
        'deleted_count': item.deletedCount,
        'files': jsonEncode(item.files.map((f) => f.toJson()).toList()),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<BackupItem>> getBackupsForProject(String projectName) async {
    final db = await database;
    final rows = await db.query(
      'backups',
      where: 'project_name = ?',
      whereArgs: [projectName],
      orderBy: 'version DESC',
    );

    return rows.map((r) => BackupItem.fromJson(r)).toList();
  }

  Future<void> deleteBackupRecords(List<String> filenames) async {
    if (filenames.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(filenames.length, '?').join(',');
    await db.delete('backups', where: 'filename IN ($placeholders)', whereArgs: filenames);
  }


  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
  }
}
