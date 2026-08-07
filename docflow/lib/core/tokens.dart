import 'package:flutter/material.dart';

/// Design tokens sampled directly from the ProScan UI kit
/// (Figma: ProScan - Document + PDF Scanner App UI Kit).
///
/// DocFlow reuses ProScan's visual language verbatim so the auth flow and
/// splash feel identical; only the product surface differs.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFF4B68FF);
  static const Color primaryLight = Color(0xFF5E78FF);
  static const Color primaryDeep = Color(0xFF3B4FD4);
  static const Color primarySoft = Color(0xFF97AEFE);
  static const Color primaryTint = Color(0xFFF2F2FE);

  // Neutrals
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFAFAFA);
  static const Color divider = Color(0xFFEEEEEE);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF9E9E9E);
  static const Color textTertiary = Color(0xFFBDBDBD);

  /// Timestamps under file names — a step darker than [textSecondary].
  static const Color textMeta = Color(0xFF757575);

  /// Tool-grid labels under the circles.
  static const Color textLabel = Color(0xFF424242);

  // Dark surfaces (scanner + dark theme)
  static const Color darkBackground = Color(0xFF181A20);
  static const Color darkSurface = Color(0xFF1F222A);
  static const Color darkDivider = Color(0xFF35383F);

  /// Ghost circles and chips that sit on top of the dark camera chrome.
  static const Color darkElevated = Color(0xFF262A35);

  // Accents used by the tool grid and file-type badges
  static const Color amber = Color(0xFFFCA82F);
  static const Color coral = Color(0xFFFA5B5D);
  static const Color violet = Color(0xFF7B5EFF);
  static const Color green = Color(0xFF39D9A1);
  static const Color brown = Color(0xFFA9715E);

  // Matching pastel tints (circle + badge backgrounds)
  static const Color amberTint = Color(0xFFFFF7EB);
  static const Color coralTint = Color(0xFFFFF1F1);
  static const Color violetTint = Color(0xFFF3F3FF);
  static const Color greenTint = Color(0xFFDAF4EE);
  static const Color brownTint = Color(0xFFF8F4F2);
}

/// Corner radii from the kit: pill CTAs, 20pt cards, 16pt inner tiles.
class AppRadius {
  AppRadius._();

  static const double card = 20;
  static const double tile = 16;
  static const double field = 12;
  static const double pill = 999;

  /// Modal cards sit a little rounder than content cards.
  static const double sheet = 32;
}

class AppSpacing {
  AppSpacing._();

  /// Horizontal page gutter used across every ProScan screen (24pt at 430w).
  static const double gutter = 24;
  static const double section = 32;
}
