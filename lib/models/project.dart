import '../utils/app_constants.dart';

const String defaultExclusionRules = AppConstants.defaultExclusionRules;

class Project {
  final String name;
  final String source;
  final String destination;
  final int version;
  final int limit;
  final bool useGlobalDestination;
  final bool useProjectSubfolder;
  final String exclusionRules;
  final String contentHash;
  final String lastBackup;
  final String lastZipName;
  final Map<String, String> backupHashes;

  // Runtime computed scan properties
  final int srcSize;
  final int srcCount;
  final int dstSize;
  final int dstCount;
  final String destinationEffective;
  final String status; // "clean", "modified", "new"
  final String currentHash;
  final bool activeWrites;
  final String activeWritesReason;

  const Project({
    required this.name,
    required this.source,
    this.destination = '',
    this.version = 0,
    this.limit = 5,
    this.useGlobalDestination = false,
    this.useProjectSubfolder = false,
    this.exclusionRules = defaultExclusionRules,
    this.contentHash = '',
    this.lastBackup = '',
    this.lastZipName = '',
    this.backupHashes = const {},
    this.srcSize = 0,
    this.srcCount = 0,
    this.dstSize = 0,
    this.dstCount = 0,
    this.destinationEffective = '',
    this.status = 'new',
    this.currentHash = '',
    this.activeWrites = false,
    this.activeWritesReason = '',
  });

  Project copyWith({
    String? name,
    String? source,
    String? destination,
    int? version,
    int? limit,
    bool? useGlobalDestination,
    bool? useProjectSubfolder,
    String? exclusionRules,
    String? contentHash,
    String? lastBackup,
    String? lastZipName,
    Map<String, String>? backupHashes,
    int? srcSize,
    int? srcCount,
    int? dstSize,
    int? dstCount,
    String? destinationEffective,
    String? status,
    String? currentHash,
    bool? activeWrites,
    String? activeWritesReason,
  }) {
    return Project(
      name: name ?? this.name,
      source: source ?? this.source,
      destination: destination ?? this.destination,
      version: version ?? this.version,
      limit: limit ?? this.limit,
      useGlobalDestination: useGlobalDestination ?? this.useGlobalDestination,
      useProjectSubfolder: useProjectSubfolder ?? this.useProjectSubfolder,
      exclusionRules: exclusionRules ?? this.exclusionRules,
      contentHash: contentHash ?? this.contentHash,
      lastBackup: lastBackup ?? this.lastBackup,
      lastZipName: lastZipName ?? this.lastZipName,
      backupHashes: backupHashes ?? this.backupHashes,
      srcSize: srcSize ?? this.srcSize,
      srcCount: srcCount ?? this.srcCount,
      dstSize: dstSize ?? this.dstSize,
      dstCount: dstCount ?? this.dstCount,
      destinationEffective: destinationEffective ?? this.destinationEffective,
      status: status ?? this.status,
      currentHash: currentHash ?? this.currentHash,
      activeWrites: activeWrites ?? this.activeWrites,
      activeWritesReason: activeWritesReason ?? this.activeWritesReason,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'source': source,
      'destination': destination,
      'version': version,
      'limit': limit,
      'use_global_destination': useGlobalDestination,
      'use_project_subfolder': useProjectSubfolder,
      'exclusion_rules': exclusionRules,
      if (contentHash.isNotEmpty) 'content_hash': contentHash,
      if (lastBackup.isNotEmpty) 'last_backup': lastBackup,
      if (lastZipName.isNotEmpty) 'last_zip_name': lastZipName,
      if (backupHashes.isNotEmpty) 'backup_hashes': backupHashes,
    };
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    Map<String, String> hashes = {};
    if (json['backup_hashes'] is Map) {
      (json['backup_hashes'] as Map).forEach((k, v) {
        if (k is String && v is String) hashes[k] = v;
      });
    }

    int toInt(dynamic val, [int defaultValue = 0]) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    return Project(
      name: json['name'] as String? ?? '',
      source: json['source'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      version: toInt(json['version']),
      limit: toInt(json['limit'], 5),
      useGlobalDestination: json['use_global_destination'] as bool? ?? false,
      useProjectSubfolder: json['use_project_subfolder'] as bool? ?? false,
      exclusionRules: json['exclusion_rules'] as String? ?? '',
      contentHash: json['content_hash'] as String? ?? '',
      lastBackup: json['last_backup'] as String? ?? '',
      lastZipName: json['last_zip_name'] as String? ?? '',
      backupHashes: hashes,
      srcSize: toInt(json['src_size']),
      srcCount: toInt(json['src_count']),
      dstSize: toInt(json['dst_size']),
      dstCount: toInt(json['dst_count']),
      destinationEffective: json['destination_effective'] as String? ?? '',
      status: json['status'] as String? ?? 'new',
      activeWrites: json['active_writes'] as bool? ?? false,
      activeWritesReason: json['active_writes_reason'] as String? ?? '',
    );
  }
}
