import 'package:flutter/material.dart';
import 'package:fitme/core/theme/models/theme_config.dart';

/// FitMe Ocean Theme - A blue/teal variant
class FitMeOceanTheme {
  static final ThemeConfig config = ThemeConfig(
    id: 'fitme-ocean',
    name: 'FitMe Ocean',
    description: 'A deep sea theme with cool teal and blue accents',
    version: '1.0.0',
    colors: ThemeColors(
      // ── Background Surfaces ──────────────────────────
      backgroundPrimary: const Color(0xFF041014), // Deep teal/navy black
      backgroundSecondary: const Color(0xFF07181F), // Slightly lighter
      // ── Surface Containers ──────────────────────────
      surfacePrimary: const Color(0xFF0A212A),
      surfaceSecondary: const Color(0xFF0E2C38),
      surfaceElevated: const Color(0xFF133948),
      surfaceBorder: Colors.white.withOpacity(0.08),

      // ── Text Colors ──────────────────────────────────
      textPrimary: Colors.white,
      textSecondary: const Color(0xFF8BA6B0),
      textAccent: const Color(0xFF00E5FF), // Cyan/Teal accent
      textDisabled: const Color(0xFF4C6A75),

      // ── Interactive Elements ─────────────────────────
      accent: const Color(0xFF00E5FF), // Primary teal
      accentLight: const Color(0xFF00E5FF).withOpacity(0.15),
      accentDark: const Color(0xFF00B0CC),

      // ── Semantic Colors ─────────────────────────────
      success: const Color(0xFF00E5A0), // Green
      warning: const Color(0xFFFFB020), // Yellow
      error: const Color(0xFFFF453A), // Red
      info: const Color(0xFF00C7FF), // Cyan
      // ── Macro Colors (Nutrition) ─────────────────────
      proteinColor: const Color(0xFF00C7FF), // Cyan
      carbsColor: const Color(0xFF00E5A0), // Green
      fatsColor: const Color(0xFFA259FF), // Purple
      waterColor: const Color(0xFF0088FF), // Blue
      caloriesColor: const Color(0xFF00E5FF), // Teal (same as accent)
      // ── State Colors ─────────────────────────────────
      disabled: const Color(0xFF334A54),
      overlay: Colors.black.withOpacity(0.6),
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
    spacing: const ThemeSpacing(xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48),
    radius: const ThemeRadius(xs: 4, sm: 8, md: 12, lg: 16, xl: 24, full: 999),
    elevation: const ThemeElevation(
      none: [],
      sm: [BoxShadow(color: Color(0x00000000), blurRadius: 0, spreadRadius: 0)],
      md: [BoxShadow(color: Color(0x1F00E5FF), blurRadius: 4, spreadRadius: 0)],
      lg: [
        BoxShadow(color: Color(0x3D00E5FF), blurRadius: 12, spreadRadius: 2),
      ],
    ),
    gradients: const ThemeGradients(
      accentGradient: [Color(0xFF00E5FF), Color(0xFF00B0CC)],
      successGradient: [Color(0xFF00E5A0), Color(0xFF00B87A)],
      errorGradient: [Color(0xFFFF453A), Color(0xFFCC3629)],
    ),
    charts: const ThemeCharts(
      gridLineColor: Color(0xFFFFFFFF),
      tooltipBackground: Color(0xFF0A212A),
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
}
