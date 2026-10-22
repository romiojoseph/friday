import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../models/settings.dart';
import '../../services/explorer_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_dialog.dart';
import '../common/app_text_field.dart';

class GlobalSettingsDialog extends StatefulWidget {
  final Settings settings;
  final Function(Settings settings) onSave;

  const GlobalSettingsDialog({
    super.key,
    required this.settings,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    required Settings settings,
    required Function(Settings settings) onSave,
  }) {
    return AppDialog.show(
      context: context,
      builder: (context) =>
          GlobalSettingsDialog(settings: settings, onSave: onSave),
    );
  }

  @override
  State<GlobalSettingsDialog> createState() => _GlobalSettingsDialogState();
}

class _GlobalSettingsDialogState extends State<GlobalSettingsDialog> {
  late TextEditingController _globalDirController;

  @override
  void initState() {
    super.initState();
    _globalDirController = TextEditingController(
      text: widget.settings.globalBackupDir,
    );
  }

  @override
  void dispose() {
    _globalDirController.dispose();
    super.dispose();
  }

  Future<void> _browse() async {
    final path = await ExplorerService.pickDirectory(
      dialogTitle: 'Select Global Backup Directory',
    );
    if (path != null && path.trim().isNotEmpty) {
      setState(() {
        _globalDirController.text = path.trim();
      });
    }
  }

  void _save() {
    final updated = widget.settings.copyWith(
      globalBackupDir: _globalDirController.text.trim(),
    );
    widget.onSave(updated);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      width: 540,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppDialogHeader(title: 'Global Settings'),

          const SizedBox(height: AppSpacing.lg),

            Text(
              'Global backup folder (optional)',
              style: AppTypography.body.copyWith(
                color: AppColors.neutral9,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _globalDirController,
                    placeholder: r'D:\FridayBackups',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AppButton(
                  variant: ButtonVariant.secondary,
                  icon: const PhosphorIcon(PhosphorIconsDuotone.folderOpen),
                  hoverIcon: const PhosphorIcon(PhosphorIconsFill.folderOpen),
                  text: 'Browse',
                  onClick: _browse,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'If set, projects can opt-in to store backups under this folder.',
              style: AppTypography.caption.copyWith(
                color: AppColors.neutral7,
                fontSize: 12,
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            // Footer
            AppDialogFooter(
              children: [
                AppButton(
                  variant: ButtonVariant.primary,
                  icon: const PhosphorIcon(PhosphorIconsDuotone.checkCircle),
                  hoverIcon: const PhosphorIcon(PhosphorIconsFill.checkCircle),
                  text: 'Save',
                  onClick: _save,
                ),
              ],
            ),
          ],
        ),
      );
  }
}
