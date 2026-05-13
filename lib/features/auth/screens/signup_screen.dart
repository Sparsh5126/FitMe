import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitme/core/theme/app_theme.dart';
import 'package:fitme/core/theme/managers/theme_manager.dart';
import 'package:fitme/features/auth/providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
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
                'Create\naccount 💪',
                style: TextStyle(
                  color: theme.colors.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: theme.typography.headlineLargeSize,
                  height: 1.2,
                ),
              ),
              SizedBox(height: theme.spacing.sm),
              Text(
                'Your data syncs across all your devices.',
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

              // ── Name ──────────────────────────────────
              _label('Name', theme),
              SizedBox(height: theme.spacing.sm),
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: theme.colors.textPrimary),
                decoration: _inputDecoration(
                  'Your name',
                  icon: Icons.person_outline_rounded,
                  theme: theme,
                ),
              ),

              SizedBox(height: theme.spacing.md),

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
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                style: TextStyle(color: theme.colors.textPrimary),
                decoration: _inputDecoration(
                  'Min. 6 characters',
                  icon: Icons.lock_outline_rounded,
                  theme: theme,
                  suffix: _visibilityBtn(
                    obscure: _obscurePass,
                    onTap: () => setState(() => _obscurePass = !_obscurePass),
                    theme: theme,
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.md),

              // ── Confirm password ──────────────────────
              _label('Confirm Password', theme),
              SizedBox(height: theme.spacing.sm),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signUp(),
                style: TextStyle(color: theme.colors.textPrimary),
                decoration: _inputDecoration(
                  'Re-enter password',
                  icon: Icons.lock_outline_rounded,
                  theme: theme,
                  suffix: _visibilityBtn(
                    obscure: _obscureConfirm,
                    onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    theme: theme,
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.lg),

              // ── Sign up button ────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signUp,
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
                          'Create Account',
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
                    child: Divider(color: theme.colors.textPrimary.withOpacity(0.1)),
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
                    child: Divider(color: theme.colors.textPrimary.withOpacity(0.1)),
                  ),
                ],
              ),

              SizedBox(height: theme.spacing.md),

              // ── Google ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInGoogle,
                  icon: Text(
                    'G',
                    style: TextStyle(
                      color: theme.colors.textPrimary,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  label: Text(
                    'Continue with Google',
                    style: TextStyle(color: theme.colors.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: theme.spacing.md),
                    side: BorderSide(color: theme.colors.textPrimary.withOpacity(0.2)),
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.xl),

              // ── Login link ────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(
                        color: theme.colors.textSecondary,
                        fontSize: theme.typography.bodySmallSize,
                      ),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                            color: theme.colors.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(height: theme.spacing.md),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────
  Future<void> _signUp() async {
    FocusScope.of(context).unfocus();

    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Please fill in all fields.');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    HapticFeedback.mediumImpact();

    final result = await ref
        .read(authNotifierProvider.notifier)
        .registerWithEmail(email, pass, name);

    if (!mounted) return;
    if (result.success) {
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else {
      setState(() {
        _error = result.errorMessage;
        _loading = false;
      });
    }
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

  Widget _visibilityBtn({
    required bool obscure,
    required VoidCallback onTap,
    required dynamic theme,
  }) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: theme.colors.textSecondary,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

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
