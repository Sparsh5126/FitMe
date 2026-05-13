import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fitme/core/theme/models/theme_config.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/core/theme/themes/fitme_default_theme.dart';
import 'dart:convert';

/// Key for storing selected theme in SharedPreferences
const String _themePrefKey = 'selected_theme_id';

/// Notifier for managing active theme state
class ActiveThemeNotifier extends Notifier<String> {
  @override
  String build() {
    // Return the ID of the active theme
    return ThemeManager.instance.activeTheme.id;
  }

  /// Switch to a theme by ID and persist
  Future<void> switchTheme(String themeId) async {
    if (!ThemeManager.instance.switchTheme(themeId)) {
      throw Exception('Theme "$themeId" not found');
    }

    // Persist to SharedPreferences
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themePrefKey, themeId);
    } catch (e) {
      print('Failed to persist theme preference: $e');
    }

    state = themeId;
  }
}

/// Provider for active theme ID
final activeThemeIdProvider =
    NotifierProvider<ActiveThemeNotifier, String>(
      ActiveThemeNotifier.new,
    );

/// Provider for the active ThemeConfig
final activeThemeConfigProvider = Provider<ThemeConfig>((ref) {
  final themeId = ref.watch(activeThemeIdProvider);
  final theme = ThemeManager.instance.getTheme(themeId);
  return theme ?? FitMeDefaultTheme.config;
});

/// Provider for available theme metadata (for theme picker)
final availableThemesProvider = Provider<List<ThemeMetadata>>((ref) {
  return ThemeManager.instance.getAllThemeMetadata();
});

/// Provider for loading saved theme on app startup
final savedThemeProvider = FutureProvider<String>((ref) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeId = prefs.getString(_themePrefKey);
    
    if (savedThemeId != null && 
        ThemeManager.instance.getTheme(savedThemeId) != null) {
      return savedThemeId;
    }
  } catch (e) {
    print('Failed to load saved theme: $e');
  }

  // Return default theme if no saved theme found
  return FitMeDefaultTheme.config.id;
});

/// Notifier for registering new themes from JSON
class ThemeRegistryNotifier extends Notifier<int> {
  @override
  int build() => 0; // Simple counter to trigger rebuilds

  /// Register a theme from JSON
  Future<void> registerThemeFromJson(Map<String, dynamic> json) async {
    try {
      final theme = ThemeConfig.fromJson(json);
      
      // Validate theme
      final error = _validateTheme(theme);
      if (error != null) {
        throw Exception('Theme validation failed: $error');
      }

      ThemeManager.instance.registerTheme(theme);
      state = state + 1; // Increment counter to trigger rebuild
    } catch (e) {
      throw Exception('Failed to register theme: $e');
    }
  }

  /// Register a theme object directly
  Future<void> registerTheme(ThemeConfig theme) async {
    try {
      final error = _validateTheme(theme);
      if (error != null) {
        throw Exception('Theme validation failed: $error');
      }

      ThemeManager.instance.registerTheme(theme);
      state = state + 1;
    } catch (e) {
      throw Exception('Failed to register theme: $e');
    }
  }

  String? _validateTheme(ThemeConfig theme) {
    if (theme.id.isEmpty) return 'Theme ID is required';
    if (theme.name.isEmpty) return 'Theme name is required';
    if (theme.colors == null) return 'Theme colors are required';
    return null;
  }
}

/// Provider for theme registry operations
final themeRegistryProvider = NotifierProvider<ThemeRegistryNotifier, int>(
  ThemeRegistryNotifier.new,
);

/// Helper provider to export active theme as JSON
final exportedThemeJsonProvider = Provider<String>((ref) {
  final theme = ref.watch(activeThemeConfigProvider);
  return jsonEncode(theme.toJson());
});

/// Import/export theme helpers
class ThemeImportExport {
  /// Export active theme to JSON string
  static String exportActiveTheme() {
    final theme = ThemeManager.instance.activeTheme;
    return jsonEncode(theme.toJson());
  }

  /// Export theme by ID to JSON string
  static String? exportThemeById(String themeId) {
    final theme = ThemeManager.instance.getTheme(themeId);
    if (theme == null) return null;
    return jsonEncode(theme.toJson());
  }

  /// Import theme from JSON string
  static ThemeConfig? importFromJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ThemeConfig.fromJson(json);
    } catch (e) {
      print('Failed to import theme: $e');
      return null;
    }
  }
}

/// Theme metadata (for theme picker UI)
typedef ThemeMetadata = ({
  String id,
  String name,
  String description,
  Color accentColor,
});