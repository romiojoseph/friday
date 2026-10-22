class FileDiffEntry {
  final String path;
  final int? size;
  final int modTime;
  final String status; // "added", "modified", "deleted", "skipped", "unchanged", "included"
  final bool active;
  final String activeReason;

  const FileDiffEntry({
    required this.path,
    this.size,
    this.modTime = 0,
    required this.status,
    this.active = false,
    this.activeReason = '',
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'path': path,
      'size': size,
      'mod_time': modTime,
      'status': status,
    };
    if (active) {
      map['active'] = true;
      map['active_reason'] = activeReason;
    }
    return map;
  }

  FileDiffEntry copyWith({
    String? path,
    int? size,
    int? modTime,
    String? status,
    bool? active,
    String? activeReason,
  }) {
    return FileDiffEntry(
      path: path ?? this.path,
      size: size ?? this.size,
      modTime: modTime ?? this.modTime,
      status: status ?? this.status,
      active: active ?? this.active,
      activeReason: activeReason ?? this.activeReason,
    );
  }

  factory FileDiffEntry.fromJson(Map<String, dynamic> json) {
    int? sizeVal;
    if (json['size'] != null) {
      if (json['size'] is num) {
        sizeVal = (json['size'] as num).toInt();
      }
    }
    int modVal = 0;
    if (json['mod_time'] != null && json['mod_time'] is num) {
      modVal = (json['mod_time'] as num).toInt();
    }
    return FileDiffEntry(
      path: json['path'] as String? ?? '',
      size: sizeVal,
      modTime: modVal,
      status: json['status'] as String? ?? 'unchanged',
      active: json['active'] as bool? ?? false,
      activeReason: json['active_reason'] as String? ?? '',
    );
  }
}
