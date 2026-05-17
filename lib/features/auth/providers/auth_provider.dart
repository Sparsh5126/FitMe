import 'dart:developer' as dev;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/features/auth/services/auth_service.dart';
import 'package:fitme/features/auth/services/auth_session_cleanup_service.dart';
import 'package:fitme/features/dashboard/providers/user_provider.dart';
import 'package:fitme/features/nutrition/providers/nutrition_provider.dart';
import 'package:fitme/features/insights/screens/insights_screen.dart';
import 'package:fitme/features/integrations/providers/health_provider.dart';
import 'package:fitme/features/fitpoints/providers/fitpoints_provider.dart';

// ── Auth state ───────────────────────────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  dev.log('[AuthProvider] Subscribing to authStateChanges', name: 'Auth');
  return AuthService().authStateChanges;
});

// ── Guest mode state ──────────────────────────────────
class IsGuestNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final isGuestProvider = NotifierProvider<IsGuestNotifier, bool>(
  IsGuestNotifier.new,
);

// ── Migration state ───────────────────────────────────
class PendingMigrationNotifier extends Notifier<bool> {
  @override
  bool build() => false;
}

final pendingMigrationProvider =
    NotifierProvider<PendingMigrationNotifier, bool>(
      PendingMigrationNotifier.new,
    );

// ── Auth notifier ─────────────────────────────────────
final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, User?>(
  AuthNotifier.new,
);

class AuthNotifier extends AsyncNotifier<User?> {
  AuthService get _service => AuthService();

  @override
  Future<User?> build() async {
    dev.log('[AuthNotifier] build() — checking current session', name: 'Auth');
    final valid = await _service.validateCurrentSession();
    final user = valid ? _service.currentUser : null;

    // Check if we should be in guest mode
    final guestMode = await _service.isGuestMode();
    if (user == null && guestMode) {
      dev.log('[AuthNotifier] build() restoring guest session', name: 'Auth');
      ref.read(isGuestProvider.notifier).state = true;
    }

    dev.log(
      '[AuthNotifier] build() resolved user: ${user?.uid ?? (guestMode ? 'Guest' : 'null')}',
      name: 'Auth',
    );

    if (user != null) {
      await _checkMigration();
    }

    return user;
  }

  // ── Guest Mode ──────────────────────────────────────
  Future<void> continueAsGuest() async {
    dev.log('[AuthNotifier] continueAsGuest()', name: 'Auth');
    debugPrint('[Auth] Switching to guest mode');
    await _service.setGuestMode(true);
    ref.read(isGuestProvider.notifier).state = true;
    debugPrint('[Auth] Guest mode enabled, invalidating user data providers');
    _invalidateUserProviders();
    state = const AsyncValue.data(null);
  }

  // ── Migration Detection ──────────────────────────────
  Future<void> _checkMigration() async {
    if (await _service.hasGuestData()) {
      dev.log('[AuthNotifier] Flagging pending migration', name: 'Auth');
      ref.read(pendingMigrationProvider.notifier).state = true;
    }
  }

  // ── Google sign-in ──────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    dev.log('[AuthNotifier] signInWithGoogle()', name: 'Auth');
    debugPrint('[Auth] Google sign-in started');
    state = const AsyncValue.loading();
    final result = await _service.signInWithGoogle();
    if (result.success) {
      debugPrint(
        '[Auth] Google sign-in success, switching from guest/null to account',
      );
      await _service.setGuestMode(false);
      ref.read(isGuestProvider.notifier).state = false;
      debugPrint('[Auth] Invalidating providers for account switch');
      _invalidateUserProviders();
      await _checkMigration();
      state = AsyncValue.data(_service.currentUser);
      dev.log('[AuthNotifier] Google sign-in success', name: 'Auth');
    } else {
      state = const AsyncValue.data(null);
      dev.log(
        '[AuthNotifier] Google sign-in failed: ${result.errorMessage}',
        name: 'Auth',
      );
    }
    return result;
  }

  // ── Email sign-in ────────────────────────────────────
  Future<AuthResult> signInWithEmail(String email, String password) async {
    dev.log('[AuthNotifier] signInWithEmail()', name: 'Auth');
    debugPrint('[Auth] Email sign-in started');
    state = const AsyncValue.loading();
    final result = await _service.signInWithEmail(email, password);
    if (result.success) {
      debugPrint(
        '[Auth] Email sign-in success, switching from guest/null to account',
      );
      await _service.setGuestMode(false);
      ref.read(isGuestProvider.notifier).state = false;
      debugPrint('[Auth] Invalidating providers for account switch');
      _invalidateUserProviders();
      await _checkMigration();
      state = AsyncValue.data(_service.currentUser);
    } else {
      state = const AsyncValue.data(null);
    }
    return result;
  }

  // ── Register ─────────────────────────────────────────
  Future<AuthResult> registerWithEmail(
    String email,
    String password,
    String name,
  ) async {
    dev.log('[AuthNotifier] registerWithEmail()', name: 'Auth');
    debugPrint('[Auth] Email registration started');
    state = const AsyncValue.loading();
    final result = await _service.registerWithEmail(email, password, name);
    if (result.success) {
      debugPrint(
        '[Auth] Email registration success, switching from guest/null to account',
      );
      await _service.setGuestMode(false);
      ref.read(isGuestProvider.notifier).state = false;
      debugPrint('[Auth] Invalidating providers for account switch');
      _invalidateUserProviders();
      await _checkMigration();
      state = AsyncValue.data(_service.currentUser);
    } else {
      state = const AsyncValue.data(null);
    }
    return result;
  }

  // ── Password Reset ──────────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    dev.log('[AuthNotifier] sendPasswordReset()', name: 'Auth');
    return await _service.sendPasswordReset(email);
  }

  // ── Sign out ─────────────────────────────────────────
  Future<void> signOut() async {
    dev.log('[AuthNotifier] signOut() — starting full sign-out', name: 'Auth');
    state = const AsyncValue.loading();

    // 1. Clear account-specific local caches (Smart Logger history, oil preferences, etc.)
    await AuthSessionCleanupService.clear();

    // 2. Perform Firebase sign-out
    await _service.signOut();

    // 3. Clear guest mode flags
    ref.read(isGuestProvider.notifier).state = false;

    // 4. Invalidate all user-scoped Riverpod providers
    _invalidateUserProviders();

    state = const AsyncValue.data(null);
    dev.log('[AuthNotifier] signOut() complete', name: 'Auth');
  }

  // ── Invalidate all user-scoped providers ─────────────
  void _invalidateUserProviders() {
    dev.log('[AuthNotifier] Invalidating user-scoped providers', name: 'Auth');
    debugPrint(
      '[Auth] Invalidating all user-scoped providers (logout/guest-switch)',
    );
    try {
      ref.invalidate(userProfileProvider);
      ref.invalidate(nutritionProvider);
      ref.invalidate(recentsProvider);
      ref.invalidate(favoritesProvider);
      ref.invalidate(customMealsProvider);
      ref.invalidate(insightsDataProvider);
      ref.invalidate(healthConnectNotifier);
      ref.invalidate(consistencySnapshotProvider);
      debugPrint(
        '[Auth] ✓ Cache invalidated: consistency snapshot will rebuild on next access',
      );
      ref.invalidateSelf();
    } catch (e) {
      dev.log('[AuthNotifier] Error invalidating providers: $e', name: 'Auth');
      debugPrint('[Auth] ERROR invalidating providers: $e');
    }
  }
}

// ── Convenience helper used by menu_screen ────────────
// Call this instead of manually navigating — it signs out and
// the AuthGate stream will handle navigation automatically.
Future<void> performSignOut(WidgetRef ref) async {
  dev.log('[Auth] performSignOut() called', name: 'Auth');
  await ref.read(authNotifierProvider.notifier).signOut();

  // Invalidate all known user-data providers so they re-fetch
  // fresh data on next login. Keep this list in sync with the
  // graph's firebase_auth dependents.
  ref.invalidate(authNotifierProvider);
}
