import 'dart:io';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class WindowService {
  WindowService._();

  static Future<void> initialize() async {
    if (!Platform.isWindows) return;
    try {
      final window = WindowManager.instance.getCurrent();
      if (window != null) {
        window.title = 'Friday - Desktop Backup Manager';
        window.setSize(const Size(1280, 800).toNative(), false);
        window.minimumSize = const Size(800, 600).toNative();
        window.titleBarStyle = TitleBarStyle.hidden;
        window.center();
        window.maximize();
        window.show();
        window.focus();
      }
    } catch (_) {}
  }

  static Future<void> showAndFocus() async {
    if (!Platform.isWindows) return;
    try {
      final window = WindowManager.instance.getCurrent();
      if (window != null) {
        if (window.isMinimized) {
          window.restore();
        }
        window.show();
        window.focus();
      }
    } catch (_) {}
  }
}
