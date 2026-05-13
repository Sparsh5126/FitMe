/// Migration Guide for Theme System
///
/// This file documents the systematic approach to migrate FitMe screens
/// to use the new centralized theme system.
///
/// COMPLETED MIGRATIONS:
/// ✅ lib/features/auth/screens/login_screen.dart
/// ✅ lib/core/theme/app_theme.dart (backwards compatible)
///
/// PRIORITY MIGRATIONS (Do these next):
/// 1. Signup Screen (70% complete - needs build method)
/// 2. Settings Screen (themes selector UI)
/// 3. Home Screen (most visible)
/// 4. App Shell (bottom navigation)
/// 5. Auth Migration Dialog
/// 6. Backup Settings
///
/// PATTERN FOR MIGRATION:
///
/// STEP 1: Add Imports
/// ```dart
/// import 'package:fitme/core/theme/managers/theme_manager.dart';
/// import 'package:fitme/core/theme/providers/theme_provider.dart';
/// ```
///
/// STEP 2: Get Theme in Build Method
/// ```dart
/// @override
/// Widget build(BuildContext context) {
///   final theme = ThemeManager.instance.activeTheme;
///   
///   // Now use theme throughout this method
/// }
/// ```
///
/// STEP 3: Replace Colors
/// BEFORE:
///   backgroundColor: AppTheme.background,
///   color: Colors.white,
/// AFTER:
///   backgroundColor: theme.colors.backgroundPrimary,
///   color: theme.colors.textPrimary,
///
/// STEP 4: Replace Spacing
/// BEFORE:
///   const SizedBox(height: 16),
///   padding: const EdgeInsets.all(24),
/// AFTER:
///   SizedBox(height: theme.spacing.md),
///   padding: EdgeInsets.all(theme.spacing.lg),
///
/// STEP 5: Replace Radius
/// BEFORE:
///   BorderRadius.circular(12),
/// AFTER:
///   BorderRadius.circular(theme.radius.md),
///
/// STEP 6: Replace Typography
/// BEFORE:
///   fontSize: 18, fontWeight: FontWeight.bold
/// AFTER:
///   fontSize: theme.typography.titleLargeSize, fontWeight: FontWeight.bold
///
/// QUICK REFERENCE:
/// 
/// Colors:
///   backgroundPrimary (dark background)
///   surfacePrimary (card/container)
///   textPrimary (main text, white)
///   textSecondary (secondary text, grey)
///   accent (orange buttons/interactive)
///   success/warning/error (semantic)
///   proteinColor, carbsColor, fatsColor, waterColor (nutrition)
///
/// Spacing:
///   xs: 4, sm: 8, md: 16, lg: 24, xl: 32, xxl: 48
///
/// Radius:
///   xs: 4, sm: 8, md: 12, lg: 16, xl: 24, full: 999
///
/// Typography Sizes:
///   headlineLargeSize (32)
///   headlineMediumSize (28)
///   titleLargeSize (22)
///   bodyMediumSize (14)
///   bodySmallSize (12)
///
/// FOR HELPER METHODS:
/// Pass theme as parameter and use theme.colors, theme.spacing, etc.
///
/// Example:
/// ```dart
/// Widget _buildCard(dynamic theme) {
///   return Container(
///     color: theme.colors.surfacePrimary,
///     padding: EdgeInsets.all(theme.spacing.md),
///     child: Text('Hello', style: TextStyle(
///       color: theme.colors.textPrimary,
///       fontSize: theme.typography.bodyMediumSize,
///     )),
///   );
/// }
/// ```
///
/// TESTING AFTER MIGRATION:
/// 1. App should look visually identical
/// 2. No layout changes
/// 3. Colors match original
/// 4. Spacing proportions same
/// 5. Test theme switching works (will implement in Phase 4)
///
/// COMMON PITFALLS TO AVOID:
/// ❌ Forgetting to pass theme parameter to helper methods
/// ❌ Mixing old AppTheme.xxx and new theme.colors
/// ❌ Forgetting to import ThemeManager
/// ❌ Using Colors.white directly instead of theme.colors.textPrimary
/// ❌ Not updating SizedBox height/padding spacing
///
/// VERIFICATION CHECKLIST:
/// [ ] All colors use theme.colors.*
/// [ ] All spacing uses theme.spacing.*
/// [ ] All radius uses theme.radius.*
/// [ ] All font sizes use theme.typography.*
/// [ ] Helper methods receive theme parameter
/// [ ] No const decorations with hardcoded values
/// [ ] Build method gets theme from ThemeManager
/// [ ] App still looks identical to original
///
class ThemeMigrationGuide {}
