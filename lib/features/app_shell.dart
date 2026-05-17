import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/nutrition/screens/home_screen.dart';
import 'package:fitme/features/profile/screens/profile_screen.dart';
import 'package:fitme/features/menu/screens/menu_screen.dart';
import 'package:fitme/features/insights/screens/insights_screen.dart';
import 'package:fitme/features/nutrition/widgets/log_sheet.dart';
import 'package:fitme/features/nutrition/widgets/smart_logger_sheet.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 2;

  static const _screens = [
    MenuScreen(),
    InsightsScreen(),
    HomeScreen(),
    SizedBox(), // placeholder — Smart Logger nav opens modal, never shown
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colors.surfacePrimary,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: theme.colors.textSecondary.withOpacity(0.05),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.menu_rounded,
                  label: 'Menu',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                  theme: theme,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.show_chart_rounded,
                  label: 'Insights',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                  theme: theme,
                ),
              ),

              // Central Action Button
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (_selectedIndex != 2) {
                      setState(() => _selectedIndex = 2);
                    } else {
                      LogSheet.show(context);
                    }
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colors.backgroundPrimary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colors.accent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colors.accent.withOpacity(0.3),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: theme.colors.accent,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Log',
                        style: TextStyle(
                          color: _selectedIndex == 2
                              ? theme.colors.accent
                              : theme.colors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: _NavItem(
                  icon: Icons.auto_awesome_rounded,
                  label: 'Smart Logger',
                  isSelected: false,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    SmartLoggerSheet.show(context);
                  },
                  theme: theme,
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  isSelected: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                  theme: theme,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final dynamic theme;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? theme.colors.accent : theme.colors.textSecondary;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colors.accent.withOpacity(0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
