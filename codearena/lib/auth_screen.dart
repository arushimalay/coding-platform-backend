import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

// ── Login Screen ──────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to your account',
      child: Column(
        children: [
          _Field(
            ctrl: _emailCtrl,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 14),
          _Field(
            ctrl: _passCtrl,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          ),
          const SizedBox(height: 24),
          Consumer<AuthProvider>(
            builder: (ctx, auth, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.error != null)
                  _ErrorBanner(auth.error!),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Sign In',
                  loading: auth.loading,
                  onPressed: _submit,
                  width: double.infinity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Don't have an account? ",
                  style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 14)),
              GestureDetector(
                onTap: () => context.go('/register'),
                child: Text(
                  'Sign up',
                  style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Register Screen ───────────────────────────────────────────────────────────
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final auth = context.read<AuthProvider>();
    final ok = await auth.register(
      _usernameCtrl.text.trim(),
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    if (ok && mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return _AuthScaffold(
      title: 'Create account',
      subtitle: 'Join the arena — start competing',
      child: Column(
        children: [
          _Field(
            ctrl: _usernameCtrl,
            label: 'Username',
            hint: 'hackerman_99',
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _Field(
            ctrl: _emailCtrl,
            label: 'Email',
            hint: 'you@example.com',
            icon: Icons.alternate_email,
          ),
          const SizedBox(height: 14),
          _Field(
            ctrl: _passCtrl,
            label: 'Password',
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscure,
            onToggleObscure: () => setState(() => _obscure = !_obscure),
          ),
          const SizedBox(height: 24),
          Consumer<AuthProvider>(
            builder: (ctx, auth, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (auth.error != null) _ErrorBanner(auth.error!),
                const SizedBox(height: 8),
                GradientButton(
                  label: 'Create Account',
                  loading: auth.loading,
                  onPressed: _submit,
                  width: double.infinity,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Already have an account? ",
                  style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 14)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text(
                  'Sign in',
                  style: GoogleFonts.inter(
                    color: AppTheme.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Shared Widgets ────────────────────────────────────────────────────────────
class _AuthScaffold extends StatelessWidget {
  final String title, subtitle;
  final Widget child;

  const _AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: Stack(
        children: [
          // Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [AppTheme.accent.withOpacity(0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: const AppLogo(size: 28),
                    ),
                    const SizedBox(height: 40),
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: AppTheme.bg1,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: Theme.of(context).textTheme.displaySmall),
                          const SizedBox(height: 4),
                          Text(subtitle,
                              style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: 28),
                          child,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label, hint;
  final IconData icon;
  final bool obscure;
  final VoidCallback? onToggleObscure;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.onToggleObscure,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.text1,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          obscureText: obscure,
          style: GoogleFonts.inter(color: AppTheme.text0, fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.text2, size: 18),
            suffixIcon: onToggleObscure != null
                ? IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.text2,
                      size: 18,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}