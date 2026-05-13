import 'package:flutter/material.dart';
import 'package:fitme/core/theme/models/theme_config.dart';
import 'package:fitme/core/theme/themes/fitme_default_theme.dart';

/// Manages theme state, switching, and persistence
class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  static ThemeManager get instance => _instance;

  // Map of available themes
  final Map<String, ThemeConfig> _themes = {
    'fitme-default-amoled': FitMeDefaultTheme.config,
  };

  // Current active theme
  late ThemeConfig _activeTheme;
  
  // Listeners for theme changes
  final List<VoidCallback> _listeners = [];

  ThemeManager._internal() {
    _activeTheme = FitMeDefaultTheme.config;
  }

  /// Get current active theme
  ThemeConfig get activeTheme => _activeTheme;
  
  /// Get current theme as Flutter ThemeData
  ThemeData get themeData => FitMeDefaultTheme.toThemeData(_activeTheme);

  /// Get list of all available theme IDs
  List<String> get availableThemeIds => _themes.keys.toList();

  /// Get theme by ID
  ThemeConfig? getTheme(String id) => _themes[id];

  /// Register a new theme
  void registerTheme(ThemeConfig theme) {
    _themes[theme.id] = theme;
    _notifyListeners();
  }

  /// Switch to a theme by ID
  bool switchTheme(String themeId) {
    final theme = _themes[themeId];
    if (theme == null) {
      print('Theme "$themeId" not found');
      return false;
    }

    _activeTheme = theme;
    _notifyListeners();
    return true;
  }

  /// Switch to a theme by config
  void switchToTheme(ThemeConfig theme) {
    _activeTheme = theme;
    _notifyListeners();
  }

  /// Add listener for theme changes
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners of theme change
  void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Load theme from JSON (for downloaded/generated themes)
  ThemeConfig loadThemeFromJson(Map<String, dynamic> json) {
    return ThemeConfig.fromJson(json);
  }

  /// Validate theme schema
  String? validateTheme(ThemeConfig theme) {
    try {
      // Check required fields
      if (theme.id.isEmpty) return 'Theme ID cannot be empty';
      if (theme.name.isEmpty) return 'Theme name cannot be empty';
      if (theme.colors == null) return 'Theme must have colors defined';
      
      // Add more validations as needed
      return null; // Valid
    } catch (e) {
      return 'Theme validation error: $e';
    }
  }

  /// Export active theme as JSON
  Map<String, dynamic> exportActiveThemeAsJson() {
    return _activeTheme.toJson();
  }

  /// Get theme preview (returns Flutter ThemeData)
  ThemeData getThemePreview(String themeId) {
    final theme = _themes[themeId];
    if (theme == null) {
      return FitMeDefaultTheme.toThemeData(FitMeDefaultTheme.config);
    }
    return FitMeDefaultTheme.toThemeData(theme);
  }

  /// Reset to default theme
  void resetToDefault() {
    _activeTheme = FitMeDefaultTheme.config;
    _notifyListeners();
  }

  /// Get all themes with metadata (for theme picker UI)
  List<ThemeMetadata> getAllThemeMetadata() {
    return _themes.values
        .map((theme) => ThemeMetadata(
          id: theme.id,
          name: theme.name,
          description: theme.description,
          accentColor: theme.colors.accent,
        ))
        .toList();
  }
}

/// Metadata for theme picker UI
class ThemeMetadata {
  final String id;
  final String name;
  final String description;
  final Color accentColor;

  const ThemeMetadata({
    required this.id,
    required this.name,
    required this.description,
    required this.accentColor,
  });
}
