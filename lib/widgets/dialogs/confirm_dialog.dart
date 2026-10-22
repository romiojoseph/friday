import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';
import '../common/app_button.dart';
import '../common/app_dialog.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String? message;
  final String? details;
  final String confirmText;
  final String cancelText;
  final ButtonVariant variant;

  const ConfirmDialog({
    super.key,
    required this.title,
    this.message,
    this.details,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.variant = ButtonVariant.primary,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    String? details,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    ButtonVariant variant = ButtonVariant.primary,
  }) async {
    final result = await AppDialog.show<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: title,
        message: message,
        details: details,
        confirmText: confirmText,
        cancelText: cancelText,
        variant: variant,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AppDialog(
      width: 500,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDialogHeader(
            title: title,
            onClose: () => Navigator.of(context).pop(false),
          ),
          if (message != null && message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              message!,
              style: AppTypography.body.copyWith(
                color: AppColors.neutral9,
                fontSize: 14,
              ),
            ),
          ],
          if (details != null && details!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: ShapeDecoration(
                color: AppColors.neutral1,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(color: AppColors.neutral3),
                ),
              ),
              child: SelectableText(
                details!,
                style: AppTypography.subtitle.copyWith(
                  color: AppColors.neutral10,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppDialogFooter(
            children: [
              AppButton(
                variant: ButtonVariant.secondary,
                text: cancelText,
                onClick: () => Navigator.of(context).pop(false),
              ),
              AppButton(
                variant: variant,
                icon: const PhosphorIcon(
                  PhosphorIconsDuotone.checkCircle,
                  size: 20,
                ),
                hoverIcon: const PhosphorIcon(
                  PhosphorIconsFill.checkCircle,
                  size: 20,
                ),
                text: confirmText,
                onClick: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
