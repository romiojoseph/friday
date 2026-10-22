import 'package:flutter/material.dart';

class AppTypography {
  AppTypography._();

  // Font Sizes
  static const double displayLargeSize = 52;
  static const double displayMediumSize = 46;
  static const double displaySmallSize = 41;
  static const double heading1Size = 36;
  static const double heading2Size = 32;
  static const double heading3Size = 29;
  static const double heading4Size = 26;
  static const double heading5Size = 23;
  static const double heading6Size = 20;
  static const double subtitleSize = 18;
  static const double bodySize = 16;
  static const double captionSize = 14;
  static const double labelSize = 13;
  static const double taglineSize = 11;

  // Base TextStyles (use with const or override via .copyWith())
  static const TextStyle displayLarge = TextStyle(
    fontSize: displayLargeSize,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle displayMedium = TextStyle(
    fontSize: displayMediumSize,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle displaySmall = TextStyle(
    fontSize: displaySmallSize,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading1 = TextStyle(
    fontSize: heading1Size,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading2 = TextStyle(
    fontSize: heading2Size,
    fontWeight: FontWeight.bold,
  );

  static const TextStyle heading3 = TextStyle(
    fontSize: heading3Size,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle heading4 = TextStyle(
    fontSize: heading4Size,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle heading5 = TextStyle(
    fontSize: heading5Size,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle heading6 = TextStyle(
    fontSize: heading6Size,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: subtitleSize,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body = TextStyle(
    fontSize: bodySize,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle caption = TextStyle(
    fontSize: captionSize,
    fontWeight: FontWeight.normal,
  );

  static const TextStyle label = TextStyle(
    fontSize: labelSize,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle tagline = TextStyle(
    fontSize: taglineSize,
    fontWeight: FontWeight.normal,
  );
}
