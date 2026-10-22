class Settings {
  final String globalBackupDir;
  final bool useProjectSubfolderDefault;

  const Settings({
    this.globalBackupDir = '',
    this.useProjectSubfolderDefault = false,
  });

  Settings copyWith({
    String? globalBackupDir,
    bool? useProjectSubfolderDefault,
  }) {
    return Settings(
      globalBackupDir: globalBackupDir ?? this.globalBackupDir,
      useProjectSubfolderDefault:
          useProjectSubfolderDefault ?? this.useProjectSubfolderDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'global_backup_dir': globalBackupDir,
      'use_project_subfolder_default': useProjectSubfolderDefault,
    };
  }

  factory Settings.fromJson(Map<String, dynamic> json) {
    return Settings(
      globalBackupDir: json['global_backup_dir'] as String? ?? '',
      useProjectSubfolderDefault:
          json['use_project_subfolder_default'] as bool? ?? false,
    );
  }
}
