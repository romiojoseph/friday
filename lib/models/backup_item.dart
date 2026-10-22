import 'dart:convert';
import 'file_diff_entry.dart';

class BackupItem {
  final String filename;
  final int version;
  final String timestamp;
  final int size;
  final String note;
  final String zipHash;
  final String integrity; // "verified", "untracked", "corrupted"
  final int fileCount;
  final int folderCount;
  final int excludedCount;
  final int addedCount;
  final int modifiedCount;
  final int deletedCount;
  final List<FileDiffEntry> files;

  const BackupItem({
    required this.filename,
    required this.version,
    required this.timestamp,
    required this.size,
    this.note = '',
    this.zipHash = '',
    this.integrity = 'verified',
    this.fileCount = 0,
    this.folderCount = 0,
    this.excludedCount = 0,
    this.addedCount = 0,
    this.modifiedCount = 0,
    this.deletedCount = 0,
    this.files = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'version': version,
      'timestamp': timestamp,
      'size': size,
      'note': note,
      'zip_hash': zipHash,
      'integrity': integrity,
      'file_count': fileCount,
      'folder_count': folderCount,
      'excluded_count': excludedCount,
      'added_count': addedCount,
      'modified_count': modifiedCount,
      'deleted_count': deletedCount,
      'files': files.map((f) => f.toJson()).toList(),
    };
  }

  factory BackupItem.fromJson(Map<String, dynamic> json) {
    var rawFiles = json['files'];
    if (rawFiles is String) {
      try {
        rawFiles = jsonDecode(rawFiles);
      } catch (_) {
        rawFiles = [];
      }
    }
    List<FileDiffEntry> fileEntries = [];
    if (rawFiles is List) {
      for (final item in rawFiles) {
        if (item is Map) {
          fileEntries.add(FileDiffEntry.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    int toInt(dynamic val, [int defaultValue = 0]) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val) ?? defaultValue;
      return defaultValue;
    }

    return BackupItem(
      filename: json['filename'] as String? ?? '',
      version: toInt(json['version']),
      timestamp: json['timestamp'] as String? ?? '',
      size: toInt(json['size']),
      note: json['note'] as String? ?? '',
      zipHash: json['zip_hash'] as String? ?? '',
      integrity: json['integrity'] as String? ?? 'verified',
      fileCount: toInt(json['file_count']),
      folderCount: toInt(json['folder_count']),
      excludedCount: toInt(json['excluded_count']),
      addedCount: toInt(json['added_count']),
      modifiedCount: toInt(json['modified_count']),
      deletedCount: toInt(json['deleted_count']),
      files: fileEntries,
    );
  }
}
