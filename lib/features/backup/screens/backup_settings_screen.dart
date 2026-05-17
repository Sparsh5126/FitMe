import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/backup/services/backup_service.dart';

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
    final isLoggedIn = ref.watch(authNotifierProvider).value != null;
    final theme = ThemeManager.instance.activeTheme;

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
                    'Cloud Backup',
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
                          color: theme.colors.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: theme.colors.accent.withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: theme.colors.accent,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Sign in to enable cloud backup & multi-device sync.',
                                style: TextStyle(
                                  color: theme.colors.textPrimary,
                                  fontSize: 13,
                                ),
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
                      _GroupLabel('Status', theme: theme),
                      const SizedBox(height: 10),
                      _status != null
                          ? _StatusCard(status: _status!, theme: theme)
                          : CircularProgressIndicator(
                              color: theme.colors.accent,
                            ),

                      const SizedBox(height: 24),

                      // ── Message ──────────────────────────
                      if (_message != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colors.success.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _message!,
                            style: TextStyle(
                              color: theme.colors.success,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Actions ──────────────────────────
                      _GroupLabel('Actions', theme: theme),
                      const SizedBox(height: 10),

                      // Backup button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _backing ? null : _doBackup,
                          icon: _backing
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colors.backgroundPrimary,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(
                            _backing ? 'Backing up...' : 'Backup Now',
                          ),
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
                              ? SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: theme.colors.accent,
                                  ),
                                )
                              : const Icon(Icons.cloud_download_outlined),
                          label: Text(
                            _restoring ? 'Restoring...' : 'Restore from Backup',
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Danger zone ──────────────────────
                      _GroupLabel('Danger Zone', theme: theme),
                      const SizedBox(height: 10),

                      OutlinedButton.icon(
                        onPressed: _doDelete,
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Delete Backup'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colors.error,
                          side: BorderSide(
                            color: theme.colors.error.withOpacity(0.3),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Info ─────────────────────────────
                      _GroupLabel('About', theme: theme),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colors.surfacePrimary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _InfoRow(
                              'Backed up',
                              _status?.logsCount.toString() ?? '—',
                              'meal logs',
                              theme: theme,
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(
                              'Last backup',
                              _status?.lastBackupText ?? '—',
                              '',
                              theme: theme,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Backup includes: meal logs, streak data, and profile settings. Favorites sync locally on your device.',
                              style: TextStyle(
                                color: theme.colors.textSecondary,
                                fontSize: 12,
                              ),
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
    final theme = ThemeManager.instance.activeTheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colors.surfacePrimary,
        title: Text(
          'Restore from Backup?',
          style: TextStyle(color: theme.colors.textPrimary),
        ),
        content: Text(
          'This will merge backed-up meals into your current device.',
          style: TextStyle(color: theme.colors.textSecondary),
        ),
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

    final count = await BackupService().restoreAll();

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
    final theme = ThemeManager.instance.activeTheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colors.surfacePrimary,
        title: Text(
          'Delete Backup?',
          style: TextStyle(color: theme.colors.error),
        ),
        content: Text(
          'This permanently deletes your cloud backup. You can still backup again anytime.',
          style: TextStyle(color: theme.colors.textSecondary),
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colors.error,
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
      setState(
        () => _message = ok ? 'Backup deleted.' : 'Failed to delete backup.',
      );
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
  final dynamic theme;
  const _StatusCard({required this.status, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colors.surfacePrimary,
        borderRadius: BorderRadius.circular(16),
        border: status.hasBackup
            ? Border.all(
                color: theme.colors.success.withOpacity(0.4),
                width: 1.5,
              )
            : null,
      ),
      child: Row(
        children: [
          Icon(
            status.hasBackup
                ? Icons.check_circle_rounded
                : Icons.cloud_off_rounded,
            color: status.hasBackup
                ? theme.colors.success
                : theme.colors.textSecondary,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.hasBackup ? 'Backup exists' : 'No backup yet',
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status.lastBackupText,
                  style: TextStyle(
                    color: theme.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
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
  final dynamic theme;

  const _InfoRow(this.label, this.value, this.unit, {required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.colors.textSecondary, fontSize: 12),
        ),
        Text(
          '$value $unit',
          style: TextStyle(
            color: theme.colors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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

// Import for login screen reference
// In real file: import '../../auth/screens/login_screen.dart';
// For now, placeholder — wire the actual import
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('Navigate to LoginScreen')));
}
