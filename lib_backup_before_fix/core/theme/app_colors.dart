import 'package:flutter/material.dart';

/// Central brand palette. A deep indigo/violet gradient brand with a warm
/// coral accent for CTAs — chosen to feel premium and distinct from the
/// default Material blue that most Flutter PDF apps ship with.
class AppColors {
  AppColors._();

  static const Color brandPrimary = Color(0xFF5B4FE9);
  static const Color brandPrimaryDark = Color(0xFF7C6FFF);
  static const Color brandSecondary = Color(0xFF2FD3C6);
  static const Color accentCoral = Color(0xFFFF6B5B);

  static const Color lightBg = Color(0xFFF7F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFF0EFFA);
  static const Color lightBorder = Color(0xFFE7E6F2);
  static const Color lightTextPrimary = Color(0xFF17162B);
  static const Color lightTextSecondary = Color(0xFF6E6C87);

  static const Color darkBg = Color(0xFF0E0D18);
  static const Color darkSurface = Color(0xFF17162A);
  static const Color darkSurfaceAlt = Color(0xFF1F1E36);
  static const Color darkBorder = Color(0xFF2A2942);
  static const Color darkTextPrimary = Color(0xFFF3F2FB);
  static const Color darkTextSecondary = Color(0xFFA6A4C2);

  static const Color success = Color(0xFF2FBF71);
  static const Color warning = Color(0xFFF5A623);
  static const Color danger = Color(0xFFE5484D);

  static const List<Color> heroGradient = [brandPrimary, Color(0xFF8B5CF6)];

  // Per-tool accent colors for visual distinction on the Tools grid.
  static const Color toolMerge = Color(0xFF5B4FE9);
  static const Color toolSplit = Color(0xFF2FD3C6);
  static const Color toolCompress = Color(0xFFFF9F43);
  static const Color toolImageToPdf = Color(0xFF34C759);
  static const Color toolPdfToImage = Color(0xFF00B4D8);
  static const Color toolReorder = Color(0xFFA855F7);
  static const Color toolRotate = Color(0xFFEF476F);
  static const Color toolFill = Color(0xFF3A86FF);
  static const Color toolSign = Color(0xFFFB5607);
  static const Color toolSecurity = Color(0xFF6C757D);
  static const Color toolQrScan = Color(0xFF06D6A0);
  static const Color toolQrGen = Color(0xFFFFB703);
}
