import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'api_service.dart';
import 'auth_provider.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class ContestScreen extends StatefulWidget {
  final int contestId;
  const ContestScreen({super.key, required this.contestId});

  @override
  State<ContestScreen> createState() => _ContestScreenState();
}

class _ContestScreenState extends State<ContestScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  Contest? _contest;
  List<LeaderboardEntry>? _leaderboard;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        ApiService.getContest(widget.contestId),
        ApiService.getLeaderboard(widget.contestId),
      ]);
      if (mounted) {
        setState(() {
          _contest    = results[0] as Contest;
          _leaderboard = results[1] as List<LeaderboardEntry>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _copyJoinCode(BuildContext context, String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Join code "$code" copied!', style: GoogleFonts.inter()),
      backgroundColor: AppTheme.green,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
          body: Center(child: Text(_error!, style: const TextStyle(color: AppTheme.red))));
    }
    if (_contest == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final c = _contest!;
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => context.go('/home'),
        ),
        title: Text(c.title),
        actions: [
          ContestStatusBadge(c.statusLabel),
          const SizedBox(width: 12),
          // Join code chip in app bar
          if (c.joinCode != null)
            GestureDetector(
              onTap: () => _copyJoinCode(context, c.joinCode!),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key_outlined,
                        size: 14, color: AppTheme.accentLight),
                    const SizedBox(width: 6),
                    Text(
                      c.joinCode!,
                      style: GoogleFonts.firaCode(
                          fontSize: 13,
                          color: AppTheme.accentLight,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy_outlined,
                        size: 13, color: AppTheme.accentLight),
                  ],
                ),
              ),
            ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.text2,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle:
              GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Problems'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _ProblemsTab(contest: c, onCopyCode: () => _copyJoinCode(context, c.joinCode ?? '')),
          _LeaderboardTab(entries: _leaderboard, onRefresh: _load),
        ],
      ),
    );
  }
}

// ── Problems Tab ──────────────────────────────────────────────────────────────
class _ProblemsTab extends StatelessWidget {
  final Contest contest;
  final VoidCallback onCopyCode;

  const _ProblemsTab({required this.contest, required this.onCopyCode});

  @override
  Widget build(BuildContext context) {
    final problems = contest.problems;
    if (problems.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_off_outlined, size: 48, color: AppTheme.text2),
            const SizedBox(height: 12),
            Text('No problems in this contest',
                style: GoogleFonts.inter(color: AppTheme.text2)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // ── Contest banner ────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.accent.withOpacity(0.12), AppTheme.bg1],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${problems.length} Problems',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.text0),
                    ),
                    Text(
                      'Total: ${problems.fold(0, (s, p) => s + p.points)} points available',
                      style: GoogleFonts.inter(fontSize: 14, color: AppTheme.accentLight),
                    ),
                    // Join code inside banner
                    if (contest.joinCode != null) ...[
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: onCopyCode,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.key_outlined,
                                size: 14, color: AppTheme.text2),
                            const SizedBox(width: 6),
                            Text('Share code: ',
                                style: GoogleFonts.inter(
                                    fontSize: 12, color: AppTheme.text2)),
                            Text(
                              contest.joinCode!,
                              style: GoogleFonts.firaCode(
                                  fontSize: 13,
                                  color: AppTheme.accentLight,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.copy_outlined,
                                size: 12, color: AppTheme.text2),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Difficulty breakdown
              ...['Easy', 'Medium', 'Hard'].map((d) {
                final count = problems.where((p) => p.difficulty == d).length;
                if (count == 0) return const SizedBox.shrink();
                return Container(
                  margin: const EdgeInsets.only(left: 16),
                  child: Column(
                    children: [
                      Text('$count',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.difficultyColor(d))),
                      Text(d,
                          style: GoogleFonts.inter(
                              fontSize: 11, color: AppTheme.text2)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),

        ...problems.asMap().entries.map((entry) => _ContestProblemRow(
              problem: entry.value,
              index: entry.key,
              contestId: contest.contestId,
            )),
      ],
    );
  }
}

class _ContestProblemRow extends StatefulWidget {
  final Problem problem;
  final int index;
  final int contestId;

  const _ContestProblemRow({
    required this.problem,
    required this.index,
    required this.contestId,
  });

  @override
  State<_ContestProblemRow> createState() => _ContestProblemRowState();
}

class _ContestProblemRowState extends State<_ContestProblemRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p      = widget.problem;
    final letter = String.fromCharCode(65 + widget.index);

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context
            .go('/problem/${p.problemId}?contest=${widget.contestId}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bg2 : AppTheme.bg1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover ? AppTheme.accent.withOpacity(0.4) : AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    letter,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentLight),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.title,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.text0)),
                    const SizedBox(height: 2),
                    Text(
                      p.description.isNotEmpty
                          ? p.description.split('\n').first
                          : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 12, color: AppTheme.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PointsChip(p.points),
              const SizedBox(width: 10),
              DifficultyBadge(p.difficulty),
              const SizedBox(width: 10),
              Icon(Icons.chevron_right, color: AppTheme.text2, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Leaderboard Tab ───────────────────────────────────────────────────────────
class _LeaderboardTab extends StatelessWidget {
  final List<LeaderboardEntry>? entries;
  final VoidCallback onRefresh;

  const _LeaderboardTab({required this.entries, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    if (entries == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Text('Leaderboard',
                style: Theme.of(context).textTheme.headlineLarge),
            const Spacer(),
            IconButton(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_outlined, color: AppTheme.text2),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.bg2, borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              SizedBox(width: 40, child: _hdr('Rank')),
              Expanded(child: _hdr('User')),
              SizedBox(width: 90, child: _hdr('Solved', center: true)),
              SizedBox(width: 90, child: _hdr('Score', center: true)),
              SizedBox(width: 90, child: _hdr('Time (s)', center: true)),
            ],
          ),
        ),
        const SizedBox(height: 8),

        if (entries!.isEmpty)
          Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Text('No submissions yet',
                  style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 15)),
            ),
          )
        else
          ...entries!.map((e) => _LeaderboardRow(entry: e)),
      ],
    );
  }

  static Widget _hdr(String label, {bool center = false}) =>
      Text(label,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.spaceGrotesk(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text2));
}

class _LeaderboardRow extends StatelessWidget {
  final LeaderboardEntry entry;
  const _LeaderboardRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final rank = entry.rank;
    Color rankColor;
    Widget rankWidget;

    switch (rank) {
      case 1:
        rankColor  = const Color(0xFFFFD700);
        rankWidget = Text('🥇', style: GoogleFonts.spaceGrotesk(fontSize: 18));
      case 2:
        rankColor  = const Color(0xFFC0C0C0);
        rankWidget = Text('🥈', style: GoogleFonts.spaceGrotesk(fontSize: 18));
      case 3:
        rankColor  = const Color(0xFFCD7F32);
        rankWidget = Text('🥉', style: GoogleFonts.spaceGrotesk(fontSize: 18));
      default:
        rankColor  = AppTheme.text2;
        rankWidget = Text('#$rank',
            style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text2));
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: rank <= 3 ? rankColor.withOpacity(0.06) : AppTheme.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: rank <= 3 ? rankColor.withOpacity(0.25) : AppTheme.divider,
        ),
      ),
      child: Row(
        children: [
          SizedBox(width: 40, child: rankWidget),
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 28, height: 28,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      entry.username[0].toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentLight),
                    ),
                  ),
                ),
                Text(entry.username,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.text0)),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Text('${entry.problemsSolved}',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.blue)),
          ),
          SizedBox(
            width: 90,
            child: Text('${entry.totalScore}',
                textAlign: TextAlign.center,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.accent)),
          ),
          SizedBox(
            width: 90,
            child: Text(entry.totalTime.toStringAsFixed(2),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.text2)),
          ),
        ],
      ),
    );
  }
}