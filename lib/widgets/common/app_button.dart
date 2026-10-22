import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

enum ButtonVariant { primary, secondary, danger, text }

class AppButton extends StatefulWidget {
  final VoidCallback? onClick;
  final Widget? icon;
  final Widget? hoverIcon;
  final String? text;
  final Widget? child;
  final ButtonVariant variant;
  final bool disabled;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  const AppButton({
    super.key,
    this.onClick,
    this.icon,
    this.hoverIcon,
    this.text,
    this.child,
    this.variant = ButtonVariant.primary,
    this.disabled = false,
    this.padding,
    this.width,
    this.height,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.onClick == null;

    Color bg;
    Color border;
    Color fg;

    switch (widget.variant) {
      case ButtonVariant.primary:
        bg = isDisabled
            ? AppColors.neutral5
            : _isPressed
            ? AppColors.primary650
            : _isHovered
            ? AppColors.primaryHover
            : AppColors.primaryBase;
        border = Colors.transparent;
        fg = isDisabled ? AppColors.neutral7 : AppColors.neutral12;
        break;

      case ButtonVariant.secondary:
        bg = isDisabled
            ? Colors.transparent
            : _isPressed
            ? AppColors.neutral4
            : _isHovered
            ? AppColors.neutral3
            : AppColors.neutral2;
        border = isDisabled
            ? AppColors.neutral4
            : _isHovered
            ? AppColors.neutral4
            : AppColors.neutral3;
        fg = isDisabled ? AppColors.neutral7 : AppColors.neutral10;
        break;

      case ButtonVariant.danger:
        bg = isDisabled
            ? Colors.transparent
            : _isPressed
            ? AppColors.dangerHover
            : _isHovered
            ? AppColors.dangerHover
            : AppColors.dangerBase;
        border = Colors.transparent;
        fg = isDisabled ? AppColors.neutral7 : AppColors.neutral12;
        break;

      case ButtonVariant.text:
        bg = _isHovered ? AppColors.neutral3 : Colors.transparent;
        border = Colors.transparent;
        fg = isDisabled ? AppColors.neutral7 : AppColors.primary450;
        break;
    }

    final content =
        widget.child ??
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              IconTheme(
                data: IconThemeData(color: fg, size: 18),
                child: widget.hoverIcon != null
                    ? AnimatedCrossFade(
                        duration: const Duration(milliseconds: 150),
                        firstCurve: Curves.easeInOut,
                        secondCurve: Curves.easeInOut,
                        sizeCurve: Curves.easeInOut,
                        crossFadeState: (_isHovered && !isDisabled)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        firstChild: widget.icon!,
                        secondChild: widget.hoverIcon!,
                      )
                    : widget.icon!,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (widget.text != null)
              Flexible(
                child: Text(
                  widget.text!,
                  style: AppTypography.caption.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        );

    return MouseRegion(
      cursor: isDisabled
          ? SystemMouseCursors.forbidden
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: isDisabled ? null : widget.onClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          height: widget.height ?? 44,
          padding:
              widget.padding ??
              const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
          decoration: ShapeDecoration(
            color: bg,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: border, width: 2),
            ),
            shadows:
                _isHovered &&
                    !isDisabled &&
                    widget.variant == ButtonVariant.primary
                ? [
                    BoxShadow(
                      color: AppColors.primaryBase.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: DefaultTextStyle(
            style: AppTypography.body.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
            child: IconTheme(
              data: IconThemeData(color: fg, size: 18),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
