import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String label;
  final bool disabled;

  const AppCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    required this.label,
    this.disabled = false,
  });

  @override
  State<AppCheckbox> createState() => _AppCheckboxState();
}

class _AppCheckboxState extends State<AppCheckbox> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.onChanged == null;

    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: isDisabled ? null : () => widget.onChanged!(!widget.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 150),
                firstCurve: Curves.easeInOut,
                secondCurve: Curves.easeInOut,
                sizeCurve: Curves.easeInOut,
                crossFadeState: widget.value
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: _isHovered && !isDisabled
                    ? const PhosphorIcon(
                        PhosphorIconsDuotone.circle,
                        color: AppColors.neutral7,
                        size: 24,
                      )
                    : const Icon(
                        PhosphorIconsBold.circle,
                        color: AppColors.neutral6,
                        size: 24,
                      ),
                secondChild: const Icon(
                  PhosphorIconsFill.checkCircle,
                  color: AppColors.primary450,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  widget.label,
                  style: AppTypography.body.copyWith(
                    color: isDisabled
                        ? AppColors.neutral7
                        : _isHovered
                            ? AppColors.neutral11
                            : AppColors.neutral9,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
