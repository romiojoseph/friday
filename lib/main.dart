import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'providers/backup_provider.dart';
import 'services/window_service.dart';
import 'theme/app_colors.dart';

TextTheme _buildGoogleSansTextTheme() {
  final g = GoogleFonts.googleSansTextTheme();
  return TextTheme(
    displayLarge: g.displayLarge,
    displayMedium: g.displayMedium,
    displaySmall: g.displaySmall,
    headlineLarge: g.headlineLarge,
    headlineMedium: g.headlineMedium,
    headlineSmall: g.headlineSmall,
    titleLarge: g.titleLarge,
    titleMedium: g.titleMedium,
    titleSmall: g.titleSmall,
    bodyLarge: g.bodyLarge,
    bodyMedium: g.bodyMedium,
    bodySmall: g.bodySmall,
    labelLarge: g.labelLarge,
    labelMedium: g.labelMedium,
    labelSmall: g.labelSmall,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await WindowService.initialize();

  runApp(const FridayApp());
}

class FridayApp extends StatefulWidget {
  const FridayApp({super.key});

  @override
  State<FridayApp> createState() => _FridayAppState();
}

class _FridayAppState extends State<FridayApp> {
  late final BackupProvider _backupProvider;

  @override
  void initState() {
    super.initState();
    _backupProvider = BackupProvider();
  }

  @override
  void dispose() {
    _backupProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Friday - Desktop Backup Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.neutral1,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryBase,
          surface: AppColors.neutral2,
        ),
        textTheme: _buildGoogleSansTextTheme(),
      ),
      home: ListenableBuilder(
        listenable: _backupProvider,
        builder: (context, _) {
          return HomeScreen(provider: _backupProvider);
        },
      ),
    );
  }
}
