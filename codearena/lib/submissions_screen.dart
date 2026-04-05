import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'api_service.dart';
import 'auth_provider.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class SubmissionsScreen extends StatefulWidget {
  const SubmissionsScreen({super.key});

  @override
  State<SubmissionsScreen> createState() => _SubmissionsScreenState();
}

class _SubmissionsScreenState extends State<SubmissionsScreen> {
  List<Submission>? _submissions;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AuthProvider>().user!.userId;
    try {
      final s = await ApiService.getUserSubmissions(userId);
      if (mounted) setState(() => _submissions = s);
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => context.go('/home'),
        ),
        title: Text('My Submissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _load,
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!, style: TextStyle(color: AppTheme.red)))
          : _submissions == null
              ? const Center(child: CircularProgressIndicator())
              : _submissions!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_outlined,
                              size: 48, color: AppTheme.text2),
                          const SizedBox(height: 12),
                          Text('No submissions yet',
                              style: GoogleFonts.inter(
                                  color: AppTheme.text2, fontSize: 15)),
                        ],
                      ),
                    )
                  : CustomScrollView(
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Submission History',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge),
                                Text(
                                  '${_submissions!.length} total submissions',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 20),
                                // Stats row
                                Row(
                                  children: [
                                    _StatCard(
                                      label: 'Total',
                                      value: '${_submissions!.length}',
                                      color: AppTheme.accent,
                                    ),
                                    const SizedBox(width: 12),
                                    _StatCard(
                                      label: 'Accepted',
                                      value:
                                          '${_submissions!.where((s) => s.status == 'Accepted').length}',
                                      color: AppTheme.green,
                                    ),
                                    const SizedBox(width: 12),
                                    _StatCard(
                                      label: 'Wrong Answer',
                                      value:
                                          '${_submissions!.where((s) => s.status == 'Wrong Answer').length}',
                                      color: AppTheme.red,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppTheme.bg2,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Text('Problem',
                                        style: _headerStyle),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('Status', style: _headerStyle),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('Contest', style: _headerStyle),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text('Time (s)',
                                        textAlign: TextAlign.right,
                                        style: _headerStyle),
                                  ),
                                  SizedBox(
                                    width: 140,
                                    child: Text('Submitted',
                                        textAlign: TextAlign.right,
                                        style: _headerStyle),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 8)),

                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) =>
                                  _SubmissionRow(sub: _submissions![i]),
                              childCount: _submissions!.length,
                            ),
                          ),
                        ),
                      ],
                    ),
    );
  }

  TextStyle get _headerStyle => GoogleFonts.spaceGrotesk(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.text2,
      );
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatCard(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(label,
              style: GoogleFonts.inter(fontSize: 12, color: AppTheme.text2)),
        ],
      ),
    );
  }
}

class _SubmissionRow extends StatefulWidget {
  final Submission sub;
  const _SubmissionRow({required this.sub});

  @override
  State<_SubmissionRow> createState() => _SubmissionRowState();
}

class _SubmissionRowState extends State<_SubmissionRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final fmt = DateFormat('MMM d, HH:mm');

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _hover ? AppTheme.bg2 : AppTheme.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(
                s.problemTitle,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.text0,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(flex: 2, child: StatusBadge(s.status)),
            Expanded(
              flex: 2,
              child: Text(
                s.contestTitle ?? '—',
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppTheme.text2),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                s.executionTime.toStringAsFixed(3),
                textAlign: TextAlign.right,
                style: GoogleFonts.firaCode(
                    fontSize: 13, color: AppTheme.text1),
              ),
            ),
            SizedBox(
              width: 140,
              child: Text(
                fmt.format(s.submissionTime),
                textAlign: TextAlign.right,
                style:
                    GoogleFonts.inter(fontSize: 12, color: AppTheme.text2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}