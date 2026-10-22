import 'dart:io';
import 'package:file_picker/file_picker.dart';

class ExplorerService {
  ExplorerService._();

  static Future<bool> openInExplorer(String path) async {
    try {
      final isDir = await Directory(path).exists();
      final isFile = await File(path).exists();
      if (!isDir && !isFile) {
        return false;
      }
      await Process.run('explorer', [path]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> revealInExplorer(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        final dir = Directory(filePath);
        if (!await dir.exists()) return false;
      }
      await Process.run('explorer', ['/select,', filePath]);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<String?> pickDirectory({String? dialogTitle}) async {
    try {
      final result = await FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle ?? 'Select Backup Directory',
      );
      return result;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> pickFile({String? dialogTitle}) async {
    try {
      final result = await FilePicker.pickFile(
        dialogTitle: dialogTitle ?? 'Select Source File',
      );
      return result?.path;
    } catch (_) {
      return null;
    }
  }
}
