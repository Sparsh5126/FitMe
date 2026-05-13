import 'dart:developer' as dev;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitme/core/theme/app_theme.dart';
import 'package:fitme/features/app_shell.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/auth/screens/login_screen.dart';
import 'package:fitme/features/onboarding/onboarding_screen.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:fitme/features/auth/widgets/migration_dialog.dart';
import 'package:fitme/firebase_options.dart';
import 'package:fitme/features/rebalancer/services/rebalancer_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  dev.log('[Main] Firebase initialised', name: 'App');

  runApp(const ProviderScope(child: FitMeApp()));
}

class FitMeApp extends StatelessWidget {
  const FitMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitMe',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      // AuthGate is the single entry point — no named routes needed.
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase auth state via [authStateProvider] (a StreamProvider).
/// Because it wraps a Stream, it reacts instantly to sign-in and sign-out
/// without any polling or manual navigation calls from individual screens.
///
/// Navigation contract:
///   loading  → splash / loading indicator (prevents flash of wrong screen)
///   error    → login (fail-safe)
///   null     → LoginScreen (not authenticated)
///   User     → AppShell or OnboardingScreen depending on profile completion
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    dev.log(
      '[AuthGate] state=${authAsync.runtimeType} '
      'isLoading=${authAsync.isLoading} '
      'value=${authAsync.value?.uid ?? "null"}',
      name: 'Nav',
    );
    final isGuest = ref.watch(isGuestProvider);

    return authAsync.when(
      // ── Still resolving (app cold start) ────────────
      loading: () => const _SplashScreen(),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Auth Error: $err'))),
      data: (user) {
        if (user == null && !isGuest) {
          dev.log(
            '[AuthGate] No user & not Guest — routing to LoginScreen',
            name: 'Nav',
          );
          return const PopScope(canPop: false, child: LoginScreen());
        }

        if (isGuest && user == null) {
          dev.log(
            '[AuthGate] Guest session active — entering AppShell',
            name: 'Nav',
          );
          return const PopScope(canPop: false, child: AppShell());
        }

        dev.log(
          '[AuthGate] Authenticated as ${user?.uid} — routing to ProfileGate',
          name: 'Nav',
        );
        return const ProfileGate();
      },
    );
  }
}

/// Listens to [userProfileProvider] to ensure the user has completed onboarding.
/// If the profile is missing or incomplete (age == 0), routes to OnboardingScreen.
class ProfileGate extends ConsumerWidget {
  const ProfileGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return profileAsync.when(
      loading: () => const _SplashScreen(),
      error: (e, _) {
        dev.log('[ProfileGate] Error loading profile: $e', name: 'Nav');
        return const LoginScreen(); // Fail-safe
      },
      data: (profile) {
        // If profile doesn't exist or age is 0, onboarding is required.
        if (profile == null || profile.age == 0) {
          dev.log(
            '[ProfileGate] Profile incomplete — routing to Onboarding',
            name: 'Nav',
          );
          return const PopScope(
            canPop: false,
            child: MigrationDialog(child: OnboardingScreen()),
          );
        }

        dev.log(
          '[ProfileGate] Profile complete — entering AppShell',
          name: 'Nav',
        );

        // Run rebalancer on startup if due
        RebalancerService.runIfDue();

        return const PopScope(
          canPop: false,
          child: MigrationDialog(child: AppShell()),
        );
      },
    );
  }
}

/// Shown while Firebase resolves the persisted auth token on cold start.
/// Keeps the screen branded and prevents flash of login or app content.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'FitMe',
              style: TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 24),
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
