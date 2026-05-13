import 'package:flutter/material.dart';
import '../models/theme_config.dart';

/// FitMe Default Theme - Generated from current app styling
/// This is the base reference theme that represents the current FitMe look.
/// Future Gemini-generated themes will use this schema format.
class FitMeDefaultTheme {
  static final ThemeConfig config = ThemeConfig(
    id: 'fitme-default-amoled',
    name: 'FitMe Default',
    description: 'Original FitMe AMOLED dark theme with orange accents',
    version: '1.0.0',
    colors: ThemeColors(
      // ── Background Surfaces ──────────────────────────
      backgroundPrimary: const Color(0xFF0D0D0D), // Pure black AMOLED
      backgroundSecondary: const Color(0xFF1A1A1A), // Slightly lighter

      // ── Surface Containers ──────────────────────────
      surfacePrimary: const Color(0xFF1A1A1A),
      surfaceSecondary: const Color(0xFF242424),
      surfaceElevated: const Color(0xFF2E2E2E),
      surfaceBorder: Colors.white.withOpacity(0.06),

      // ── Text Colors ──────────────────────────────────
      textPrimary: Colors.white,
      textSecondary: const Color(0xFF888888),
      textAccent: const Color(0xFFFF9500), // Orange for call-to-action text
      textDisabled: const Color(0xFF555555),

      // ── Interactive Elements ─────────────────────────
      accent: const Color(0xFFFF9500), // Primary orange
      accentLight: const Color(0xFFFF9500).withOpacity(0.15),
      accentDark: const Color(0xFFD97600),

      // ── Semantic Colors ─────────────────────────────
      success: const Color(0xFF00E5A0), // Green
      warning: const Color(0xFFFF9500), // Orange (same as accent)
      error: const Color(0xFFFF453A), // Red
      info: const Color(0xFF00C7FF), // Cyan

      // ── Macro Colors (Nutrition) ─────────────────────
      proteinColor: const Color(0xFF4D9FFF), // Blue
      carbsColor: const Color(0xFFFF9500), // Orange
      fatsColor: const Color(0xFFAF52DE), // Purple
      waterColor: const Color(0xFF00C7FF), // Cyan
      caloriesColor: const Color(0xFFFF9500), // Orange (same as accent)

      // ── State Colors ─────────────────────────────────
      disabled: const Color(0xFF444444),
      overlay: Colors.black.withOpacity(0.54),
    ),
    typography: ThemeTypography(
      fontFamily: 'Inter',
      displayLargeSize: 57,
      displayMediumSize: 45,
      headlineLargeSize: 32,
      headlineMediumSize: 28,
      titleLargeSize: 22,
      titleMediumSize: 16,
      titleSmallSize: 14,
      bodyLargeSize: 16,
      bodyMediumSize: 14,
      bodySmallSize: 12,
      labelLargeSize: 14,
      labelMediumSize: 12,
    ),
    spacing: const ThemeSpacing(
      xs: 4,
      sm: 8,
      md: 16,
      lg: 24,
      xl: 32,
      xxl: 48,
    ),
    radius: const ThemeRadius(
      xs: 4,
      sm: 8,
      md: 12,
      lg: 16,
      xl: 24,
      full: 999,
    ),
    elevation: const ThemeElevation(
      none: [],
      sm: [
        BoxShadow(
          color: Color(0x00000000),
          blurRadius: 0,
          spreadRadius: 0,
        ),
      ],
      md: [
        BoxShadow(
          color: Color(0x1F000000),
          blurRadius: 4,
          spreadRadius: 0,
        ),
      ],
      lg: [
        BoxShadow(
          color: Color(0x3D000000),
          blurRadius: 12,
          spreadRadius: 2,
        ),
      ],
    ),
    gradients: const ThemeGradients(
      accentGradient: [
        Color(0xFFFF9500),
        Color(0xFFFF7200),
      ],
      successGradient: [
        Color(0xFF00E5A0),
        Color(0xFF00B87A),
      ],
      errorGradient: [
        Color(0xFFFF453A),
        Color(0xFFCC3629),
      ],
    ),
    charts: const ThemeCharts(
      gridLineColor: Color(0xFFFFFFFF),
      tooltipBackground: Color(0xFF242424),
      tooltipText: Color(0xFFFFFFFF),
      gridLineWidth: 0.5,
    ),
    animations: const ThemeAnimations(
      fast: Duration(milliseconds: 150),
      normal: Duration(milliseconds: 300),
      slow: Duration(milliseconds: 500),
      standardCurve: Curves.easeInOut,
    ),
  );

  /// Export as JSON for storage/transmission to Gemini
  static Map<String, dynamic> toJson() => config.toJson();

  /// Get Flutter ThemeData from this configuration
  static ThemeData toThemeData(ThemeConfig theme) {
    final colors = theme.colors;
    final typo = theme.typography;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colors.backgroundPrimary,
      fontFamily: typo.fontFamily,
      colorScheme: ColorScheme.dark(
        primary: colors.accent,
        secondary: colors.accent,
        surface: colors.surfacePrimary,
        error: colors.error,
        onPrimary: colors.backgroundPrimary,
        onSecondary: colors.backgroundPrimary,
        onSurface: colors.textPrimary,
        onError: Colors.white,
        outline: colors.surfaceBorder,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: typo.titleLargeSize,
          fontFamily: typo.fontFamily,
        ),
        iconTheme: IconThemeData(color: colors.textPrimary),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: typo.displayLargeSize,
          fontFamily: typo.fontFamily,
        ),
        displayMedium: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.w900,
          fontSize: typo.displayMediumSize,
          fontFamily: typo.fontFamily,
        ),
        headlineLarge: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: typo.headlineLargeSize,
          fontFamily: typo.fontFamily,
        ),
        headlineMedium: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: typo.headlineMediumSize,
          fontFamily: typo.fontFamily,
        ),
        titleLarge: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: typo.titleLargeSize,
          fontFamily: typo.fontFamily,
        ),
        titleMedium: TextStyle(
          color: colors.textPrimary,
          fontSize: typo.titleMediumSize,
          fontFamily: typo.fontFamily,
        ),
        titleSmall: TextStyle(
          color: colors.textPrimary,
          fontSize: typo.titleSmallSize,
          fontFamily: typo.fontFamily,
        ),
        bodyLarge: TextStyle(
          color: colors.textPrimary,
          fontSize: typo.bodyLargeSize,
          fontFamily: typo.fontFamily,
        ),
        bodyMedium: TextStyle(
          color: colors.textSecondary,
          fontSize: typo.bodyMediumSize,
          fontFamily: typo.fontFamily,
        ),
        bodySmall: TextStyle(
          color: colors.textSecondary,
          fontSize: typo.bodySmallSize,
          fontFamily: typo.fontFamily,
        ),
        labelLarge: TextStyle(
          color: colors.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: typo.labelLargeSize,
          fontFamily: typo.fontFamily,
        ),
        labelMedium: TextStyle(
          color: colors.textSecondary,
          fontSize: typo.labelMediumSize,
          fontFamily: typo.fontFamily,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: colors.backgroundPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.lg),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: typo.fontFamily,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.textPrimary,
          side: BorderSide(color: colors.surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(theme.radius.lg),
          ),
          textStyle: TextStyle(
            fontWeight: FontWeight.bold,
            fontFamily: typo.fontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfacePrimary,
        labelStyle: TextStyle(
          color: colors.textSecondary,
          fontFamily: typo.fontFamily,
        ),
        hintStyle: TextStyle(
          color: colors.textSecondary,
          fontFamily: typo.fontFamily,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
          borderSide: BorderSide(color: colors.accent, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accent
              : colors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.accentLight
              : colors.surfacePrimary,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: colors.surfaceBorder,
        thickness: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.surfacePrimary,
        contentTextStyle: TextStyle(
          color: colors.textPrimary,
          fontFamily: typo.fontFamily,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(theme.radius.md),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
