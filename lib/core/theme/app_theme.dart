import 'package:flutter/material.dart';

class AppTheme {
  // ── Core colors ──────────────────────────
  static const Color background = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color accent = Color(0xFFFF9500);       // Orange
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFF888888);

  // ── Macro colors ─────────────────────────
  static const Color proteinColor = Color(0xFF4D9FFF);  // Blue
  static const Color carbsColor = Color(0xFFFF9500);    // Orange
  static const Color fatsColor = Color(0xFFAF52DE);     // Purple
  static const Color waterColor = Color(0xFF00C7FF);    // Cyan
  static const Color caloriesColor = accent;

  // ── Semantic colors ──────────────────────
  static const Color success = Color(0xFF00E5A0);
  static const Color warning = Color(0xFFFF9500);
  static const Color error = Color(0xFFFF453A);

  // ── Theme data ───────────────────────────
  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      fontFamily: 'Inter',
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accent,
        surface: surface,
        background: background,
        error: error,
        onPrimary: background,
        onSecondary: background,
        onSurface: textPrimary,
        onBackground: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        titleTextStyle: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Inter'),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
        displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w900, fontFamily: 'Inter'),
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        titleMedium: TextStyle(color: textPrimary, fontFamily: 'Inter'),
        bodyLarge: TextStyle(color: textPrimary, fontFamily: 'Inter'),
        bodyMedium: TextStyle(color: textSecondary, fontFamily: 'Inter'),
        labelLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: background,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: Colors.white.withOpacity(0.15)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        labelStyle: const TextStyle(color: textSecondary, fontFamily: 'Inter'),
        hintStyle: const TextStyle(color: textSecondary, fontFamily: 'Inter'),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? accent : textSecondary),
        trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? accent.withOpacity(0.4) : surface),
      ),
      dividerTheme: DividerThemeData(color: Colors.white.withOpacity(0.06), thickness: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: const TextStyle(color: textPrimary, fontFamily: 'Inter'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}