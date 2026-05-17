import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/integrations/providers/health_provider.dart';
// Removed direct import of health_sync_service — screen communicates only
// through the provider layer (HealthConnectNotifier). Graph confirmed
// integrations_screen → health_sync_service was a leaking dependency.

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  Future<bool> _requestPermissions(BuildContext context) async {
    // Health Connect on Android 13+ needs activityRecognition at minimum.
    debugPrint("Requesting permissions: [activityRecognition, sensors]");
    final statuses = await [
      Permission.activityRecognition,
      if (Theme.of(context).platform == TargetPlatform.android)
        Permission.sensors,
    ].request();

    debugPrint("Permission statuses: $statuses");

    final denied = statuses.values.any(
      (s) =>
          s == PermissionStatus.denied ||
          s == PermissionStatus.permanentlyDenied,
    );

    if (denied && context.mounted) {
      final isPermanent = statuses.values.any(
        (s) => s == PermissionStatus.permanentlyDenied,
      );

      if (isPermanent) {
        final theme = ThemeManager.instance.activeTheme;
        // Permanent denial — direct user to settings
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            backgroundColor: theme.colors.surfacePrimary,
            title: Text(
              'Permission required',
              style: TextStyle(color: theme.colors.textPrimary),
            ),
            content: Text(
              'Health access was permanently denied.\n'
              'Open Settings and enable Activity Recognition to continue.',
              style: TextStyle(color: theme.colors.textSecondary, height: 1.5),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: theme.colors.textSecondary),
                ),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await openAppSettings();
                },
                child: Text(
                  'Open Settings',
                  style: TextStyle(color: theme.colors.accent),
                ),
              ),
            ],
          ),
        );
      }
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ThemeManager.instance.activeTheme;
    final connectState = ref.watch(healthConnectNotifier);
    final isConnected = connectState.value ?? false;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────
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
                    'Integrations',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  if (isConnected)
                    IconButton(
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: theme.colors.accent,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ref.read(healthConnectNotifier.notifier).refresh();
                      },
                    ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Health platform card ─────────────
                    _GroupLabel('Health Platform', theme: theme),
                    const SizedBox(height: 10),
                    _HealthConnectCard(
                      isConnected: isConnected,
                      isLoading: connectState.isLoading,
                      theme: theme,
                      onConnect: () async {
                        HapticFeedback.mediumImpact();

                        // Step 1: request runtime permissions from UI context
                        final granted = await _requestPermissions(context);
                        if (!granted) return;

                        // Step 2: delegate to provider (which calls HealthSyncService)
                        if (!context.mounted) return;
                        final ok = await ref
                            .read(healthConnectNotifier.notifier)
                            .connect();

                        if (!ok && context.mounted) {
                          // Check if SDK is unavailable or update required
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: theme.colors.surfacePrimary,
                              behavior: SnackBarBehavior.floating,
                              content: Text(
                                'Health Connect SDK is missing or needs update. Check Play Store.',
                                style: TextStyle(
                                  color: theme.colors.textPrimary,
                                ),
                              ),
                              action: SnackBarAction(
                                label: 'Settings',
                                textColor: theme.colors.accent,
                                onPressed: openAppSettings,
                              ),
                            ),
                          );
                        }
                      },
                    ),

                    // ── Live summary ─────────────────────
                    if (isConnected) ...[
                      const SizedBox(height: 24),
                      _GroupLabel("Today's Activity", theme: theme),
                      const SizedBox(height: 10),
                      _HealthSummaryCard(theme: theme),
                    ],

                    const SizedBox(height: 24),

                    // ── Coming soon ──────────────────────
                    _GroupLabel('Coming Soon', theme: theme),
                    const SizedBox(height: 10),
                    _ComingSoonTile(
                      theme: theme,
                      icon: '⌚',
                      label: 'Fitbit',
                      subtitle: 'Sync workouts and sleep data',
                    ),
                    _ComingSoonTile(
                      theme: theme,
                      icon: '🏃',
                      label: 'Garmin Connect',
                      subtitle: 'Import runs, rides, and VO2 max',
                    ),
                    _ComingSoonTile(
                      theme: theme,
                      icon: '🔵',
                      label: 'Whoop',
                      subtitle: 'Recovery and strain scores',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Health connect card ───────────────────────────────
class _HealthConnectCard extends StatelessWidget {
  final bool isConnected;
  final bool isLoading;
  final VoidCallback onConnect;
  final dynamic theme;

  const _HealthConnectCard({
    required this.isConnected,
    required this.isLoading,
    required this.onConnect,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: isConnected
            ? Border.all(
                color: theme.colors.success.withOpacity(0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('❤️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Health Connect',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isConnected ? 'Connected' : 'Not connected',
                    style: TextStyle(
                      color: isConnected
                          ? theme.colors.success
                          : theme.colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isConnected)
                Icon(
                  Icons.check_circle_rounded,
                  color: theme.colors.success,
                  size: 22,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Syncs steps, calories burned, and weight from your device\'s health platform.',
            style: TextStyle(
              color: theme.colors.textSecondary,
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onConnect,
                child: isLoading
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colors.backgroundPrimary,
                        ),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Today summary card ────────────────────────────────
class _HealthSummaryCard extends ConsumerWidget {
  final dynamic theme;
  const _HealthSummaryCard({required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(healthSummaryProvider);

    return summaryAsync.when(
      loading: () => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: CircularProgressIndicator(color: theme.colors.accent),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colors.textSecondary,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Failed to load health data',
              style: TextStyle(color: theme.colors.textSecondary),
            ),
          ],
        ),
      ),
      data: (summary) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatChip(
              icon: Icons.directions_walk_rounded,
              label: 'Steps',
              value: _fmt(summary.steps),
              color: theme.colors.accent,
              theme: theme,
            ),
            _divider(theme),
            _StatChip(
              icon: Icons.local_fire_department_rounded,
              label: 'Burned',
              value: '${summary.caloriesBurned.toInt()} kcal',
              color: const Color(0xFFFF6B6B),
              theme: theme,
            ),
            _divider(theme),
            _StatChip(
              icon: Icons.monitor_weight_rounded,
              label: 'Weight',
              value: summary.weightKg != null
                  ? '${summary.weightKg!.toStringAsFixed(1)} kg'
                  : '—',
              color: theme.colors.proteinColor,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(dynamic theme) => Container(
    width: 1,
    height: 40,
    color: theme.colors.textSecondary.withOpacity(0.12),
  );

  String _fmt(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final dynamic theme;

  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(color: theme.colors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

// ── Coming soon tile ──────────────────────────────────
class _ComingSoonTile extends StatelessWidget {
  final dynamic theme;
  final String icon;
  final String label;
  final String subtitle;

  const _ComingSoonTile({
    required this.theme,
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: theme.colors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Soon',
              style: TextStyle(
                color: theme.colors.accent,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Group label ───────────────────────────────────────
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
