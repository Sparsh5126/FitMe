import 'dart:developer' as dev;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:fitme/core/theme/app_theme.dart';
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Menu',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 20),

              // ── User greeting ─────────────────────
              profileAsync.when(
                loading: () => const SizedBox(
                  height: 76,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                ),
                error: (_, __) => _buildLoginTile(context),
                data: (p) => p != null
                    ? _buildUserCard(context, ref, p.name)
                    : _buildLoginTile(context),
              ),

              const SizedBox(height: 24),

              // ── Settings ──────────────────────────
              const _GroupLabel('Preferences'),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.tune_rounded,
                label: 'Settings',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
              ),

              const SizedBox(height: 20),

              // ── Connect health apps ───────────────
              const _GroupLabel('Connected Apps'),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.monitor_heart_rounded,
                label: 'Health & Activity',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IntegrationsScreen()),
                ),
              ),

              const SizedBox(height: 20),

              // ── Features ──────────────────────────
              const _GroupLabel('Features'),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.storefront_rounded,
                label: 'Store',
                trailing: _ComingSoonBadge(),
                onTap: () {},
              ),
              _MenuTile(
                icon: Icons.people_rounded,
                label: 'Challenge a Friend',
                trailing: _ComingSoonBadge(),
                onTap: () {},
              ),

              const SizedBox(height: 20),

              // ── Help & Feedback ───────────────────
              const _GroupLabel('Help & Feedback'),
              const SizedBox(height: 10),
              _MenuTile(
                icon: Icons.code_rounded,
                label: 'GitHub',
                onTap: () => _launchUrl('https://github.com/Sparsh5126/FitMe'),
              ),
              _MenuTile(
                icon: Icons.star_rounded,
                label: 'Rate on Play Store',
                onTap: () => _launchUrl(
                  'https://play.google.com/store/apps/details?id=com.sparsh.fitme',
                ),
              ),
              _MenuTile(
                icon: Icons.bug_report_rounded,
                label: 'Report a Bug',
                onTap: () => _launchUrl(
                  'https://github.com/Sparsh5126/FitMe/issues/new',
                ),
              ),

              const SizedBox(height: 20),

              // ── Subscription ──────────────────────
              const _GroupLabel('Premium'),
              const SizedBox(height: 10),
              const _SubscriptionTile(),

              const SizedBox(height: 40),

              // ── App version ───────────────────────
              const Center(
                child: Text(
                  'FitMe v1.0.0',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
  Widget _buildUserCard(BuildContext context, WidgetRef ref, String name) {
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
              style: const TextStyle(
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
                const Text(
                  'Anonymous Account',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          // ── Sign-out button ──────────────────────
          GestureDetector(
            onTap: () => _confirmSignOut(context, ref),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                Icons.logout_rounded,
                color: AppTheme.textSecondary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTile(BuildContext context) {
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
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Sign out?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You will be returned to the login screen.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
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
  const _GroupLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
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

  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accent, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            trailing ??
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                  size: 20,
                ),
          ],
        ),
      ),
    );
  }
}

class _ComingSoonBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Soon',
        style: TextStyle(
          color: AppTheme.accent,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withOpacity(0.8),
            AppTheme.accent.withOpacity(0.3),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'FitMe Pro',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Unlimited AI logging + AI Coach',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Upgrade',
              style: TextStyle(
                color: AppTheme.accent,
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
