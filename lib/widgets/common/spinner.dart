import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';

class Spinner extends StatelessWidget {
  final double size;
  final Color? color;
  final double strokeWidth;

  const Spinner({
    super.key,
    this.size = 18,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.neutral12,
        ),
      ),
    );
  }
}
