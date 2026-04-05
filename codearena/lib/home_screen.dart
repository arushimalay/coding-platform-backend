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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  List<Contest>? _contests;
  List<Problem>? _problems;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user!;
    try {
      final results = await Future.wait([
        ApiService.getJoinedContests(user.userId), // only joined contests
        ApiService.getProblems(),
      ]);
      if (mounted) {
        setState(() {
          _contests = results[0] as List<Contest>;
          _problems = results[1] as List<Problem>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthProvider>().user!;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        backgroundColor: AppTheme.bg0,
        title: const AppLogo(size: 24),
        actions: [
          // User chip
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(
                    color: AppTheme.accent, shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      user.username[0].toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(user.username,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text0)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'My Submissions',
            icon: const Icon(Icons.history_outlined, color: AppTheme.text1),
            onPressed: () => context.go('/submissions'),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_outlined, color: AppTheme.text1),
            onPressed: () {
              context.read<AuthProvider>().logout();
              context.go('/');
            },
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.text2,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Contests'),
            Tab(text: 'Problems'),
          ],
        ),
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: AppTheme.red)))
          : TabBarView(
              controller: _tabCtrl,
              children: [
                _ContestsTab(
                  contests: _contests,
                  onRefresh: _load,
                  user: user,
                ),
                _ProblemsTab(problems: _problems, onRefresh: _load, user: user),
              ],
            ),
    );
  }
}

// ── Contests Tab ──────────────────────────────────────────────────────────────
class _ContestsTab extends StatelessWidget {
  final List<Contest>? contests;
  final VoidCallback onRefresh;
  final dynamic user;

  const _ContestsTab({
    required this.contests,
    required this.onRefresh,
    required this.user,
  });

  void _showJoinDialog(BuildContext context) {
    final ctrl = TextEditingController();
    bool joining = false;
    String? err;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AppTheme.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Join Contest',
              style: GoogleFonts.spaceGrotesk(
                  fontWeight: FontWeight.w700, color: AppTheme.text0)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enter the join code shared by the contest organiser.',
                  style: GoogleFonts.inter(fontSize: 13, color: AppTheme.text2),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  style: GoogleFonts.firaCode(color: AppTheme.text0, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'swift-tiger-42',
                    hintStyle: GoogleFonts.firaCode(color: AppTheme.text2, fontSize: 15),
                    prefixIcon: const Icon(Icons.key_outlined,
                        size: 18, color: AppTheme.text2),
                  ),
                ),
                if (err != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.error_outline, color: AppTheme.red, size: 14),
                      const SizedBox(width: 6),
                      Expanded(child: Text(err!,
                          style: GoogleFonts.inter(color: AppTheme.red, fontSize: 12))),
                    ]),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel',
                  style: GoogleFonts.spaceGrotesk(color: AppTheme.text2)),
            ),
            GradientButton(
              label: joining ? '' : 'Join',
              loading: joining,
              onPressed: joining
                  ? null
                  : () async {
                      final code = ctrl.text.trim();
                      if (code.isEmpty) return;
                      setS(() { joining = true; err = null; });
                      try {
                        final res = await ApiService.joinContest(
                          userId: user.userId,
                          joinCode: code,
                        );
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          onRefresh();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(res['message'] ?? 'Joined!',
                                style: GoogleFonts.inter()),
                            backgroundColor: AppTheme.green,
                            behavior: SnackBarBehavior.floating,
                          ));
                          context.go('/contest/${res['contest_id']}');
                        }
                      } catch (e) {
                        setS(() {
                          joining = false;
                          err = e.toString().replaceAll('Exception: ', '');
                        });
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Contests',
                          style: Theme.of(context).textTheme.headlineLarge),
                      Text('Contests you have joined',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                // Join contest button
                HollowButton(
                  label: 'Join via Code',
                  icon: const Icon(Icons.key_outlined,
                      size: 16, color: AppTheme.accent),
                  onPressed: () => _showJoinDialog(context),
                ),
                const SizedBox(width: 10),
                GradientButton(
                  label: 'Create Contest',
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  onPressed: () => context.go('/create-contest'),
                ),
              ],
            ),
          ),
        ),
        if (contests == null)
          const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()))
        else if (contests!.isEmpty)
          SliverFillRemaining(
            child: _EmptyState(
              label: 'No contests yet',
              subtitle: 'Create one or join with a code',
              icon: Icons.emoji_events_outlined,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 420,
                mainAxisExtent: 180,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ContestCard(contest: contests![i]),
                childCount: contests!.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ContestCard extends StatefulWidget {
  final Contest contest;
  const _ContestCard({required this.contest});

  @override
  State<_ContestCard> createState() => _ContestCardState();
}

class _ContestCardState extends State<_ContestCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.contest;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/contest/${c.contestId}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.bg1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hover ? AppTheme.accent.withOpacity(0.5) : AppTheme.divider,
            ),
            boxShadow: _hover
                ? [BoxShadow(
                    color: AppTheme.accent.withOpacity(0.06),
                    blurRadius: 16, offset: const Offset(0, 4))]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      c.title,
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.text0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ContestStatusBadge(c.statusLabel),
                ],
              ),
              const SizedBox(height: 8),
              _TimeRow(icon: Icons.play_arrow_rounded, label: 'Start', time: c.startTime),
              const SizedBox(height: 4),
              _TimeRow(icon: Icons.stop_rounded, label: 'End', time: c.endTime),
              const SizedBox(height: 8),
              // Join code displayed inline on card
              if (c.joinCode != null)
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: c.joinCode!));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Join code copied!', style: GoogleFonts.inter()),
                      backgroundColor: const Color(0xFF4ADE80),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 1),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.key_outlined,
                            size: 12, color: AppTheme.accentLight),
                        const SizedBox(width: 5),
                        Text(
                          c.joinCode!,
                          style: GoogleFonts.firaCode(
                              fontSize: 12, color: AppTheme.accentLight),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.copy_outlined,
                            size: 11, color: AppTheme.accentLight),
                      ],
                    ),
                  ),
                ),
              const Spacer(),
              Row(
                children: [
                  Icon(Icons.extension_outlined, size: 14, color: AppTheme.text2),
                  const SizedBox(width: 4),
                  Text('${c.problems.length} problems',
                      style: GoogleFonts.inter(fontSize: 13, color: AppTheme.text2)),
                  const Spacer(),
                  Icon(Icons.chevron_right, color: AppTheme.text2, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final DateTime time;
  const _TimeRow({required this.icon, required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${time.year}-${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.text2),
        const SizedBox(width: 4),
        Text('$label: $formatted',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.text2)),
      ],
    );
  }
}

// ── Problems Tab ──────────────────────────────────────────────────────────────
class _ProblemsTab extends StatelessWidget {
  final List<Problem>? problems;
  final VoidCallback onRefresh;
  final dynamic user;

  const _ProblemsTab({required this.problems, required this.onRefresh, required this.user});

  @override
  Widget build(BuildContext context) {
    if (problems == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Problem Set',
                          style: Theme.of(context).textTheme.headlineLarge),
                      Text('Practice problems across all difficulty levels',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                // ── Add Problem button — visible to all users ──
                GradientButton(
                  label: 'Add Problem',
                  icon: const Icon(Icons.add, size: 16, color: Colors.white),
                  onPressed: () => context.go('/create-problem'),
                ),
              ],
            ),
          ),
        ),
        if (problems!.isEmpty)
          SliverFillRemaining(
            child: _EmptyState(
              label: 'No problems yet',
              subtitle: 'Be the first to add one!',
              icon: Icons.code_off_outlined,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _ProblemRow(problem: problems![i], currentUserId: user.userId, onDeleted: onRefresh),
                childCount: problems!.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _ProblemRow extends StatefulWidget {
  final Problem problem;
  final int currentUserId;
  final VoidCallback onDeleted;
  const _ProblemRow({required this.problem, required this.currentUserId, required this.onDeleted});

  @override
  State<_ProblemRow> createState() => _ProblemRowState();
}

class _ProblemRowState extends State<_ProblemRow> {
  bool _hover = false;
  bool _deleting = false;

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bg2,
        title: Text('Delete Problem',
            style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, color: AppTheme.text0)),
        content: Text('Are you sure you want to delete "${widget.problem.title}"? This cannot be undone.',
            style: GoogleFonts.inter(color: AppTheme.text1)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.spaceGrotesk(color: AppTheme.text2)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: GoogleFonts.spaceGrotesk(color: AppTheme.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ApiService.deleteProblem(widget.problem.problemId, widget.currentUserId);
      widget.onDeleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.problem;
    final isOwner = p.createdBy == widget.currentUserId;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go('/problem/${p.problemId}'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: _hover ? AppTheme.bg2 : AppTheme.bg1,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hover ? AppTheme.divider.withOpacity(0.7) : AppTheme.divider,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '#${p.problemId}',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 13, color: AppTheme.text2, fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Text(
                  p.title,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15, color: AppTheme.text0, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 12),
              ...p.tags.take(2).map((t) => Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.bg3,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(t,
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.text2)),
                  )),
              const SizedBox(width: 12),
              PointsChip(p.points),
              const SizedBox(width: 12),
              DifficultyBadge(p.difficulty),
              if (isOwner) ...[
                const SizedBox(width: 10),
                _deleting
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.red))
                    : GestureDetector(
                        onTap: () => _delete(context),
                        child: const Icon(Icons.delete_outline, size: 18, color: AppTheme.red),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String label;
  final String? subtitle;
  final IconData? icon;

  const _EmptyState({required this.label, this.subtitle, this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon ?? Icons.inbox_outlined, size: 48, color: AppTheme.text2),
          const SizedBox(height: 12),
          Text(label,
              style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 15)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!,
                style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 13)),
          ],
        ],
      ),
    );
  }
}