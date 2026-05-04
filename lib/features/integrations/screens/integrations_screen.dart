import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/health_provider.dart';
import '../services/health_sync_service.dart';

class IntegrationsScreen extends ConsumerWidget {
  const IntegrationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectState = ref.watch(healthConnectNotifier);
    final isConnected = connectState.value ?? false;

    return Scaffold(
      backgroundColor: AppTheme.background,
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
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const Text('Integrations',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
                  const Spacer(),
                  if (isConnected)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppTheme.accent),
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
                    const _GroupLabel('Health Platform'),
                    const SizedBox(height: 10),
                    _HealthConnectCard(
                      isConnected: isConnected,
                      isLoading: connectState.isLoading,
                      onConnect: () async {
                        HapticFeedback.mediumImpact();
                        final ok = await ref
                            .read(healthConnectNotifier.notifier)
                            .connect();
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'Permission denied. Enable in device settings.'),
                            ),
                          );
                        }
                      },
                    ),

                    // ── Live summary ─────────────────────
                    if (isConnected) ...[
                      const SizedBox(height: 24),
                      const _GroupLabel("Today's Activity"),
                      const SizedBox(height: 10),
                      const _HealthSummaryCard(),
                    ],

                    const SizedBox(height: 24),

                    // ── Coming soon ──────────────────────
                    const _GroupLabel('Coming Soon'),
                    const SizedBox(height: 10),
                    _ComingSoonTile(
                      icon: '⌚',
                      label: 'Fitbit',
                      subtitle: 'Sync workouts and sleep data',
                    ),
                    _ComingSoonTile(
                      icon: '🏃',
                      label: 'Garmin Connect',
                      subtitle: 'Import runs, rides, and VO2 max',
                    ),
                    _ComingSoonTile(
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

  const _HealthConnectCard({
    required this.isConnected,
    required this.isLoading,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isConnected
            ? Border.all(color: AppTheme.success.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Platform icons
              const Text('❤️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Apple Health / Google Fit',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    isConnected ? 'Connected' : 'Not connected',
                    style: TextStyle(
                      color: isConnected ? AppTheme.success : AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (isConnected)
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.success, size: 22),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Syncs steps, calories burned, and weight from your device\'s health platform.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
          ),
          if (!isConnected) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : onConnect,
                child: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.background),
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
  const _HealthSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(healthSummaryProvider);

    return summaryAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppTheme.accent),
        ),
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
        child: const Text('Failed to load health data',
            style: TextStyle(color: AppTheme.textSecondary)),
      ),
      data: (summary) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatChip(
              icon: Icons.directions_walk_rounded,
              label: 'Steps',
              value: _fmt(summary.steps),
              color: AppTheme.accent,
            ),
            _divider(),
            _StatChip(
              icon: Icons.local_fire_department_rounded,
              label: 'Burned',
              value: '${summary.caloriesBurned.toInt()} kcal',
              color: const Color(0xFFFF6B6B),
            ),
            _divider(),
            _StatChip(
              icon: Icons.monitor_weight_rounded,
              label: 'Weight',
              value: summary.weightKg != null
                  ? '${summary.weightKg!.toStringAsFixed(1)} kg'
                  : '—',
              color: AppTheme.proteinColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        color: Colors.white.withOpacity(0.06),
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

  const _StatChip(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 15)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 11)),
      ],
    );
  }
}

// ── Coming soon tile ──────────────────────────────────
class _ComingSoonTile extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;

  const _ComingSoonTile(
      {required this.icon, required this.label, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppTheme.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20)),
            child: const Text('Soon',
                style: TextStyle(
                    color: AppTheme.accent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── Group label ───────────────────────────────────────
class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(label.toUpperCase(),
        style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2));
  }
}