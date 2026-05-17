import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/core/models/user_profile.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/nutrition/services/local_nutrition_service.dart';
import 'package:fitme/features/menu/screens/theme_selector_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: theme.colors.textPrimary,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Text(
                    'Settings',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: profile == null
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.colors.accent,
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Personality ─────────────────────
                          _GroupLabel('Personality & Animations', theme: theme),
                          const SizedBox(height: 10),
                          _ToggleTile(
                            label: 'Hi-Five on Rest',
                            subtitle:
                                'Celebratory animation when ending rest (under 25)',
                            value: profile.hiFiveEnabled,
                            onChanged: (v) =>
                                _update(ref, profile, hiFiveEnabled: v),
                            theme: theme,
                          ),
                          _ToggleTile(
                            label: 'Celebration Animations',
                            subtitle:
                                'Confetti and pulse when hitting macro goals',
                            value: profile.celebrationsEnabled,
                            onChanged: (v) =>
                                _update(ref, profile, celebrationsEnabled: v),
                            theme: theme,
                          ),
                          _ToggleTile(
                            label: 'Rest Timer Messages',
                            subtitle:
                                'Motivational messages during rest countdown',
                            value: profile.restMessagesEnabled,
                            onChanged: (v) =>
                                _update(ref, profile, restMessagesEnabled: v),
                            theme: theme,
                          ),

                          const SizedBox(height: 24),

                          // ── Notifications ────────────────────
                          _GroupLabel('Notifications', theme: theme),
                          const SizedBox(height: 10),
                          _ToggleTile(
                            label: 'Morning Reminder',
                            subtitle: 'Daily prompt to start logging at 8 AM',
                            value: profile.morningReminderEnabled,
                            onChanged: (v) => _update(
                              ref,
                              profile,
                              morningReminderEnabled: v,
                            ),
                            theme: theme,
                          ),
                          _ToggleTile(
                            label: 'Streak Alerts',
                            subtitle: 'Notify when you hit streak milestones',
                            value: profile.streakAlertsEnabled,
                            onChanged: (v) =>
                                _update(ref, profile, streakAlertsEnabled: v),
                            theme: theme,
                          ),
                          _ToggleTile(
                            label: 'Re-balancer Updates',
                            subtitle: 'Weekly goal adjustment summaries',
                            value: profile.rebalancerUpdatesEnabled,
                            onChanged: (v) => _update(
                              ref,
                              profile,
                              rebalancerUpdatesEnabled: v,
                            ),
                            theme: theme,
                          ),

                          const SizedBox(height: 24),

                          // ── Smart Logger ─────────────────────
                          _GroupLabel('Smart Logger', theme: theme),
                          const SizedBox(height: 10),
                          Builder(
                            builder: (context) {
                              final today = DateTime.now().toIso8601String().substring(0, 10);
                              final smartLoggerUsed = profile.smartLoggerLastResetDate == today
                                  ? profile.smartLoggerUsedToday
                                  : 0;
                              return _InfoTile(
                                label: 'Daily Nutrition AI Assists Used',
                                value: '$smartLoggerUsed / 10',
                                color: smartLoggerUsed >= 10
                                    ? Colors.redAccent
                                    : theme.colors.accent,
                                theme: theme,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _resetSmartLogger(ref, profile),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colors.textSecondary,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                              child: const Text('Reset AI Assists Count'),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Theme ───────────────────────────
                          _GroupLabel('Theme', theme: theme),
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ThemeSelectorScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: theme.colors.surfacePrimary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.palette_rounded,
                                    color: theme.colors.textSecondary,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'App Theme',
                                          style: TextStyle(
                                            color: theme.colors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Change Theme',
                                          style: TextStyle(
                                            color: theme.colors.textSecondary,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    ThemeManager.instance.activeTheme.name,
                                    style: TextStyle(
                                      color: theme.colors.accent,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _update(
    WidgetRef ref,
    UserProfile profile, {
    bool? hiFiveEnabled,
    bool? celebrationsEnabled,
    bool? restMessagesEnabled,
    bool? morningReminderEnabled,
    bool? streakAlertsEnabled,
    bool? rebalancerUpdatesEnabled,
  }) async {
    HapticFeedback.selectionClick();
    final updated = profile.copyWith(
      hiFiveEnabled: hiFiveEnabled,
      celebrationsEnabled: celebrationsEnabled,
      restMessagesEnabled: restMessagesEnabled,
      morningReminderEnabled: morningReminderEnabled,
      streakAlertsEnabled: streakAlertsEnabled,
      rebalancerUpdatesEnabled: rebalancerUpdatesEnabled,
    );
    final isGuest = ref.read(isGuestProvider);
    if (isGuest) {
      await LocalNutritionService.saveProfile(updated);
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .update(updated.toMap());
    }
    ref.invalidate(userProfileProvider);
  }

  Future<void> _resetSmartLogger(WidgetRef ref, UserProfile profile) async {
    final isGuest = ref.read(isGuestProvider);
    final updated = profile.copyWith(
      smartLoggerUsedToday: 0,
      smartLoggerLastResetDate: '',
    );

    if (isGuest) {
      await LocalNutritionService.saveProfile(updated);
    } else {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(profile.uid)
          .update(updated.toMap());
    }

    ref.invalidate(userProfileProvider);
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  final dynamic theme;

  const _GroupLabel(this.label, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: theme.colors.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final dynamic theme;

  const _ToggleTile({
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: theme.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.colors.accent,
            inactiveTrackColor: theme.colors.backgroundPrimary,
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final dynamic theme;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: theme.colors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
