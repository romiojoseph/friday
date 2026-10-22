import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_typography.dart';

class PillSelector extends StatelessWidget {
  final int selectedValue;
  final List<int> values;
  final ValueChanged<int> onSelected;

  const PillSelector({
    super.key,
    required this.selectedValue,
    this.values = const [2, 3, 4, 5, 6, 7, 8, 9, 10],
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: values.map((val) {
          final isSelected = val == selectedValue;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: _PillButton(
              value: val,
              isSelected: isSelected,
              onTap: () => onSelected(val),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PillButton extends StatefulWidget {
  final int value;
  final bool isSelected;
  final VoidCallback onTap;

  const _PillButton({
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color border;
    Color fg;

    if (widget.isSelected) {
      bg = AppColors.primaryBase;
      border = AppColors.primary450;
      fg = AppColors.neutral12;
    } else if (_isHovered) {
      bg = AppColors.neutral3;
      border = AppColors.neutral4;
      fg = AppColors.neutral12;
    } else {
      bg = AppColors.neutral2;
      border = AppColors.neutral3;
      fg = AppColors.neutral8;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: border, width: 2),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primaryBase.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            '${widget.value}',
            style: AppTypography.body.copyWith(
              color: fg,
              fontWeight: widget.isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
