import 'dart:io';
import 'package:local_notifier/local_notifier.dart';

class NotificationService {
  NotificationService._();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      await localNotifier.setup(
        appName: 'Friday',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
    } catch (_) {}
  }

  static String _sanitizePowerShell(String s) {
    var res = s.replaceAll("'", "''");
    res = res.replaceAll('`', '``');
    res = res.replaceAll(String.fromCharCode(36), '`\$');
    res = res.replaceAll(';', '`;');
    res = res.replaceAll('|', '`|');
    res = res.replaceAll('(', '`(');
    res = res.replaceAll(')', '`)');
    return res;
  }

  static Future<void> showNotification({
    required String title,
    required String message,
    String? launchPath,
  }) async {
    // If launchPath is present, invoke Windows PowerShell toast manager
    if (launchPath != null && launchPath.isNotEmpty && Platform.isWindows) {
      try {
        final safeTitle = _sanitizePowerShell(title);
        final safeMessage = _sanitizePowerShell(message);
        var formattedPath = _sanitizePowerShell(launchPath).replaceAll(r'\', '/');
        if (!formattedPath.startsWith('/')) {
          formattedPath = '/$formattedPath';
        }
        final protocolPath = 'file://$formattedPath';

        final psScript = '''
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] | Out-Null
\$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
\$textNodes = \$template.GetElementsByTagName("text")
\$textNodes.Item(0).AppendChild(\$template.CreateTextNode('$safeTitle')) | Out-Null
\$textNodes.Item(1).AppendChild(\$template.CreateTextNode('$safeMessage')) | Out-Null
\$xml = [Windows.Data.Xml.Dom.XmlDocument]::new()
\$xml.LoadXml(\$template.GetXml())
\$toastEl = \$xml.SelectSingleNode("/toast")
\$actions = \$xml.CreateElement("actions")
\$action = \$xml.CreateElement("action")
\$action.SetAttribute("content", "Open Destination")
\$action.SetAttribute("arguments", '$protocolPath')
\$action.SetAttribute("activationType", "protocol")
\$actions.AppendChild(\$action) | Out-Null
\$toastEl.AppendChild(\$actions) | Out-Null
\$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("explorer.exe").Show(\$toast)
''';
        await Process.run(
          'powershell',
          ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-Command', psScript],
          runInShell: true,
        );
        return;
      } catch (_) {}
    }

    try {
      if (!_initialized) await initialize();
      final notification = LocalNotification(
        title: title,
        body: message,
      );
      await notification.show();
    } catch (_) {}
  }
}
