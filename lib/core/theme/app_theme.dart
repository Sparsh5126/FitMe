import 'package:flutter/material.dart';
import 'package:fitme/core/theme/models/theme_config.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/core/theme/themes/fitme_default_theme.dart';

/// Legacy compatibility class - provides static access to current theme colors
///
/// NEW APPROACH:
/// For new screens, use ThemeManager or the Riverpod provider directly
/// For migrating existing screens, gradually replace AppTheme.color with theme tokens
///
/// Example migration:
///   OLD: Colors.white, AppTheme.accent
///   NEW: theme.colors.textPrimary, theme.colors.accent
class AppTheme {
  // ── Dynamic Theme Colors ──────────
  static Color get background =>
      ThemeManager.instance.activeTheme.colors.backgroundPrimary;
  static Color get surface =>
      ThemeManager.instance.activeTheme.colors.surfacePrimary;
  static Color get surfaceElevated =>
      ThemeManager.instance.activeTheme.colors.surfaceElevated;
  static Color get accent => ThemeManager.instance.activeTheme.colors.accent;
  static Color get textPrimary =>
      ThemeManager.instance.activeTheme.colors.textPrimary;
  static Color get textSecondary =>
      ThemeManager.instance.activeTheme.colors.textSecondary;

  // ── Macro colors ─────────────────────────
  static Color get proteinColor =>
      ThemeManager.instance.activeTheme.colors.proteinColor;
  static Color get carbsColor =>
      ThemeManager.instance.activeTheme.colors.carbsColor;
  static Color get fatsColor =>
      ThemeManager.instance.activeTheme.colors.fatsColor;
  static Color get waterColor =>
      ThemeManager.instance.activeTheme.colors.waterColor;
  static Color get caloriesColor =>
      ThemeManager.instance.activeTheme.colors.caloriesColor;

  // ── Semantic colors ──────────────────────
  static Color get success => ThemeManager.instance.activeTheme.colors.success;
  static Color get warning => ThemeManager.instance.activeTheme.colors.warning;
  static Color get error => ThemeManager.instance.activeTheme.colors.error;

  // ── Theme data ───────────────────────────
  /// Get dark theme data (now uses ThemeConfig)
  static ThemeData get dark {
    return FitMeDefaultTheme.toThemeData(FitMeDefaultTheme.config);
  }

  // ── New theme-aware accessors ──────────────
  /// Get current theme configuration
  static ThemeConfig get currentTheme => ThemeManager.instance.activeTheme;

  /// Get current theme colors
  static ThemeColors get currentColors => currentTheme.colors;

  /// Get current theme typography
  static ThemeTypography get currentTypography => currentTheme.typography;

  /// Get current theme spacing
  static ThemeSpacing get currentSpacing => currentTheme.spacing;

  /// Get current theme radius
  static ThemeRadius get currentRadius => currentTheme.radius;
}
