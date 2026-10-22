import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class ToastData {
  final String id;
  final String text;
  final String type; // "success", "error", "info"

  const ToastData({
    required this.id,
    required this.text,
    this.type = 'info',
  });
}

class ToastOverlay extends StatelessWidget {
  final List<ToastData> toasts;
  final Function(String id) onDismiss;

  const ToastOverlay({
    super.key,
    required this.toasts,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (toasts.isEmpty) return const SizedBox.shrink();

    return Positioned(
      bottom: AppSpacing.xl,
      right: AppSpacing.xl,
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: 380,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: toasts.map((t) {
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: _ToastCard(
                  key: ValueKey(t.id),
                  data: t,
                  onDismiss: () => onDismiss(t.id),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatefulWidget {
  final ToastData data;
  final VoidCallback onDismiss;

  const _ToastCard({
    super.key,
    required this.data,
    required this.onDismiss,
  });

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _progressController.forward();
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    IconData iconData;

    switch (widget.data.type) {
      case 'success':
        accentColor = AppColors.successBase;
        iconData = PhosphorIconsFill.checkCircle;
        break;
      case 'error':
        accentColor = AppColors.dangerBase;
        iconData = PhosphorIconsFill.xCircle;
        break;
      default:
        accentColor = AppColors.primary450;
        iconData = PhosphorIconsFill.info;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.neutral3, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(iconData, color: accentColor, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.data.text,
                    style: AppTypography.body.copyWith(
                      color: AppColors.neutral11,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    PhosphorIconsBold.x,
                    color: AppColors.neutral7,
                    size: 16,
                  ),
                  onPressed: widget.onDismiss,
                  splashRadius: 16,
                  constraints: const BoxConstraints(),
                  padding: const EdgeInsets.all(AppSpacing.xxs),
                ),
              ],
            ),
          ),
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return LinearProgressIndicator(
                value: 1.0 - _progressController.value,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                minHeight: 2,
              );
            },
          ),
        ],
      ),
    );
  }
}
