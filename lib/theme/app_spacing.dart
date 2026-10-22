import 'package:flutter/material.dart';

/// 4-point spacing system for consistent layout and padding
class AppSpacing {
  AppSpacing._();

  static const double xxxs = 2.0;
  static const double xxs = 4.0;
  static const double xs = 8.0;
  static const double sm = 12.0;
  static const double md = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double xxxxl = 48.0;
  static const double huge = 64.0;
  static const double massive = 80.0;
  static const double colossal = 96.0;

  // EdgeInsets all-around padding
  static const EdgeInsets paddingXxxs = EdgeInsets.all(xxxs);
  static const EdgeInsets paddingXxs = EdgeInsets.all(xxs);
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);
  static const EdgeInsets paddingXxl = EdgeInsets.all(xxl);
  static const EdgeInsets paddingXxxl = EdgeInsets.all(xxxl);
  static const EdgeInsets paddingXxxxl = EdgeInsets.all(xxxxl);
  static const EdgeInsets paddingHuge = EdgeInsets.all(huge);
  static const EdgeInsets paddingMassive = EdgeInsets.all(massive);
  static const EdgeInsets paddingColossal = EdgeInsets.all(colossal);

  // Horizontal Padding
  static const EdgeInsets paddingHXs = EdgeInsets.symmetric(horizontal: xs);
  static const EdgeInsets paddingHSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHXl = EdgeInsets.symmetric(horizontal: xl);
  static const EdgeInsets paddingHXxl = EdgeInsets.symmetric(horizontal: xxl);

  // Vertical Padding
  static const EdgeInsets paddingVXs = EdgeInsets.symmetric(vertical: xs);
  static const EdgeInsets paddingVSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVXl = EdgeInsets.symmetric(vertical: xl);
  static const EdgeInsets paddingVXxl = EdgeInsets.symmetric(vertical: xxl);
}
