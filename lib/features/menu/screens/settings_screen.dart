import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_profile.dart';
import '../../dashboard/providers/user_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            Expanded(
              child: profile == null
                  ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Personality ─────────────────────
                          const _GroupLabel('Personality & Animations'),
                          const SizedBox(height: 10),
                          _ToggleTile(
                            label: 'Hi-Five on Rest',
                            subtitle: 'Celebratory animation when ending rest (under 25)',
                            value: profile.hiFiveEnabled,
                            onChanged: (v) => _update(ref, profile, hiFiveEnabled: v),
                          ),
                          _ToggleTile(
                            label: 'Celebration Animations',
                            subtitle: 'Confetti and pulse when hitting macro goals',
                            value: profile.celebrationsEnabled,
                            onChanged: (v) => _update(ref, profile, celebrationsEnabled: v),
                          ),
                          _ToggleTile(
                            label: 'Rest Timer Messages',
                            subtitle: 'Motivational messages during rest countdown',
                            value: profile.restMessagesEnabled,
                            onChanged: (v) => _update(ref, profile, restMessagesEnabled: v),
                          ),

                          const SizedBox(height: 24),

                          // ── Notifications ────────────────────
                          const _GroupLabel('Notifications'),
                          const SizedBox(height: 10),
                          _ToggleTile(
                            label: 'Morning Reminder',
                            subtitle: 'Daily prompt to start logging at 8 AM',
                            value: profile.morningReminderEnabled,
                            onChanged: (v) => _update(ref, profile, morningReminderEnabled: v),
                          ),
                          _ToggleTile(
                            label: 'Streak Alerts',
                            subtitle: 'Notify when you hit streak milestones',
                            value: profile.streakAlertsEnabled,
                            onChanged: (v) => _update(ref, profile, streakAlertsEnabled: v),
                          ),
                          _ToggleTile(
                            label: 'Re-balancer Updates',
                            subtitle: 'Weekly goal adjustment summaries',
                            value: profile.rebalancerUpdatesEnabled,
                            onChanged: (v) => _update(ref, profile, rebalancerUpdatesEnabled: v),
                          ),

                          const SizedBox(height: 24),

                          // ── Smart Logger ─────────────────────
                          const _GroupLabel('Smart Logger'),
                          const SizedBox(height: 10),
                          _InfoTile(
                            label: 'Daily Nutrition AI Assists Used',
                            value: '${profile.smartLoggerUsedToday} / 10',
                            color: profile.smartLoggerUsedToday >= 10 ? Colors.redAccent : AppTheme.accent,
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _resetSmartLogger(ref, profile),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.textSecondary,
                                side: BorderSide(color: Colors.white.withOpacity(0.1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              child: const Text('Reset AI Assists Count'),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Theme ───────────────────────────
                          const _GroupLabel('Theme'),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
                            child: const Row(
                              children: [
                                Icon(Icons.palette_rounded, color: AppTheme.textSecondary, size: 20),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('App Theme', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                                      SizedBox(height: 2),
                                      Text('More themes coming soon', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Text('Default', style: TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                              ],
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

  Future<void> _update(WidgetRef ref, UserProfile profile, {
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
    await FirebaseFirestore.instance
        .collection('users')
        .doc(profile.uid)
        .update(updated.toMap());
    ref.invalidate(userProfileProvider);
  }

  Future<void> _resetSmartLogger(WidgetRef ref, UserProfile profile) async {
    await FirebaseFirestore.instance.collection('users').doc(profile.uid).update({
      'smartLoggerUsedToday': 0,
      'smartLoggerLastResetDate': '',
    });
    ref.invalidate(userProfileProvider);
  }
}

class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2));
  }
}

class _ToggleTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({required this.label, required this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
            inactiveTrackColor: AppTheme.background,
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

  const _InfoTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}