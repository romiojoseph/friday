class AppConstants {
  AppConstants._();

  static const String defaultExclusionRules =
      '*.bak, *.orig, *.log, *.etl, *.evtx, *.cache, *.autosave, thumbs.db, desktop.ini, .DS_Store, .git, node_modules, .idea, .vscode, vendor, .venv';
}

class ProjectStatus {
  ProjectStatus._();

  static const String clean = 'clean';
  static const String modified = 'modified';
  static const String fresh = 'new';
}

class IntegrityStatus {
  IntegrityStatus._();

  static const String verified = 'verified';
  static const String untracked = 'untracked';
  static const String corrupted = 'corrupted';
}

class DiffStatus {
  DiffStatus._();

  static const String added = 'added';
  static const String modified = 'modified';
  static const String deleted = 'deleted';
  static const String skipped = 'skipped';
  static const String unchanged = 'unchanged';
  static const String included = 'included';
}

class BusyAction {
  BusyAction._();

  static const String backup = 'backup';
  static const String cleanup = 'cleanup';
}

class ToastType {
  ToastType._();

  static const String success = 'success';
  static const String error = 'error';
  static const String info = 'info';
}
