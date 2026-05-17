# FitMe Theme Generator Prompt

Copy and paste the text below to any AI model (like ChatGPT, Claude, or Gemini) to generate new, fully compatible themes for the FitMe app!

---
**COPY FROM HERE DOWN:**
---

Act as an expert mobile UI/UX designer and Flutter developer. I want you to create a new, beautiful color theme for my fitness tracking app, "FitMe".

### About FitMe
FitMe is a gamified, modern fitness app with an AMOLED-first aesthetic. It has features for nutrition logging (macros: Protein, Carbs, Fats, Water), gamification (Streak, FitPoints, Leveling), and progress tracking.

### Your Task
I will give you a theme concept (e.g., "Cyberpunk", "Forest", "Sunset"). I need you to generate a valid Dart file using the exact template provided below. 

### Rules for the Theme Colors
1. **Backgrounds**: `backgroundPrimary` should be the darkest color (often near-black for dark mode themes). `backgroundSecondary` should be slightly lighter.
2. **Surfaces**: `surfacePrimary`, `surfaceSecondary`, and `surfaceElevated` should progressively get lighter to show elevation/depth.
3. **Accent**: `accent` is the primary brand/action color. Provide a lighter version (`accentLight` - usually 15% opacity) and a darker version (`accentDark`).
4. **Macros**: Ensure `proteinColor`, `carbsColor`, `fatsColor`, and `waterColor` are distinct but harmonious with your overall theme. They represent different nutrients on progress rings.
5. **Contrast**: Ensure `textPrimary` (usually white or very light) and `textSecondary` have excellent readability against the backgrounds and surfaces.

### The Template
Generate ONLY the Dart code block below, filling in the `TODO` sections with your expertly chosen hex colors. Name the class `FitMe[YourThemeName]Theme` and ensure the `id` is lowercase with hyphens.

```dart
import 'package:flutter/material.dart';
import '../models/theme_config.dart';

/// FitMe [Your Theme Name] Theme
class FitMe[YourThemeName]Theme {
  static final ThemeConfig config = ThemeConfig(
    id: 'fitme-[your-theme-name]',
    name: 'FitMe [Your Theme Name]',
    description: '[A short, engaging description of this theme]',
    version: '1.0.0',
    colors: ThemeColors(
      // ── Background Surfaces ──────────────────────────
      backgroundPrimary: const Color(0xFF[HEX]), // Darkest background
      backgroundSecondary: const Color(0xFF[HEX]), // Slightly lighter

      // ── Surface Containers ──────────────────────────
      surfacePrimary: const Color(0xFF[HEX]), // e.g. Card backgrounds
      surfaceSecondary: const Color(0xFF[HEX]), // e.g. Inner cards
      surfaceElevated: const Color(0xFF[HEX]), // e.g. Floating menus
      surfaceBorder: Colors.white.withOpacity(0.08),

      // ── Text Colors ──────────────────────────────────
      textPrimary: Colors.white, // Or a very light tint of your theme
      textSecondary: const Color(0xFF[HEX]), // Usually a readable grey/tint
      textAccent: const Color(0xFF[HEX]), // Same as accent, or readable variant
      textDisabled: const Color(0xFF[HEX]), // Muted text

      // ── Interactive Elements ─────────────────────────
      accent: const Color(0xFF[HEX]), // Main action color
      accentLight: const Color(0xFF[HEX]).withOpacity(0.15),
      accentDark: const Color(0xFF[HEX]), // Darker shade of accent

      // ── Semantic Colors ─────────────────────────────
      success: const Color(0xFF00E5A0), // Green or your theme's success
      warning: const Color(0xFFFFB020), // Yellow or your theme's warning
      error: const Color(0xFFFF453A), // Red or your theme's error
      info: const Color(0xFF00C7FF), // Cyan or your theme's info

      // ── Macro Colors (Nutrition) ─────────────────────
      proteinColor: const Color(0xFF[HEX]), // e.g. Blue/Cyan
      carbsColor: const Color(0xFF[HEX]), // e.g. Green/Orange
      fatsColor: const Color(0xFF[HEX]), // e.g. Purple/Pink
      waterColor: const Color(0xFF[HEX]), // e.g. Deep Blue
      caloriesColor: const Color(0xFF[HEX]), // Usually matches the Accent color

      // ── State Colors ─────────────────────────────────
      disabled: const Color(0xFF[HEX]), // For disabled buttons/surfaces
      overlay: Colors.black.withOpacity(0.6),
    ),
    
    // Using default typography and sizing for consistency
    typography: const ThemeTypography(fontFamily: 'Inter'),
    spacing: const ThemeSpacing(),
    radius: const ThemeRadius(),
    elevation: const ThemeElevation(),
    
    gradients: const ThemeGradients(
      accentGradient: [
        Color(0xFF[HEX]), // Accent color
        Color(0xFF[HEX]), // Slightly darker or complementary accent
      ],
      successGradient: [Color(0xFF00E5A0), Color(0xFF00B87A)],
      errorGradient: [Color(0xFFFF453A), Color(0xFFCC3629)],
    ),
    charts: const ThemeCharts(
      gridLineColor: Color(0xFFFFFFFF),
      tooltipBackground: Color(0xFF[HEX]), // Usually same as surfacePrimary
      tooltipText: Color(0xFFFFFFFF),
      gridLineWidth: 0.5,
    ),
    animations: const ThemeAnimations(),
  );
}
```

### Instructions for the user (me):
Once you generate this file, I will save it to `lib/core/theme/themes/fitme_[your_theme_name]_theme.dart` and register it in my `ThemeManager`!

Please create a **[INSERT THEME CONCEPT HERE, e.g. "Cyberpunk"]** theme now!
