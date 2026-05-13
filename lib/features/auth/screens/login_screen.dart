import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/app_theme.dart';
import 'package:fitme/core/theme/providers/theme_provider.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';
import 'package:fitme/features/auth/screens/signup_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeManager.instance.activeTheme;
    
    return Scaffold(
      backgroundColor: theme.colors.backgroundPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.all(theme.spacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: theme.spacing.md),

              // ── Back ──────────────────────────────────
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: theme.colors.textPrimary),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),

              SizedBox(height: theme.spacing.xl),

              // ── Title ─────────────────────────────────
              Text(
                'Welcome\nback 👋',
                style: TextStyle(
                  color: theme.colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: theme.typography.headlineLargeSize,
                  height: 1.2,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                'Sign in to sync your data across devices.',
                style: TextStyle(
                  color: theme.colors.textSecondary,
                  fontSize: theme.typography.bodyMediumSize,
                ),
              ),

              SizedBox(height: theme.spacing.xl),

              // ── Error banner ──────────────────────────
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(theme.spacing.md),
                  decoration: BoxDecoration(
                    color: theme.colors.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(theme.radius.md),
                    border: Border.all(color: theme.colors.error.withOpacity(0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: theme.colors.error,
                      fontSize: theme.typography.bodySmallSize,
                    ),
                  ),
                ),
                SizedBox(height: theme.spacing.md),
              ],

              // ── Email ─────────────────────────────────
              _label('Email', theme),
              SizedBox(height: theme.spacing.sm),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                style: TextStyle(color: theme.colors.textPrimary),
                decoration: _inputDecoration(
                  'you@example.com',
                  icon: Icons.email_outlined,
                  theme: theme,
                ),
              ),

              SizedBox(height: theme.spacing.md),

              // ── Password ──────────────────────────────
              _label('Password', theme),
              SizedBox(height: theme.spacing.sm),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signIn(),
                style: TextStyle(color: theme.colors.textPrimary),
                decoration: _inputDecoration(
                  '••••••••',
                  icon: Icons.lock_outline_rounded,
                  theme: theme,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      color: theme.colors.textSecondary,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.sm),

              // ── Forgot password ───────────────────────
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _forgotPassword,
                  child: Text(
                    'Forgot password?',
                    style: TextStyle(
                      color: theme.colors.accent,
                      fontSize: theme.typography.bodySmallSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.lg),

              // ── Sign in button ────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                  ),
                  child: _loading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colors.backgroundPrimary,
                          ),
                        )
                      : Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: theme.typography.bodyMediumSize,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              SizedBox(height: theme.spacing.md),

              // ── Divider ───────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Divider(color: theme.colors.textSecondary.withOpacity(0.15)),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: theme.spacing.md),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: theme.colors.textSecondary,
                        fontSize: theme.typography.bodySmallSize,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: theme.colors.textSecondary.withOpacity(0.15)),
                  ),
                ],
              ),

              SizedBox(height: theme.spacing.md),

              // ── Google sign in ────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInGoogle,
                  icon: Text(
                    'G',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: theme.typography.bodyMediumSize,
                    ),
                  ),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(color: theme.colors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                    side: BorderSide(color: theme.colors.surfaceBorder),
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.sm),

              // ── Guest login ───────────────────────────
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _loading ? null : _signInGuest,
                  child: Text(
                    'Continue as Guest',
                    style: TextStyle(
                      color: theme.colors.textSecondary,
                      fontSize: theme.typography.bodyMediumSize,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ── Sign up link ──────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: TextStyle(
                            color: AppTheme.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────
  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    if (!mounted) return;
    if (result.success) {
      // Do nothing — AuthGate stream will rebuild and route to AppShell.
    } else {
      setState(() {
        _error = result.errorMessage;
        _loading = false;
      });
    }
  }

  Future<void> _signInGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    final result = await ref
        .read(authNotifierProvider.notifier)
        .signInWithGoogle();
    if (!mounted) return;
    if (result.success) {
      // Do nothing — AuthGate stream will rebuild and route to AppShell.
    } else {
      setState(() {
        _error = result.errorMessage;
        _loading = false;
      });
    }
  }

  Future<void> _signInGuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();
    await ref.read(authNotifierProvider.notifier).continueAsGuest();
    // AuthGate will rebuild and route based on isGuestProvider
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Enter your email above first.');
      return;
    }
    final result = await ref
        .read(authNotifierProvider.notifier)
        .sendPasswordReset(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Reset link sent to $email'
              : result.errorMessage ?? 'Failed to send reset email.',
        ),
        backgroundColor: result.success ? AppTheme.success : AppTheme.error,
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────
  Widget _label(String text, dynamic theme) => Text(
    text,
    style: TextStyle(
      color: theme.colors.textSecondary,
      fontSize: theme.typography.bodySmallSize,
      fontWeight: FontWeight.w500,
    ),
  );

  InputDecoration _inputDecoration(
    String hint, {
    required IconData icon,
    required dynamic theme,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.colors.textSecondary),
      prefixIcon: Icon(icon, color: theme.colors.textSecondary, size: 18),
      suffixIcon: suffix,
      filled: true,
      fillColor: theme.colors.surfacePrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(theme.radius.md),
        borderSide: BorderSide(color: theme.colors.accent, width: 1.5),
      ),
    );
  }
}
