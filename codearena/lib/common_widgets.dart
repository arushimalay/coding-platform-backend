import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';

// ── Difficulty Badge ──────────────────────────────────────────────────────────
class DifficultyBadge extends StatelessWidget {
  final String difficulty;
  const DifficultyBadge(this.difficulty, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.difficultyColor(difficulty);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        difficulty,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Status Badge ──────────────────────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        status,
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Contest Status Badge ───────────────────────────────────────────────────────
class ContestStatusBadge extends StatelessWidget {
  final String status;
  const ContestStatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'Live':
        color = AppTheme.green;
      case 'Upcoming':
        color = AppTheme.blue;
      default:
        color = AppTheme.text2;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (status == 'Live')
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.only(right: 5),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 4)],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(
            status,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ── App Logo ──────────────────────────────────────────────────────────────────
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.accent, AppTheme.accentLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(size * 0.3),
          ),
          child: Icon(Icons.code, color: Colors.white, size: size * 0.65),
        ),
        const SizedBox(width: 8),
        Text(
          'CodeArena',
          style: GoogleFonts.spaceGrotesk(
            fontSize: size * 0.75,
            fontWeight: FontWeight.w800,
            color: AppTheme.text0,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

// ── Gradient Button ───────────────────────────────────────────────────────────
class GradientButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final Widget? icon;
  final double? width;

  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.icon,
    this.width,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _hover
                  ? [AppTheme.accentLight, AppTheme.accent]
                  : [AppTheme.accent, const Color(0xFF5B4BD5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: AppTheme.accent.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 8),
              ],
              if (!widget.loading)
                Text(
                  widget.label,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Hollow Button ─────────────────────────────────────────────────────────────
class HollowButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  const HollowButton({super.key, required this.label, this.onPressed, this.icon});

  @override
  State<HollowButton> createState() => _HollowButtonState();
}

class _HollowButtonState extends State<HollowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bg2 : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover ? AppTheme.accent : AppTheme.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _hover ? AppTheme.accent : AppTheme.text1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Glass Card ────────────────────────────────────────────────────────────────
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final bool highlight;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bg1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlight ? AppTheme.accent.withOpacity(0.5) : AppTheme.divider,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── Points chip ───────────────────────────────────────────────────────────────
class PointsChip extends StatelessWidget {
  final int points;
  const PointsChip(this.points, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppTheme.accent.withOpacity(0.25)),
      ),
      child: Text(
        '+$points pts',
        style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppTheme.accentLight,
        ),
      ),
    );
  }
}