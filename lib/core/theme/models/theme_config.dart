import 'package:flutter/material.dart';

/// Defines the complete theme schema for FitMe
/// Future Gemini-generated themes MUST follow this exact structure
class ThemeConfig {
  // Metadata
  final String id;
  final String name;
  final String description;
  final String version; // For compatibility versioning

  // Colors - Semantic tokens (NOT literal colors like "blue" or "grey")
  final ThemeColors colors;

  // Typography
  final ThemeTypography typography;

  // Spacing scale (in logical pixels)
  final ThemeSpacing spacing;

  // Border radius scale
  final ThemeRadius radius;

  // Shadows/Elevations
  final ThemeElevation elevation;

  // Gradients for special components
  final ThemeGradients gradients;

  // Chart styling
  final ThemeCharts charts;

  // Animation settings
  final ThemeAnimations animations;

  const ThemeConfig({
    required this.id,
    required this.name,
    required this.description,
    required this.version,
    required this.colors,
    required this.typography,
    required this.spacing,
    required this.radius,
    required this.elevation,
    required this.gradients,
    required this.charts,
    required this.animations,
  });

  /// Convert to JSON for storage/transmission
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'version': version,
    'colors': colors.toJson(),
    'typography': typography.toJson(),
    'spacing': spacing.toJson(),
    'radius': radius.toJson(),
    'elevation': elevation.toJson(),
    'gradients': gradients.toJson(),
    'charts': charts.toJson(),
    'animations': animations.toJson(),
  };

  /// Create from JSON
  static ThemeConfig fromJson(Map<String, dynamic> json) {
    return ThemeConfig(
      id: json['id'] ?? 'unknown',
      name: json['name'] ?? 'Unknown Theme',
      description: json['description'] ?? '',
      version: json['version'] ?? '1.0.0',
      colors: ThemeColors.fromJson(json['colors'] ?? {}),
      typography: ThemeTypography.fromJson(json['typography'] ?? {}),
      spacing: ThemeSpacing.fromJson(json['spacing'] ?? {}),
      radius: ThemeRadius.fromJson(json['radius'] ?? {}),
      elevation: ThemeElevation.fromJson(json['elevation'] ?? {}),
      gradients: ThemeGradients.fromJson(json['gradients'] ?? {}),
      charts: ThemeCharts.fromJson(json['charts'] ?? {}),
      animations: ThemeAnimations.fromJson(json['animations'] ?? {}),
    );
  }
}

/// Semantic color tokens (NOT hardcoded color names)
class ThemeColors {
  // Background surfaces
  final Color backgroundPrimary;
  final Color backgroundSecondary;

  // Surface containers
  final Color surfacePrimary;
  final Color surfaceSecondary;
  final Color surfaceElevated;
  final Color surfaceBorder;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textAccent;
  final Color textDisabled;

  // Interactive elements
  final Color accent; // Primary interactive color
  final Color accentLight; // Lighter variant for backgrounds
  final Color accentDark; // Darker variant for hovers

  // Semantic colors
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Macro colors (nutrition specific)
  final Color proteinColor;
  final Color carbsColor;
  final Color fatsColor;
  final Color waterColor;
  final Color caloriesColor;

  // Additional states
  final Color disabled;
  final Color overlay; // Semi-transparent overlay

  const ThemeColors({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.surfacePrimary,
    required this.surfaceSecondary,
    required this.surfaceElevated,
    required this.surfaceBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.textAccent,
    required this.textDisabled,
    required this.accent,
    required this.accentLight,
    required this.accentDark,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.proteinColor,
    required this.carbsColor,
    required this.fatsColor,
    required this.waterColor,
    required this.caloriesColor,
    required this.disabled,
    required this.overlay,
  });

  Map<String, dynamic> toJson() => {
    'backgroundPrimary': backgroundPrimary.value,
    'backgroundSecondary': backgroundSecondary.value,
    'surfacePrimary': surfacePrimary.value,
    'surfaceSecondary': surfaceSecondary.value,
    'surfaceElevated': surfaceElevated.value,
    'surfaceBorder': surfaceBorder.value,
    'textPrimary': textPrimary.value,
    'textSecondary': textSecondary.value,
    'textAccent': textAccent.value,
    'textDisabled': textDisabled.value,
    'accent': accent.value,
    'accentLight': accentLight.value,
    'accentDark': accentDark.value,
    'success': success.value,
    'warning': warning.value,
    'error': error.value,
    'info': info.value,
    'proteinColor': proteinColor.value,
    'carbsColor': carbsColor.value,
    'fatsColor': fatsColor.value,
    'waterColor': waterColor.value,
    'caloriesColor': caloriesColor.value,
    'disabled': disabled.value,
    'overlay': overlay.value,
  };

  static ThemeColors fromJson(Map<String, dynamic> json) {
    Color _colorFromJson(dynamic value) {
      if (value is int) return Color(value);
      if (value is String) return Color(int.parse(value.replaceFirst('0x', ''), radix: 16));
      return Colors.white; // Fallback
    }

    return ThemeColors(
      backgroundPrimary: _colorFromJson(json['backgroundPrimary'] ?? 0xFF0D0D0D),
      backgroundSecondary: _colorFromJson(json['backgroundSecondary'] ?? 0xFF1A1A1A),
      surfacePrimary: _colorFromJson(json['surfacePrimary'] ?? 0xFF1A1A1A),
      surfaceSecondary: _colorFromJson(json['surfaceSecondary'] ?? 0xFF242424),
      surfaceElevated: _colorFromJson(json['surfaceElevated'] ?? 0xFF2E2E2E),
      surfaceBorder: _colorFromJson(json['surfaceBorder'] ?? 0xFFFFFFFF).withOpacity(0.1),
      textPrimary: _colorFromJson(json['textPrimary'] ?? 0xFFFFFFFF),
      textSecondary: _colorFromJson(json['textSecondary'] ?? 0xFF888888),
      textAccent: _colorFromJson(json['textAccent'] ?? 0xFFFF9500),
      textDisabled: _colorFromJson(json['textDisabled'] ?? 0xFF555555),
      accent: _colorFromJson(json['accent'] ?? 0xFFFF9500),
      accentLight: _colorFromJson(json['accentLight'] ?? 0xFFFF9500).withOpacity(0.15),
      accentDark: _colorFromJson(json['accentDark'] ?? 0xFFD97600),
      success: _colorFromJson(json['success'] ?? 0xFF00E5A0),
      warning: _colorFromJson(json['warning'] ?? 0xFFFF9500),
      error: _colorFromJson(json['error'] ?? 0xFFFF453A),
      info: _colorFromJson(json['info'] ?? 0xFF00C7FF),
      proteinColor: _colorFromJson(json['proteinColor'] ?? 0xFF4D9FFF),
      carbsColor: _colorFromJson(json['carbsColor'] ?? 0xFFFF9500),
      fatsColor: _colorFromJson(json['fatsColor'] ?? 0xFFAF52DE),
      waterColor: _colorFromJson(json['waterColor'] ?? 0xFF00C7FF),
      caloriesColor: _colorFromJson(json['caloriesColor'] ?? 0xFFFF9500),
      disabled: _colorFromJson(json['disabled'] ?? 0xFF444444),
      overlay: _colorFromJson(json['overlay'] ?? 0xFF000000).withOpacity(0.5),
    );
  }
}

/// Typography configuration
class ThemeTypography {
  final String fontFamily;
  final double displayLargeSize;
  final double displayMediumSize;
  final double headlineLargeSize;
  final double headlineMediumSize;
  final double titleLargeSize;
  final double titleMediumSize;
  final double titleSmallSize;
  final double bodyLargeSize;
  final double bodyMediumSize;
  final double bodySmallSize;
  final double labelLargeSize;
  final double labelMediumSize;

  const ThemeTypography({
    required this.fontFamily,
    this.displayLargeSize = 57,
    this.displayMediumSize = 45,
    this.headlineLargeSize = 32,
    this.headlineMediumSize = 28,
    this.titleLargeSize = 22,
    this.titleMediumSize = 16,
    this.titleSmallSize = 14,
    this.bodyLargeSize = 16,
    this.bodyMediumSize = 14,
    this.bodySmallSize = 12,
    this.labelLargeSize = 14,
    this.labelMediumSize = 12,
  });

  Map<String, dynamic> toJson() => {
    'fontFamily': fontFamily,
    'displayLargeSize': displayLargeSize,
    'displayMediumSize': displayMediumSize,
    'headlineLargeSize': headlineLargeSize,
    'headlineMediumSize': headlineMediumSize,
    'titleLargeSize': titleLargeSize,
    'titleMediumSize': titleMediumSize,
    'titleSmallSize': titleSmallSize,
    'bodyLargeSize': bodyLargeSize,
    'bodyMediumSize': bodyMediumSize,
    'bodySmallSize': bodySmallSize,
    'labelLargeSize': labelLargeSize,
    'labelMediumSize': labelMediumSize,
  };

  static ThemeTypography fromJson(Map<String, dynamic> json) {
    return ThemeTypography(
      fontFamily: json['fontFamily'] ?? 'Inter',
      displayLargeSize: (json['displayLargeSize'] as num?)?.toDouble() ?? 57,
      displayMediumSize: (json['displayMediumSize'] as num?)?.toDouble() ?? 45,
      headlineLargeSize: (json['headlineLargeSize'] as num?)?.toDouble() ?? 32,
      headlineMediumSize: (json['headlineMediumSize'] as num?)?.toDouble() ?? 28,
      titleLargeSize: (json['titleLargeSize'] as num?)?.toDouble() ?? 22,
      titleMediumSize: (json['titleMediumSize'] as num?)?.toDouble() ?? 16,
      titleSmallSize: (json['titleSmallSize'] as num?)?.toDouble() ?? 14,
      bodyLargeSize: (json['bodyLargeSize'] as num?)?.toDouble() ?? 16,
      bodyMediumSize: (json['bodyMediumSize'] as num?)?.toDouble() ?? 14,
      bodySmallSize: (json['bodySmallSize'] as num?)?.toDouble() ?? 12,
      labelLargeSize: (json['labelLargeSize'] as num?)?.toDouble() ?? 14,
      labelMediumSize: (json['labelMediumSize'] as num?)?.toDouble() ?? 12,
    );
  }
}

/// Spacing scale
class ThemeSpacing {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  const ThemeSpacing({
    this.xs = 4,
    this.sm = 8,
    this.md = 16,
    this.lg = 24,
    this.xl = 32,
    this.xxl = 48,
  });

  Map<String, dynamic> toJson() => {
    'xs': xs,
    'sm': sm,
    'md': md,
    'lg': lg,
    'xl': xl,
    'xxl': xxl,
  };

  static ThemeSpacing fromJson(Map<String, dynamic> json) {
    return ThemeSpacing(
      xs: (json['xs'] as num?)?.toDouble() ?? 4,
      sm: (json['sm'] as num?)?.toDouble() ?? 8,
      md: (json['md'] as num?)?.toDouble() ?? 16,
      lg: (json['lg'] as num?)?.toDouble() ?? 24,
      xl: (json['xl'] as num?)?.toDouble() ?? 32,
      xxl: (json['xxl'] as num?)?.toDouble() ?? 48,
    );
  }
}

/// Border radius scale
class ThemeRadius {
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  const ThemeRadius({
    this.xs = 4,
    this.sm = 8,
    this.md = 12,
    this.lg = 16,
    this.xl = 24,
    this.full = 999,
  });

  Map<String, dynamic> toJson() => {
    'xs': xs,
    'sm': sm,
    'md': md,
    'lg': lg,
    'xl': xl,
    'full': full,
  };

  static ThemeRadius fromJson(Map<String, dynamic> json) {
    return ThemeRadius(
      xs: (json['xs'] as num?)?.toDouble() ?? 4,
      sm: (json['sm'] as num?)?.toDouble() ?? 8,
      md: (json['md'] as num?)?.toDouble() ?? 12,
      lg: (json['lg'] as num?)?.toDouble() ?? 16,
      xl: (json['xl'] as num?)?.toDouble() ?? 24,
      full: (json['full'] as num?)?.toDouble() ?? 999,
    );
  }
}

/// Elevation (shadows)
class ThemeElevation {
  final List<BoxShadow> none;
  final List<BoxShadow> sm;
  final List<BoxShadow> md;
  final List<BoxShadow> lg;

  const ThemeElevation({
    this.none = const [],
    this.sm = const [
      BoxShadow(
        color: Color(0x00000000),
        blurRadius: 0,
        spreadRadius: 0,
      ),
    ],
    this.md = const [
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 4,
        spreadRadius: 0,
      ),
    ],
    this.lg = const [
      BoxShadow(
        color: Color(0x3D000000),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
  });

  Map<String, dynamic> toJson() => {
    'none': [],
    'sm': [],
    'md': [],
    'lg': [],
  };

  static ThemeElevation fromJson(Map<String, dynamic> json) {
    return const ThemeElevation();
  }
}

/// Gradients for special components
class ThemeGradients {
  final List<Color> accentGradient;
  final List<Color> successGradient;
  final List<Color> errorGradient;

  const ThemeGradients({
    this.accentGradient = const [
      Color(0xFFFF9500),
      Color(0xFFFF7200),
    ],
    this.successGradient = const [
      Color(0xFF00E5A0),
      Color(0xFF00B87A),
    ],
    this.errorGradient = const [
      Color(0xFFFF453A),
      Color(0xFFCC3629),
    ],
  });

  Map<String, dynamic> toJson() => {
    'accentGradient': accentGradient.map((c) => c.value).toList(),
    'successGradient': successGradient.map((c) => c.value).toList(),
    'errorGradient': errorGradient.map((c) => c.value).toList(),
  };

  static ThemeGradients fromJson(Map<String, dynamic> json) {
    Color _colorFromJson(dynamic value) {
      if (value is int) return Color(value);
      if (value is String) return Color(int.parse(value.replaceFirst('0x', ''), radix: 16));
      return Colors.white;
    }

    return ThemeGradients(
      accentGradient: (json['accentGradient'] as List?)
          ?.cast<dynamic>()
          .map(_colorFromJson)
          .toList() ??
          const [Color(0xFFFF9500), Color(0xFFFF7200)],
      successGradient: (json['successGradient'] as List?)
          ?.cast<dynamic>()
          .map(_colorFromJson)
          .toList() ??
          const [Color(0xFF00E5A0), Color(0xFF00B87A)],
      errorGradient: (json['errorGradient'] as List?)
          ?.cast<dynamic>()
          .map(_colorFromJson)
          .toList() ??
          const [Color(0xFFFF453A), Color(0xFFCC3629)],
    );
  }
}

/// Chart styling
class ThemeCharts {
  final Color gridLineColor;
  final Color tooltipBackground;
  final Color tooltipText;
  final double gridLineWidth;

  const ThemeCharts({
    this.gridLineColor = const Color(0xFFFFFFFF),
    this.tooltipBackground = const Color(0xFF242424),
    this.tooltipText = const Color(0xFFFFFFFF),
    this.gridLineWidth = 0.5,
  });

  Map<String, dynamic> toJson() => {
    'gridLineColor': gridLineColor.value,
    'tooltipBackground': tooltipBackground.value,
    'tooltipText': tooltipText.value,
    'gridLineWidth': gridLineWidth,
  };

  static ThemeCharts fromJson(Map<String, dynamic> json) {
    Color _colorFromJson(dynamic value) {
      if (value is int) return Color(value);
      if (value is String) return Color(int.parse(value.replaceFirst('0x', ''), radix: 16));
      return Colors.white;
    }

    return ThemeCharts(
      gridLineColor: _colorFromJson(json['gridLineColor'] ?? 0xFFFFFFFF),
      tooltipBackground: _colorFromJson(json['tooltipBackground'] ?? 0xFF242424),
      tooltipText: _colorFromJson(json['tooltipText'] ?? 0xFFFFFFFF),
      gridLineWidth: (json['gridLineWidth'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

/// Animation timing
class ThemeAnimations {
  final Duration fast;
  final Duration normal;
  final Duration slow;
  final Curve standardCurve;

  const ThemeAnimations({
    this.fast = const Duration(milliseconds: 150),
    this.normal = const Duration(milliseconds: 300),
    this.slow = const Duration(milliseconds: 500),
    this.standardCurve = Curves.easeInOut,
  });

  Map<String, dynamic> toJson() => {
    'fastMs': fast.inMilliseconds,
    'normalMs': normal.inMilliseconds,
    'slowMs': slow.inMilliseconds,
  };

  static ThemeAnimations fromJson(Map<String, dynamic> json) {
    return ThemeAnimations(
      fast: Duration(milliseconds: json['fastMs'] ?? 150),
      normal: Duration(milliseconds: json['normalMs'] ?? 300),
      slow: Duration(milliseconds: json['slowMs'] ?? 500),
    );
  }
}
