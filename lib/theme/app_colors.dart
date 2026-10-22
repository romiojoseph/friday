import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette (as specified)
  static const Color primary50 = Color(0xFFEFF6FF);
  static const Color primary60 = Color(0xFFDBEAFE);
  static const Color primary150 = Color(0xFFBFDBFE);
  static const Color primary300 = Color(0xFF60A5FA);
  static const Color primary450 = Color(0xFF3B82F6);
  static const Color primary500 = Color(0xFF2563EB);
  static const Color primary550 = Color(0xFF1D4ED8);
  static const Color primary650 = Color(0xFF1E40AF);
  static const Color primary800 = Color(0xFF172554);

  // Neutrals (Dark surface hierarchy)
  static const Color neutral0 = Color(0xFF000000);
  static const Color neutral1 = Color(0xFF050506);
  static const Color neutral2 = Color(0xFF0C0D10);
  static const Color neutral3 = Color(0xFF16171D);
  static const Color neutral4 = Color(0xFF202128);
  static const Color neutral5 = Color(0xFF2A2C35);
  static const Color neutral6 = Color(0xFF4B5563);
  static const Color neutral7 = Color(0xFF6B7280);
  static const Color neutral8 = Color(0xFF9CA3AF);
  static const Color neutral9 = Color(0xFFCBD5E1);
  static const Color neutral10 = Color(0xFFF1F5F9);
  static const Color neutral11 = Color(0xFFF8FAFC);
  static const Color neutral12 = Color(0xFFFFFFFF);

  // Semantic & Primary variations
  static const Color primaryBase = Color(0xFF2563EB);
  static const Color primaryHover = Color(0xFF1D4ED8);
  static const Color primaryLight = Color(0x142563EB);
  static const Color primaryAccent = Color(0x402563EB);

  // Danger palette
  static const Color dangerBase = Color(0xFFEF4444);
  static const Color dangerHover = Color(0xFFDC2626);
  static const Color dangerLight = Color(0x1AEF4444);

  // Success palette
  static const Color successBase = Color(0xFF10B981);
  static const Color successHover = Color(0xFF059669);
  static const Color successLight = Color(0x1A10B981);

  // Status badges
  static const Color statusCleanText = Color(0xFF00FFCC);
  static const Color statusCleanBg = Color(0x1400FFCC);
  static const Color statusCleanBorder = Color(0x1F00FFCC);

  static const Color statusModifiedText = Color(0xFFFF4D4D);
  static const Color statusModifiedBg = Color(0x14FF4D4D);
  static const Color statusModifiedBorder = Color(0x1FFF4D4D);

  static const Color statusNewText = Color(0xFFFFB366);
  static const Color statusNewBg = Color(0x14FFB366);
  static const Color statusNewBorder = Color(0x1FFFB366);

  // Diff statuses
  static const Color diffAdded = Color(0xFF4ADE80);
  static const Color diffModified = Color(0xFFA855F7);
  static const Color diffDeleted = Color(0xFFEF4444);
  static const Color diffSkipped = Color(0xFFFFB366);
  static const Color diffUnchanged = Color(0xFF9CA3AF);
}
