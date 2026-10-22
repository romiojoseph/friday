import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowService {
  WindowService._();

  static Future<void> initialize() async {
    if (!Platform.isWindows) return;
    try {
      await windowManager.ensureInitialized();

      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(800, 600),
        center: true,
        backgroundColor: Colors.transparent,
        skipTaskbar: false,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'Friday - Desktop Backup Manager',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.maximize();
        await windowManager.show();
        await windowManager.focus();
      });
    } catch (_) {}
  }

  static Future<void> showAndFocus() async {
    if (!Platform.isWindows) return;
    try {
      final isMin = await windowManager.isMinimized();
      if (isMin) {
        await windowManager.restore();
      }
      await windowManager.show();
      await windowManager.focus();
    } catch (_) {}
  }
}
