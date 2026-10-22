import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? placeholder;
  final bool disabled;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final Widget? prefixIcon;
  final Widget? suffix;

  const AppTextField({
    super.key,
    required this.controller,
    this.placeholder,
    this.disabled = false,
    this.maxLines = 1,
    this.onChanged,
    this.prefixIcon,
    this.suffix,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color borderColor = AppColors.neutral3;
    Color bgColor = AppColors.neutral2;

    if (widget.disabled) {
      bgColor = AppColors.neutral1;
      borderColor = AppColors.neutral3.withValues(alpha: 0.5);
    } else if (_isFocused) {
      borderColor = AppColors.neutral4;
      bgColor = AppColors.neutral0;
    } else if (_isHovered) {
      borderColor = AppColors.neutral4;
      bgColor = AppColors.neutral0;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: ShapeDecoration(
          color: bgColor,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: borderColor, width: 2),
          ),
          shadows: _isFocused
              ? [
                  BoxShadow(
                    color: AppColors.neutral4.withValues(alpha: 0.4),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            if (widget.prefixIcon != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.md),
                child: widget.prefixIcon,
              ),
            ],
            Expanded(
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                enabled: !widget.disabled,
                maxLines: widget.maxLines,
                onChanged: widget.onChanged,
                style: AppTypography.body.copyWith(
                  color: widget.disabled
                      ? AppColors.neutral7
                      : AppColors.neutral11,
                  fontSize: 14,
                ),
                cursorColor: AppColors.primary450,
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: AppTypography.body.copyWith(
                    color: AppColors.neutral7,
                    fontSize: 14,
                  ),
                  isDense: true,
                  contentPadding: const EdgeInsets.all(AppSpacing.md),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (widget.suffix != null) widget.suffix!,
          ],
        ),
      ),
    );
  }
}
