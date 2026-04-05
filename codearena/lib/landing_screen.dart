import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeIn = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slideUp = Tween(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      body: Stack(
        children: [
          // Ambient glow background
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.blue.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo
                        const AppLogo(size: 36),
                        const SizedBox(height: 48),

                        // Hero text
                        Text(
                          'Compete.\nCode.\nConquer.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 56,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.text0,
                            height: 1.1,
                            letterSpacing: -1.5,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'A competitive coding platform for solving\nchallenges, joining contests, and climbing\nthe leaderboard.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            color: AppTheme.text1,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 40),

                        // CTA Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GradientButton(
                              label: 'Get Started',
                              icon: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                              onPressed: () => context.go('/register'),
                            ),
                            const SizedBox(width: 12),
                            HollowButton(
                              label: 'Sign In',
                              onPressed: () => context.go('/login'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 60),

                        // Stats row
                        _StatsRow(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Stat('3', 'Languages'),
        _divider(),
        _Stat('Easy→Hard', 'Difficulty tiers'),
        _divider(),
        _Stat('Real-time', 'Judging'),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1, height: 28, color: AppTheme.divider,
        margin: const EdgeInsets.symmetric(horizontal: 20),
      );
}

class _Stat extends StatelessWidget {
  final String value, label;
  const _Stat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.accent,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.text2),
        ),
      ],
    );
  }
}