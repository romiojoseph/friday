import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

/// Reusable compact badge for copying text to clipboard with optional toast notification.
class AppCopyBadge extends StatelessWidget {
  final String text;
  final String label;
  final void Function(String message, String type)? onToast;
  final String? toastMessage;
  final VoidCallback? onCopied;

  const AppCopyBadge({
    super.key,
    required this.text,
    this.label = 'Copy',
    this.onToast,
    this.toastMessage,
    this.onCopied,
  });

  Future<void> _handleCopy() async {
    await Clipboard.setData(ClipboardData(text: text));
    if (onToast != null) {
      onToast!(toastMessage ?? 'Copied to clipboard!', 'success');
    }
    onCopied?.call();
  }

  @override
  Widget build(BuildContext context) {
    final canCopy = text.isNotEmpty;

    return GestureDetector(
      onTap: canCopy ? _handleCopy : null,
      child: MouseRegion(
        cursor: canCopy ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xxxs,
          ),
          decoration: BoxDecoration(
            color: AppColors.neutral3,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PhosphorIcon(
                PhosphorIconsDuotone.copy,
                size: 13,
                color: AppColors.neutral8,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.neutral9,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
