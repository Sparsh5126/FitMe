import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/core/theme/providers/theme_provider.dart';

class ThemeSelectorScreen extends ConsumerWidget {
  const ThemeSelectorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // We watch the provider so the UI updates when theme changes.
    // However, activeThemeIdProvider doesn't cause the whole app to rebuild yet unless we use activeThemeConfigProvider in main.dart
    final activeThemeId = ref.watch(activeThemeIdProvider);
    final availableThemes = ref.watch(availableThemesProvider);

    // Get the current theme to style this screen
    final currentTheme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: currentTheme.colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: currentTheme.colors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'App Theme',
                    style: TextStyle(
                      color: currentTheme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Themes List
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                itemCount: availableThemes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final metadata = availableThemes[index];
                  final isSelected = metadata.id == activeThemeId;

                  return _ThemePreviewCard(
                    metadata: metadata,
                    isSelected: isSelected,
                    onTap: () {
                      ref
                          .read(activeThemeIdProvider.notifier)
                          .switchTheme(metadata.id);
                    },
                    currentTheme: currentTheme,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePreviewCard extends StatelessWidget {
  final ThemeMetadata metadata;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic currentTheme;

  const _ThemePreviewCard({
    required this.metadata,
    required this.isSelected,
    required this.onTap,
    required this.currentTheme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: currentTheme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? currentTheme.colors.accent : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: currentTheme.colors.accent.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Color Preview Circles
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    metadata.accentColor,
                    metadata.accentColor.withValues(alpha: 0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: currentTheme.colors.textPrimary,
                    )
                  : null,
            ),
            const SizedBox(width: 16),

            // Text Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.name,
                    style: TextStyle(
                      color: currentTheme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadata.description,
                    style: TextStyle(
                      color: currentTheme.colors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            // Radio Indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? currentTheme.colors.accent
                      : currentTheme.colors.textSecondary.withValues(
                          alpha: 0.3,
                        ),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentTheme.colors.accent,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
