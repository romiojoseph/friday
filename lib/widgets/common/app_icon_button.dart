import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

enum IconButtonVariant { standard, ghost }

class AppIconButton extends StatefulWidget {
  final Widget icon;
  final Widget? hoverIcon;
  final VoidCallback? onClick;
  final String? tooltip;
  final bool disabled;
  final double size;
  final IconButtonVariant variant;

  const AppIconButton({
    super.key,
    required this.icon,
    this.hoverIcon,
    this.onClick,
    this.tooltip,
    this.disabled = false,
    this.size = 44,
    this.variant = IconButtonVariant.standard,
  });

  const AppIconButton.ghost({
    super.key,
    required this.icon,
    this.hoverIcon,
    this.onClick,
    this.tooltip,
    this.disabled = false,
    this.size = 28,
  }) : variant = IconButtonVariant.ghost;

  @override
  State<AppIconButton> createState() => _AppIconButtonState();
}

class _AppIconButtonState extends State<AppIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.disabled || widget.onClick == null;
    final isGhost = widget.variant == IconButtonVariant.ghost;

    final Color bgColor = isGhost
        ? Colors.transparent
        : (_isHovered && !isDisabled ? AppColors.neutral3 : Colors.transparent);

    final Border? border = isGhost
        ? null
        : Border.all(
            color: _isHovered && !isDisabled ? AppColors.neutral4 : AppColors.neutral3,
            width: 2,
          );

    final Color iconColor = isDisabled
        ? AppColors.neutral7
        : isGhost
            ? (_isHovered ? AppColors.neutral11 : AppColors.neutral7)
            : (_isHovered ? AppColors.neutral12 : AppColors.neutral8);

    final btn = MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isDisabled ? null : widget.onClick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: border,
          ),
          alignment: Alignment.center,
          child: IconTheme(
            data: IconThemeData(
              color: iconColor,
              size: isGhost ? 20 : 20,
            ),
            child: widget.hoverIcon != null
                ? AnimatedCrossFade(
                    duration: const Duration(milliseconds: 150),
                    firstCurve: Curves.easeInOut,
                    secondCurve: Curves.easeInOut,
                    sizeCurve: Curves.easeInOut,
                    crossFadeState: (_isHovered && !isDisabled)
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: widget.icon,
                    secondChild: widget.hoverIcon!,
                  )
                : widget.icon,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(
        message: widget.tooltip!,
        child: btn,
      );
    }
    return btn;
  }
}
