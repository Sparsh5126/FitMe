import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../services/backup_service.dart';

class BackupSettingsScreen extends ConsumerStatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen> {
  bool _backing = false;
  bool _restoring = false;
  BackupStatus? _status;
  String? _message;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final status = await BackupService().getBackupStatus();
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

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
                  const Text('Cloud Backup',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18)),
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
                    if (!isLoggedIn) ...[
                      // ── Guest notice ────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: AppTheme.accent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppTheme.accent, size: 20),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sign in to enable cloud backup & multi-device sync.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const LoginScreen(),
                            ),
                          ),
                          child: const Text('Sign In'),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ] else ...[
                      // ── Status card ──────────────────────
                      const _GroupLabel('Status'),
                      const SizedBox(height: 10),
                      _status != null
                          ? _StatusCard(status: _status!)
                          : const Center(
                              child: CircularProgressIndicator(
                                  color: AppTheme.accent),
                            ),

                      const SizedBox(height: 24),

                      // ── Message ──────────────────────────
                      if (_message != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: AppTheme.success.withOpacity(0.3)),
                          ),
                          child: Text(_message!,
                              style: const TextStyle(
                                  color: AppTheme.success, fontSize: 13)),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Actions ──────────────────────────
                      const _GroupLabel('Actions'),
                      const SizedBox(height: 10),

                      // Backup button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _backing ? null : _doBackup,
                          icon: _backing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.background),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(_backing ? 'Backing up...' : 'Backup Now'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Restore button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _restoring ? null : _doRestore,
                          icon: _restoring
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppTheme.accent),
                                )
                              : const Icon(Icons.cloud_download_outlined),
                          label: Text(
                              _restoring ? 'Restoring...' : 'Restore from Backup'),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Danger zone ──────────────────────
                      const _GroupLabel('Danger Zone'),
                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: _doDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete Backup'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.error,
                          side: BorderSide(
                              color: AppTheme.error.withOpacity(0.3)),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Info ─────────────────────────────
                      const _GroupLabel('About'),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow('Backed up',
                                _status?.logsCount.toString() ?? '—',
                                'meal logs'),
                            const SizedBox(height: 10),
                            _InfoRow('Last backup', _status?.lastBackupText ?? '—',
                                ''),
                            const SizedBox(height: 10),
                            const Text(
                              'Backup includes: meal logs, streak data, and profile settings. Favorites sync locally on your device.',
                              style: TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _doBackup() async {
    setState(() => _backing = true);
    HapticFeedback.mediumImpact();

    final now = await BackupService().backupAll();
    await _loadStatus();

    if (mounted) {
      setState(() {
        _backing = false;
        _message = now != null
            ? 'Backup successful! ${_status?.logsCount ?? 0} meal logs backed up.'
            : 'Backup failed. Check your connection.';
      });
      _clearMessageAfter(3);
    }
  }

  Future<void> _doRestore() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Restore from Backup?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will merge backed-up meals into your current device.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _restoring = true);
    HapticFeedback.mediumImpact();

    final count = await BackupService().restoreNutritionLogs();
    await BackupService().restoreStreakData();

    if (mounted) {
      setState(() {
        _restoring = false;
        _message = count > 0
            ? 'Restored $count meal logs to this device.'
            : 'No meals to restore.';
      });
      _clearMessageAfter(3);
    }
  }

  Future<void> _doDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete Backup?',
            style: TextStyle(color: AppTheme.error)),
        content: const Text(
            'This permanently deletes your cloud backup. You can still backup again anytime.',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    HapticFeedback.mediumImpact();
    final ok = await BackupService().deleteBackup();
    await _loadStatus();

    if (mounted) {
      setState(() => _message = ok ? 'Backup deleted.' : 'Failed to delete backup.');
      _clearMessageAfter(3);
    }
  }

  void _clearMessageAfter(int seconds) {
    Future.delayed(Duration(seconds: seconds), () {
      if (mounted) setState(() => _message = null);
    });
  }
}

// ── Status card ───────────────────────────────────────
class _StatusCard extends StatelessWidget {
  final BackupStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: status.hasBackup
            ? Border.all(color: AppTheme.success.withOpacity(0.4), width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Icon(
            status.hasBackup ? Icons.check_circle_rounded : Icons.cloud_off_rounded,
            color: status.hasBackup ? AppTheme.success : AppTheme.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(status.hasBackup ? 'Backup exists' : 'No backup yet',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(status.lastBackupText,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info row ───────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String unit;

  const _InfoRow(this.label, this.value, this.unit);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12)),
        Text('$value $unit',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
      ],
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

// Import for login screen reference
// In real file: import '../../auth/screens/login_screen.dart';
// For now, placeholder — wire the actual import
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text('Navigate to LoginScreen'),
        ),
      );
}