import 'project.dart';
import 'settings.dart';

class AppData {
  final int version;
  final Settings settings;
  final List<Project> projects;

  const AppData({
    this.version = 2,
    this.settings = const Settings(),
    this.projects = const [],
  });

  AppData copyWith({
    int? version,
    Settings? settings,
    List<Project>? projects,
  }) {
    return AppData(
      version: version ?? this.version,
      settings: settings ?? this.settings,
      projects: projects ?? this.projects,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'settings': settings.toJson(),
      'projects': projects.map((p) => p.toJson()).toList(),
    };
  }

  factory AppData.fromJson(Map<String, dynamic> json) {
    var rawProjects = json['projects'];
    List<Project> projectList = [];
    if (rawProjects is List) {
      projectList = rawProjects
          .whereType<Map<String, dynamic>>()
          .map((m) => Project.fromJson(m))
          .toList();
    }

    return AppData(
      version: (json['version'] as num?)?.toInt() ?? 2,
      settings: json['settings'] is Map<String, dynamic>
          ? Settings.fromJson(json['settings'] as Map<String, dynamic>)
          : const Settings(),
      projects: projectList,
    );
  }
}
