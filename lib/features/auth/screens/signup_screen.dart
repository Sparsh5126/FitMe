import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

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
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // ── Back ──────────────────────────────────
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
              ),

              const SizedBox(height: 32),

              // ── Title ─────────────────────────────────
              const Text('Create\naccount 💪',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 32,
                      height: 1.2)),
              const SizedBox(height: 8),
              const Text('Your data syncs across all your devices.',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),

              const SizedBox(height: 40),

              // ── Error banner ──────────────────────────
              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Text(_error!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13)),
                ),
                const SizedBox(height: 16),
              ],

              // ── Name ──────────────────────────────────
              _label('Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Your name',
                    icon: Icons.person_outline_rounded),
              ),

              const SizedBox(height: 16),

              // ── Email ─────────────────────────────────
              _label('Email'),
              const SizedBox(height: 8),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('you@example.com',
                    icon: Icons.email_outlined),
              ),

              const SizedBox(height: 16),

              // ── Password ──────────────────────────────
              _label('Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _passCtrl,
                obscureText: _obscurePass,
                textInputAction: TextInputAction.next,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Min. 6 characters',
                    icon: Icons.lock_outline_rounded,
                    suffix: _visibilityBtn(
                      obscure: _obscurePass,
                      onTap: () => setState(() => _obscurePass = !_obscurePass),
                    )),
              ),

              const SizedBox(height: 16),

              // ── Confirm password ──────────────────────
              _label('Confirm Password'),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _signUp(),
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Re-enter password',
                    icon: Icons.lock_outline_rounded,
                    suffix: _visibilityBtn(
                      obscure: _obscureConfirm,
                      onTap: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    )),
              ),

              const SizedBox(height: 28),

              // ── Sign up button ────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signUp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.background),
                        )
                      : const Text('Create Account',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 16),

              // ── Divider ───────────────────────────────
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text('or',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ),
                  Expanded(child: Divider(color: Colors.white.withOpacity(0.1))),
                ],
              ),

              const SizedBox(height: 16),

              // ── Google ────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _signInGoogle,
                  icon: const Text('G',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  label: const Text('Continue with Google'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Login link ────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: RichText(
                    text: const TextSpan(
                      text: 'Already have an account? ',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                      children: [
                        TextSpan(
                          text: 'Sign In',
                          style: TextStyle(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
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

    setState(() { _loading = true; _error = null; });
    HapticFeedback.mediumImpact();

    final result = await ref
        .read(authNotifierProvider.notifier)
        .signUpWithEmail(name: name, email: email, password: pass);

    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context);
    } else {
      setState(() { _error = result.error; _loading = false; });
    }
  }

  Future<void> _signInGoogle() async {
    setState(() { _loading = true; _error = null; });
    HapticFeedback.mediumImpact();
    final result =
        await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    if (result.isSuccess) {
      Navigator.pop(context);
    } else {
      setState(() { _error = result.error; _loading = false; });
    }
  }

  // ── Helpers ───────────────────────────────────────────
  Widget _label(String text) => Text(text,
      style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500));

  Widget _visibilityBtn({required bool obscure, required VoidCallback onTap}) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: AppTheme.textSecondary,
        size: 20,
      ),
      onPressed: onTap,
    );
  }

  InputDecoration _inputDecoration(String hint,
      {required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: AppTheme.textSecondary, size: 18),
      suffixIcon: suffix,
    );
  }
}