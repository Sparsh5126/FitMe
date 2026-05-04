import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Wraps FirebaseAuth. Handles email/password + Google Sign-In.
/// Also creates the Firestore user doc on first login.
///
/// pubspec dep required (if not already present):
///   google_sign_in: ^6.2.1
class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // ── Stream ────────────────────────────────────────────
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  // ── Email / Password ──────────────────────────────────
  Future<AuthResult> signUpWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      await cred.user?.updateDisplayName(name);
      await _ensureUserDoc(cred.user!, displayName: name);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    }
  }

  Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      await _ensureUserDoc(cred.user!);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    }
  }

  // ── Google Sign-In ────────────────────────────────────
  Future<AuthResult> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return AuthResult.failure('Sign-in cancelled.');

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      await _ensureUserDoc(cred.user!);
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    } catch (_) {
      return AuthResult.failure('Google sign-in failed. Try again.');
    }
  }

  // ── Password reset ────────────────────────────────────
  Future<AuthResult> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(_mapError(e.code));
    }
  }

  // ── Sign out ──────────────────────────────────────────
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // ── Ensure Firestore user doc exists ──────────────────
  /// Creates doc only if it doesn't exist — preserves existing data on re-login.
  Future<void> _ensureUserDoc(User user, {String? displayName}) async {
    final ref = _db.collection('users').doc(user.uid);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'uid': user.uid,
        'name': displayName ?? user.displayName ?? 'FitMe User',
        'email': user.email ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        // Personality defaults
        'hiFiveEnabled': true,
        'celebrationsEnabled': true,
        'restMessagesEnabled': true,
        // Notification defaults
        'morningReminderEnabled': true,
        'streakAlertsEnabled': true,
        'rebalancerUpdatesEnabled': false,
        // Smart logger
        'smartLoggerUsedToday': 0,
        'smartLoggerLastResetDate': '',
      });
    }
  }

  // ── Error mapper ──────────────────────────────────────
  String _mapError(String code) => switch (code) {
        'email-already-in-use' => 'An account with this email already exists.',
        'invalid-email' => 'Please enter a valid email address.',
        'weak-password' => 'Password must be at least 6 characters.',
        'user-not-found' => 'No account found with this email.',
        'wrong-password' => 'Incorrect password.',
        'too-many-requests' => 'Too many attempts. Try again later.',
        'network-request-failed' => 'No internet connection.',
        _ => 'Something went wrong. Please try again.',
      };
}

// ── Result type ───────────────────────────────────────
class AuthResult {
  final User? user;
  final String? error;
  bool get isSuccess => error == null;

  const AuthResult._({this.user, this.error});
  factory AuthResult.success(User? user) => AuthResult._(user: user);
  factory AuthResult.failure(String error) => AuthResult._(error: error);
}