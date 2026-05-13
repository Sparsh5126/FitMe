import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  // ── Default colors (used as fallback/legacy) ──────────
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color accent = Color(0xFFFF9500); // Orange
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF888888);

  // ── Macro colors ─────────────────────────
  static const Color proteinColor = Color(0xFF4D9FFF); // Blue
  static const Color carbsColor = Color(0xFFFF9500); // Orange
  static const Color fatsColor = Color(0xFFAF52DE); // Purple
  static const Color waterColor = Color(0xFF00C7FF); // Cyan
  static const Color caloriesColor = accent;

  // ── Semantic colors ──────────────────────
  static const Color success = Color(0xFF00E5A0);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF453A);

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
