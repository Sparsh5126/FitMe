import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fitme/core/theme/app_theme.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:fitme/features/integrations/screens/integrations_screen.dart';
import 'package:fitme/features/auth/screens/login_screen.dart';
import 'package:fitme/features/menu/screens/settings_screen.dart';

Future<void> _launchUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    dev.log('[MenuScreen] Could not launch $url', name: 'Nav');
  }
}

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final theme = ThemeManager.instance.activeTheme;

    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Menu',
                style: TextStyle(
                  color: theme.colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 20),

              // ── User greeting ─────────────────────
              profileAsync.when(
                loading: () => SizedBox(
                  height: 76,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colors.accent,
                      ),
                    ),
                  ),
                ),
                error: (_, __) => _buildLoginTile(context, theme),
                data: (p) => p != null
                    ? _buildUserCard(context, ref, p.name, theme)
                    : _buildLoginTile(context, theme),
              ),

              const SizedBox(height: 24),

              // ── Settings ──────────────────────────
              _GroupLabel('Preferences', theme: theme),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                theme: theme,
              ),

              const SizedBox(height: 20),

              // ── Connect health apps ───────────────
              _GroupLabel('Connected Apps', theme: theme),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.monitor_heart_rounded,
                label: 'Health & Activity',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IntegrationsScreen()),
                ),
                theme: theme,
              ),

              const SizedBox(height: 20),

              // ── Features ──────────────────────────
              _GroupLabel('Features', theme: theme),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.storefront_rounded,
                label: 'Store',
                trailing: _ComingSoonBadge(theme: theme),
                onTap: () {},
                theme: theme,
              ),
              _MenuTile(
                icon: Icons.people_rounded,
                label: 'Challenge a Friend',
                trailing: _ComingSoonBadge(theme: theme),
                onTap: () {},
                theme: theme,
              ),

              const SizedBox(height: 20),

              // ── Help & Feedback ───────────────────
              _GroupLabel('Help & Feedback', theme: theme),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.code_rounded,
                label: 'GitHub',
                onTap: () => _launchUrl('https://github.com/Sparsh5126/FitMe'),
                theme: theme,
              ),
              _MenuTile(
                icon: Icons.star_rounded,
                label: 'Rate on Play Store',
                onTap: () => _launchUrl(
                  'https://play.google.com/store/apps/details?id=com.sparsh.fitme',
                ),
                theme: theme,
              ),
              _MenuTile(
                icon: Icons.bug_report_rounded,
                label: 'Report a Bug',
                onTap: () => _launchUrl(
                  'https://github.com/Sparsh5126/FitMe/issues/new',
                ),
                theme: theme,
              ),

              const SizedBox(height: 20),

              // ── Subscription ──────────────────────
              _GroupLabel('Premium', theme: theme),
              const SizedBox(height: 10),
              _SubscriptionTile(theme: theme),

              const SizedBox(height: 40),

              // ── App version ───────────────────────
              Center(
                child: Text(
                  'FitMe v1.0.0',
                  style: TextStyle(
                    color: theme.colors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // ── User card with sign-out ──────────────────────────
  Widget _buildUserCard(
    BuildContext context,
    WidgetRef ref,
    String name,
    dynamic theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                color: AppTheme.accent,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Anonymous Account',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // ── Sign-out button ──────────────────────
          GestureDetector(
            onTap: () => _confirmSignOut(context, ref, theme),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.logout_rounded,
                color: theme.colors.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTile(BuildContext context, dynamic theme) {
    // AuthGate handles routing — tapping this is a manual shortcut only.
    // In practice, if profile is null the user is unauthenticated and
    // AuthGate will have already routed them to LoginScreen.
    return _MenuTile(
      icon: Icons.login_rounded,
      label: 'Sign In / Create Account',
      onTap: () {
        dev.log('[MenuScreen] Manual login tile tapped', name: 'Nav');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      theme: theme,
    );
  }

  Future<void> _confirmSignOut(
    BuildContext context,
    WidgetRef ref,
    dynamic theme,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.colors.surfacePrimary,
        title: Text(
          'Sign out?',
          style: TextStyle(color: theme.colors.textPrimary),
        ),
        content: Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: theme.colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: theme.colors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Sign out',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    dev.log('[MenuScreen] Sign-out confirmed', name: 'Nav');

    // performSignOut clears Firebase, Google, SharedPreferences, and all
    // Riverpod providers. AuthGate's StreamProvider will emit null and
    // rebuild to LoginScreen automatically — no Navigator call needed.
    await performSignOut(ref);

    dev.log(
      '[MenuScreen] performSignOut complete — AuthGate will navigate',
      name: 'Nav',
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────

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

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;
  final dynamic theme;

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colors.surfacePrimary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: theme.colors.accent, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: theme.colors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colors.textSecondary,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  final dynamic theme;

  const _ComingSoonBadge({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
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
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  final dynamic theme;

  const _SubscriptionTile({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colors.accent.withOpacity(0.8),
            theme.colors.accent.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Text('⭐', style: TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FitMe Pro',
                  style: TextStyle(
                    color: theme.colors.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unlimited AI logging + AI Coach',
                  style: TextStyle(
                    color: theme.colors.textPrimary.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Upgrade',
              style: TextStyle(
                color: theme.colors.accent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
