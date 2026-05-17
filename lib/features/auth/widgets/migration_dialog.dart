import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/nutrition/services/migration_service.dart';

class MigrationDialog extends ConsumerStatefulWidget {
  final Widget child;
  const MigrationDialog({super.key, required this.child});

  @override
  ConsumerState<MigrationDialog> createState() => _MigrationDialogState();
}

class _MigrationDialogState extends ConsumerState<MigrationDialog> {
  bool _isProcessing = false;

  Future<void> _handleMerge() async {
    final user = ref.read(authNotifierProvider).value;
    if (user == null) return;

    setState(() => _isProcessing = true);
    try {
      await MigrationService.performMerge(user.uid);
      ref.read(pendingMigrationProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guest data successfully merged!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Migration failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleKeepAccount() async {
    setState(() => _isProcessing = true);
    await MigrationService.discardGuestData();
    ref.read(pendingMigrationProvider.notifier).state = false;
    if (mounted) setState(() => _isProcessing = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    final isPending = ref.watch(pendingMigrationProvider);

    if (!isPending) return widget.child;

    return Stack(
      children: [
        widget.child,
        Container(
          color: Colors.black54,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colors.surfacePrimary,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colors.accent.withOpacity(0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.merge_type_rounded,
                    size: 48,
                    color: theme.colors.accent,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Guest Data Found',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Do you want to merge your guest meals, recipes, favorites, and FitPoints into this account?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_isProcessing)
                    CircularProgressIndicator(color: theme.colors.accent)
                  else ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _handleMerge,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colors.accent,
                          foregroundColor: theme.colors.backgroundPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Merge Guest Data',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colors.backgroundPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _handleKeepAccount,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: theme.colors.textSecondary),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Keep Account Data Only',
                          style: TextStyle(color: theme.colors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          ref.read(pendingMigrationProvider.notifier).state =
                              false,
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: theme.colors.textSecondary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
