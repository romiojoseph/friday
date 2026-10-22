import 'dart:math';
import 'package:intl/intl.dart';

class Formatters {
  Formatters._();

  static String formatBytes(num bytes, [int decimals = 2]) {
    if (bytes <= 0) return '0 Bytes';
    const k = 1024;
    final dm = decimals < 0 ? 0 : decimals;
    const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
    final i = (log(bytes) / log(k)).floor();
    final clampedI = i.clamp(0, sizes.length - 1);
    final count = bytes / pow(k, clampedI);
    return '${count.toStringAsFixed(dm)} ${sizes[clampedI]}';
  }

  static String formatTimestamp(DateTime dateTime) {
    return DateFormat('dd MMM, yyyy hh:mm a').format(dateTime);
  }

  static String sanitizeFilename(String name) {
    var sanitized = name.replaceAll(RegExp(r'[^\w\-_ ]'), '_');
    sanitized = sanitized.replaceAll(' ', '_');
    sanitized = sanitized.replaceAll(RegExp(r'^[_.-]+|[_.-]+$'), '');
    if (sanitized.isEmpty) return 'project';
    return sanitized;
  }
}
