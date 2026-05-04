import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';

// ── Raw Firebase auth state stream ───────────────────
final authStateProvider = StreamProvider<User?>((ref) {
  return AuthService().authStateChanges;
});

// ── Convenience: is logged in ─────────────────────────
final isLoggedInProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).value != null;
});

// ── Current user ──────────────────────────────────────
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

// ── Auth notifier: sign in / up / out actions ─────────
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, void>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<AuthResult> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await AuthService().signUpWithEmail(
        name: name, email: email, password: password);
    state = const AsyncValue.data(null);
    if (result.isSuccess) _invalidateUserData();
    return result;
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    final result = await AuthService()
        .signInWithEmail(email: email, password: password);
    state = const AsyncValue.data(null);
    if (result.isSuccess) _invalidateUserData();
    return result;
  }

  Future<AuthResult> signInWithGoogle() async {
    state = const AsyncValue.loading();
    final result = await AuthService().signInWithGoogle();
    state = const AsyncValue.data(null);
    if (result.isSuccess) _invalidateUserData();
    return result;
  }

  Future<AuthResult> sendPasswordReset(String email) async {
    return AuthService().sendPasswordReset(email);
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await AuthService().signOut();
    state = const AsyncValue.data(null);
    _invalidateUserData();
  }

  // Bust userProfileProvider so UI re-fetches after login/logout
  void _invalidateUserData() {
    ref.invalidate(authStateProvider);
  }
}