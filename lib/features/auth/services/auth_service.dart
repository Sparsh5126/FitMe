import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AuthErrorType { cancelled, networkError, invalidCredential, unknown }

class AuthResult {
  final bool success;
  final String? errorMessage;
  final AuthErrorType? errorType;

  const AuthResult.ok() : success = true, errorMessage = null, errorType = null;
  const AuthResult.fail(this.errorMessage, this.errorType) : success = false;
}

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ── Current user ────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Guest Mode ───────────────────────────────────────
  static const _kGuestKey = 'is_guest_mode';

  Future<bool> isGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kGuestKey) ?? false;
  }

  Future<void> setGuestMode(bool active) async {
    dev.log('[AuthService] Setting guest mode: $active', name: 'Auth');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kGuestKey, active);
  }

  /// Detects if there is data in local storage that doesn't belong to a cloud user.
  /// Checks for existence of common keys like 'nutrition_logs' or 'recipe_favorites'.
  Future<bool> hasGuestData() async {
    final prefs = await SharedPreferences.getInstance();
    // These keys are used by LocalNutritionService and RecipesProvider for local-only storage.
    final hasLogs = prefs.containsKey('nutrition_logs');
    final hasFavs = prefs.containsKey('recipe_favorites');
    final hasHistory = prefs.containsKey('smart_logger_history');
    
    final found = hasLogs || hasFavs || hasHistory;
    if (found) {
      dev.log('[AuthService] Guest data detected (logs:$hasLogs, favs:$hasFavs, history:$hasHistory)', name: 'Auth');
    }
    return found;
  }

  // ── Google Sign-In ───────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    dev.log('[AuthService] Starting Google Sign-In', name: 'Auth');
    try {
      // Disconnect first so account picker always shows (avoids silent re-use
      // of a previously revoked or wrong account).
      await _googleSignIn.signOut();

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        dev.log('[AuthService] Google Sign-In cancelled by user', name: 'Auth');
        return const AuthResult.fail('Sign-in cancelled', AuthErrorType.cancelled);
      }

      dev.log('[AuthService] Got Google account: ${googleUser.email}', name: 'Auth');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCred = await _auth.signInWithCredential(credential);
      dev.log('[AuthService] Firebase sign-in success: ${userCred.user?.uid}', name: 'Auth');

      await _ensureUserDoc(userCred.user!);
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      dev.log('[AuthService] FirebaseAuthException: ${e.code} - ${e.message}', name: 'Auth');
      return AuthResult.fail(_mapError(e), AuthErrorType.invalidCredential);
    } catch (e) {
      dev.log('[AuthService] Unexpected error: $e', name: 'Auth');
      return AuthResult.fail('Unexpected error. Please try again.', AuthErrorType.unknown);
    }
  }

  // ── Email / Password ─────────────────────────────────
  Future<AuthResult> signInWithEmail(String email, String password) async {
    dev.log('[AuthService] Starting email sign-in: $email', name: 'Auth');
    try {
      final userCred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      dev.log('[AuthService] Email sign-in success: ${userCred.user?.uid}', name: 'Auth');
      await _ensureUserDoc(userCred.user!);
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      dev.log('[AuthService] FirebaseAuthException: ${e.code}', name: 'Auth');
      return AuthResult.fail(_mapError(e), AuthErrorType.invalidCredential);
    } catch (e) {
      dev.log('[AuthService] Unexpected error: $e', name: 'Auth');
      return AuthResult.fail('Unexpected error. Please try again.', AuthErrorType.unknown);
    }
  }

  // ── Email Registration ────────────────────────────────
  Future<AuthResult> registerWithEmail(String email, String password, String name) async {
    dev.log('[AuthService] Starting email registration: $email', name: 'Auth');
    try {
      final userCred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      dev.log('[AuthService] Registration success: ${userCred.user?.uid}', name: 'Auth');
      
      // Set display name in Firebase Auth
      await userCred.user?.updateDisplayName(name);
      
      await _ensureUserDoc(userCred.user!, displayName: name);
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      dev.log('[AuthService] FirebaseAuthException: ${e.code}', name: 'Auth');
      return AuthResult.fail(_mapError(e), AuthErrorType.invalidCredential);
    } catch (e) {
      dev.log('[AuthService] Unexpected error: $e', name: 'Auth');
      return AuthResult.fail('Unexpected error. Please try again.', AuthErrorType.unknown);
    }
  }

  // ── Password Reset ────────────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    dev.log('[AuthService] Sending password reset: $email', name: 'Auth');
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.ok();
    } on FirebaseAuthException catch (e) {
      return AuthResult.fail(_mapError(e), AuthErrorType.invalidCredential);
    } catch (e) {
      return AuthResult.fail('Failed to send reset email.', AuthErrorType.unknown);
    }
  }

  // ── Sign Out ─────────────────────────────────────────
  /// Clears Firebase session, Google account, and all app-level
  /// SharedPreferences keys scoped to the signed-in user.
  Future<void> signOut() async {
    dev.log('[AuthService] Starting sign out', name: 'Auth');
    try {
      // 1. Revoke Google token so it doesn't silently re-authenticate
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect(); // revoke + sign out
        dev.log('[AuthService] Google account disconnected', name: 'Auth');
      }
    } catch (e) {
      // Non-fatal — Google may already be signed out
      dev.log('[AuthService] Google disconnect error (non-fatal): $e', name: 'Auth');
    }

    // 2. Clear app-level persisted data
    await _clearLocalStorage();

    // 3. Sign out from Firebase last — this triggers authStateChanges → null,
    //    which AuthGate will catch to redirect to LoginScreen.
    await _auth.signOut();
    dev.log('[AuthService] Firebase sign out complete', name: 'Auth');
  }

  // ── Validate existing session ─────────────────────────
  /// Returns true only if there is a valid, non-expired Firebase ID token.
  /// Used on app startup to reject stale/legacy sessions.
  Future<bool> validateCurrentSession() async {
    final user = _auth.currentUser;
    if (user == null) {
      dev.log('[AuthService] No current user on startup', name: 'Auth');
      return false;
    }

    try {
      // Force-refresh the token — if the account was deleted or token expired
      // this will throw, and we sign out cleanly.
      await user.getIdToken(true);
      dev.log('[AuthService] Session valid for: ${user.uid}', name: 'Auth');
      return true;
    } catch (e) {
      dev.log('[AuthService] Stale/invalid session detected, signing out: $e', name: 'Auth');
      await signOut();
      return false;
    }
  }

  // ── Helpers ──────────────────────────────────────────
  Future<void> _ensureUserDoc(User user, {String? displayName}) async {
    final ref = _firestore.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': displayName ?? user.displayName ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      dev.log('[AuthService] Created Firestore user doc for ${user.uid}', name: 'Auth');
    }
  }

  Future<void> _clearLocalStorage() async {
    dev.log('[AuthService] Clearing SharedPreferences', name: 'Auth');
    try {
      final prefs = await SharedPreferences.getInstance();
      // Clear all keys — providers re-initialise from Firestore after login.
      // If you need to preserve device settings (e.g. theme), remove those
      // keys from this list instead of calling clear().
      await prefs.clear();
      dev.log('[AuthService] SharedPreferences cleared', name: 'Auth');
    } catch (e) {
      dev.log('[AuthService] SharedPreferences clear error: $e', name: 'Auth');
    }
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'email-already-in-use':
        return 'An account already exists for this email.';
      case 'weak-password':
        return 'Password is too weak.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'account-exists-with-different-credential':
        return 'An account exists with a different sign-in method.';
      default:
        return e.message ?? 'Authentication failed.';
    }
  }
}