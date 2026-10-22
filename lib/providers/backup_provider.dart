import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/app_data.dart';
import '../models/backup_item.dart';
import '../models/project.dart';
import '../models/settings.dart';
import '../services/backup_service.dart';
import '../services/notification_service.dart';
import '../services/database_service.dart';

class BackupProvider extends ChangeNotifier {
  final DatabaseService _databaseService = DatabaseService();
  final BackupService _backupService = const BackupService();

  AppData _appData = const AppData();
  bool _isLoading = true;
  bool _initialLoadAlerted = false;
  Timer? _scanTimer;
  final Map<int, String> _busy = {};

  Function(String message, String type)? onToast;

  BackupProvider() {
    _initialize();
  }

  AppData get appData => _appData;
  Settings get settings => _appData.settings;
  List<Project> get projects => _appData.projects;
  bool get isLoading => _isLoading;
  Map<int, String> get busy => _busy;

  Future<void> _initialize() async {
    await NotificationService.initialize();

    await loadAndScan();

    _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_busy.isEmpty) {
        refreshProjects();
      }
    });
  }

  Future<void> loadAndScan() async {
    _isLoading = true;
    notifyListeners();

    _appData = await _databaseService.loadData();
    await refreshProjects();

    _isLoading = false;
    notifyListeners();
  }

  bool _isScanning = false;

  Future<void> refreshProjects() async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      final snapshot = List<Project>.from(_appData.projects);
      if (snapshot.isEmpty) return;

      final updatedProjects = <Project>[];

      for (int i = 0; i < snapshot.length; i++) {
        final proj = snapshot[i];
        final dstEffective = _backupService.resolveDestination(proj, _appData.settings);
        final pName = proj.name;
        final (dstSize, dstCount) = await Isolate.run(() => const BackupService().calculateDestStats(dstEffective, pName));

        String lastZipPath = '';
        if (proj.lastZipName.isNotEmpty && dstEffective.isNotEmpty) {
          lastZipPath = p.join(dstEffective, proj.lastZipName);
        }

        final pSource = proj.source;
        final pExclusion = proj.exclusionRules;
        final scan = await Isolate.run(() => const BackupService().scanProject(
          pSource,
          pExclusion,
          lastZipPath: lastZipPath,
        ));

        String status = 'clean';
        if (proj.version == 0) {
          status = 'new';
        } else if (scan.currentHash != proj.contentHash) {
          status = 'modified';
        }

        updatedProjects.add(proj.copyWith(
          srcSize: scan.size,
          srcCount: scan.count,
          dstSize: dstSize,
          dstCount: dstCount,
          destinationEffective: dstEffective,
          status: status,
          currentHash: scan.currentHash,
          activeWrites: scan.hasActive,
          activeWritesReason: scan.activeReason,
        ));
      }

      // Merge scanned results back into current state so newly added projects are never wiped.
      // Apply scan-derived runtime fields on top of the CURRENT project (not the stale snapshot),
      // so any edits that happened while scanning (e.g. exclusionRules change) are preserved.
      final currentMap = {for (final p in _appData.projects) p.name: p};
      final merged = <Project>[];
      for (final scanned in updatedProjects) {
        final current = currentMap[scanned.name];
        if (current != null) {
          merged.add(current.copyWith(
            srcSize: scanned.srcSize,
            srcCount: scanned.srcCount,
            dstSize: scanned.dstSize,
            dstCount: scanned.dstCount,
            destinationEffective: scanned.destinationEffective,
            status: scanned.status,
            currentHash: scanned.currentHash,
            activeWrites: scanned.activeWrites,
            activeWritesReason: scanned.activeWritesReason,
          ));
          currentMap.remove(scanned.name);
        }
      }
      // Add any projects that were created while scanning
      merged.addAll(currentMap.values);

      _appData = _appData.copyWith(projects: merged);
      notifyListeners();

      if (!_initialLoadAlerted && updatedProjects.isNotEmpty) {
        final modifiedCount = updatedProjects.where((p) => p.status == 'modified').length;
        if (modifiedCount > 0) {
          onToast?.call(
            '$modifiedCount project(s) have unsaved changes since last backup.',
            'info',
          );
        }
        _initialLoadAlerted = true;
      }
    } finally {
      _isScanning = false;
    }
  }

  Future<bool> addProject(Project project) async {
    final currentList = List<Project>.from(_appData.projects);
    currentList.add(project);
    _appData = _appData.copyWith(projects: currentList);
    notifyListeners();
    await _databaseService.saveProjects(currentList);
    unawaited(refreshProjects());
    return true;
  }

  Future<bool> editProject(int index, Project updated) async {
    if (index < 0 || index >= _appData.projects.length) return false;
    final currentList = List<Project>.from(_appData.projects);
    currentList[index] = updated;
    _appData = _appData.copyWith(projects: currentList);
    notifyListeners();
    await _databaseService.saveProjects(currentList);
    unawaited(refreshProjects());
    return true;
  }

  Future<bool> removeProject(int index) async {
    if (index < 0 || index >= _appData.projects.length) return false;
    final currentList = List<Project>.from(_appData.projects);
    currentList.removeAt(index);
    _appData = _appData.copyWith(projects: currentList);
    notifyListeners();
    await _databaseService.saveProjects(currentList);
    unawaited(refreshProjects());
    return true;
  }

  Future<BackupResult> triggerBackup(int index, String note) async {
    if (index < 0 || index >= _appData.projects.length) {
      return const BackupResult(success: false, message: 'Invalid project index.');
    }

    final project = _appData.projects[index];
    final settings = _appData.settings;
    final dstEffective = _backupService.resolveDestination(project, settings);

    // Fast check: If background scan already knows the project is clean and up to date
    if (project.version > 0 && project.status == 'clean' && project.lastZipName.isNotEmpty) {
      final zipFile = File(p.join(dstEffective, project.lastZipName));
      if (zipFile.existsSync()) {
        return const BackupResult(
          success: false,
          skipped: true,
          message: 'No changes detected, backup skipped.',
        );
      }
    }

    _busy[index] = 'backup';
    notifyListeners();

    try {
      final existingBackups = await _databaseService.getBackupsForProject(project.name);
      final previousFiles = existingBackups.isNotEmpty ? existingBackups.first.files : null;

      final res = await Isolate.run(() => const BackupService().doBackup(
        project,
        settings,
        note,
        previousFiles: previousFiles,
      ));

      if (res.success && res.newVersion != null) {
        if (res.backupItem != null) {
          await _databaseService.insertBackupRecord(project.name, res.backupItem!);
        }

        final updatedHashes = Map<String, String>.from(project.backupHashes);
        if (res.zipName != null && res.zipHash != null) {
          updatedHashes[res.zipName!] = res.zipHash!;
        }

        final updatedProject = project.copyWith(
          version: res.newVersion,
          lastBackup: res.lastBackup,
          contentHash: res.contentHash,
          lastZipName: res.zipName,
          backupHashes: updatedHashes,
        );

        final currentList = List<Project>.from(_appData.projects);
        currentList[index] = updatedProject;
        _appData = _appData.copyWith(projects: currentList);
        await _databaseService.saveProjects(currentList);
      }

      await refreshProjects();
      return res;
    } finally {
      _busy.remove(index);
      notifyListeners();
    }
  }


  Future<(bool, String, int)> triggerCleanup(int index, int limit) async {
    if (index < 0 || index >= _appData.projects.length) {
      return (false, 'Invalid project index.', 0);
    }

    _busy[index] = 'cleanup';
    notifyListeners();

    try {
      var project = _appData.projects[index];
      if (limit > 0) {
        project = project.copyWith(limit: limit);
      }
      final settings = _appData.settings;
      final pLimit = project.limit;
      final (ok, msg, count) = await Isolate.run(() => const BackupService().cleanOldBackups(
        project,
        settings,
        pLimit,
      ));

      if (ok) {
        final currentList = List<Project>.from(_appData.projects);
        currentList[index] = project;
        _appData = _appData.copyWith(projects: currentList);
        await _databaseService.saveProjects(currentList);
      }

      await refreshProjects();
      return (ok, msg, count);
    } finally {
      _busy.remove(index);
      notifyListeners();
    }
  }

  Future<int> deleteBackups(int index, List<String> filenames) async {
    if (index < 0 || index >= _appData.projects.length) return 0;
    var project = _appData.projects[index];
    final settings = _appData.settings;

    final deleted = await Isolate.run(() => const BackupService().deleteBackups(
      project,
      settings,
      filenames,
    ));

    await _databaseService.deleteBackupRecords(filenames);

    final updatedHashes = Map<String, String>.from(project.backupHashes);
    bool deletedLatest = false;
    for (final name in filenames) {
      updatedHashes.remove(name);
      if (name == project.lastZipName) {
        deletedLatest = true;
      }
    }

    project = project.copyWith(backupHashes: updatedHashes);

    if (deletedLatest) {
      project = await Isolate.run(() {
        Project synced = project;
        const BackupService().syncProjectStateAfterDeletion(
          project,
          settings,
          onUpdate: (s) => synced = s,
        );
        return synced;
      });
    }

    final currentList = List<Project>.from(_appData.projects);
    currentList[index] = project;
    _appData = _appData.copyWith(projects: currentList);
    await _databaseService.saveProjects(currentList);

    await refreshProjects();
    return deleted;
  }

  Future<void> saveSettings(Settings newSettings) async {
    _appData = _appData.copyWith(settings: newSettings);
    await _databaseService.saveSettings(newSettings);
    await refreshProjects();
  }

  Future<List<BackupItem>> fetchBackups(int index) async {
    if (index < 0 || index >= _appData.projects.length) return [];
    final project = _appData.projects[index];
    final settings = _appData.settings;
    final dbList = await _databaseService.getBackupsForProject(project.name);
    final dbMap = {for (final b in dbList) b.filename: b};

    final backups = await Isolate.run(() => const BackupService().listProjectBackups(
      project,
      settings,
      dbBackups: dbMap,
    ));

    for (final b in backups) {
      final existing = dbMap[b.filename];
      if (existing == null || (existing.note.isEmpty && b.note.isNotEmpty)) {
        await _databaseService.insertBackupRecord(project.name, b);
      }
    }

    return backups;
  }

  Future<ProjectScanResult> fetchPreview(int index) async {
    if (index < 0 || index >= _appData.projects.length) {
      return const ProjectScanResult(
        size: 0,
        count: 0,
        hasActive: false,
        activeReason: '',
        currentHash: '',
        files: [],
      );
    }

    final project = _appData.projects[index];
    final dstEffective = _backupService.resolveDestination(project, _appData.settings);
    String lastZipPath = '';
    if (project.lastZipName.isNotEmpty && dstEffective.isNotEmpty) {
      lastZipPath = p.join(dstEffective, project.lastZipName);
    }

    final dbList = await _databaseService.getBackupsForProject(project.name);
    final previousFiles = dbList.isNotEmpty ? dbList.first.files : null;

    final pSource = project.source;
    final pExclusion = project.exclusionRules;
    return await Isolate.run(() => const BackupService().scanProject(
      pSource,
      pExclusion,
      lastZipPath: lastZipPath,
      previousFiles: previousFiles,
    ));
  }


  @override
  void dispose() {
    _scanTimer?.cancel();
    _databaseService.close();
    super.dispose();
  }
}
