import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'api_service.dart';
import 'auth_provider.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class CreateContestScreen extends StatefulWidget {
  const CreateContestScreen({super.key});

  @override
  State<CreateContestScreen> createState() => _CreateContestScreenState();
}

class _CreateContestScreenState extends State<CreateContestScreen> {
  final _titleCtrl = TextEditingController();
  DateTime _startTime = DateTime.now().add(const Duration(hours: 1));
  DateTime _endTime = DateTime.now().add(const Duration(hours: 3));
  List<Problem>? _allProblems;
  final Set<int> _selectedProblemIds = {};
  bool _loading = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProblems();
  }

  Future<void> _loadProblems() async {
    setState(() => _loading = true);
    try {
      final p = await ApiService.getProblems();
      if (mounted) setState(() => _allProblems = p);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDateTimePicker(context, isStart ? _startTime : _endTime);
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<DateTime?> showDateTimePicker(BuildContext ctx, DateTime initial) async {
    final date = await showDatePicker(
      context: ctx,
      initialDate: initial,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            onPrimary: Colors.white,
            surface: AppTheme.bg2,
            onSurface: AppTheme.text0,
          ),
        ),
        child: child!,
      ),
    );
    if (date == null) return null;

    final time = await showTimePicker(
      context: ctx,
      initialTime: TimeOfDay.fromDateTime(initial),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.accent,
            onPrimary: Colors.white,
            surface: AppTheme.bg2,
            onSurface: AppTheme.text0,
          ),
        ),
        child: child!,
      ),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  /// Formats a DateTime to MySQL-compatible 'YYYY-MM-DD HH:MM:SS'
  String _fmt(DateTime dt) =>
      '${dt.year}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}:00';

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Contest title is required');
      return;
    }
    if (_endTime.isBefore(_startTime)) {
      setState(() => _error = 'End time must be after start time');
      return;
    }
    if (_selectedProblemIds.isEmpty) {
      setState(() => _error = 'Select at least one problem');
      return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final user = context.read<AuthProvider>().user!;
      final res = await ApiService.createContest(
        title: _titleCtrl.text.trim(),
        startTime: _fmt(_startTime),
        endTime: _fmt(_endTime),
        problemIds: _selectedProblemIds.toList(),
        createdBy: user.userId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Contest created!', style: GoogleFonts.inter()),
          backgroundColor: AppTheme.green,
          behavior: SnackBarBehavior.floating,
        ));
        context.go('/contest/${res["contest_id"]}');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => context.go('/home'),
        ),
        title: const Text('Create Contest'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text('New Contest',
                  style: Theme.of(context).textTheme.displaySmall),
              const SizedBox(height: 4),
              Text('Set up your competitive coding contest',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 28),

              // ── Title ─────────────────────────────────────────────────────
              _Label('Contest Title'),
              const SizedBox(height: 6),
              TextField(
                controller: _titleCtrl,
                style: GoogleFonts.spaceGrotesk(color: AppTheme.text0),
                decoration: const InputDecoration(
                  hintText: 'Weekly Challenge #1',
                  prefixIcon: Icon(Icons.emoji_events_outlined,
                      size: 18, color: AppTheme.text2),
                ),
              ),
              const SizedBox(height: 20),

              // ── Times ─────────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('Start Time'),
                        const SizedBox(height: 6),
                        _DateTile(
                          dateTime: _startTime,
                          onTap: () => _pickDate(true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label('End Time'),
                        const SizedBox(height: 6),
                        _DateTile(
                          dateTime: _endTime,
                          onTap: () => _pickDate(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── Problems ──────────────────────────────────────────────────
              Row(
                children: [
                  Expanded(child: _Label('Select Problems')),
                  if (_selectedProblemIds.isNotEmpty)
                    Text(
                      '${_selectedProblemIds.length} selected',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              if (_loading)
                const Center(child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ))
              else if (_allProblems == null || _allProblems!.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.bg1,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Text('No problems available',
                      style: GoogleFonts.inter(color: AppTheme.text2)),
                )
              else
                Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bg1,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: Column(
                    children: _allProblems!.asMap().entries.map((entry) {
                      final i = entry.key;
                      final p = entry.value;
                      final selected = _selectedProblemIds.contains(p.problemId);
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.vertical(
                            top: i == 0 ? const Radius.circular(10) : Radius.zero,
                            bottom: i == _allProblems!.length - 1
                                ? const Radius.circular(10)
                                : Radius.zero,
                          ),
                          onTap: () => setState(() {
                            if (selected) {
                              _selectedProblemIds.remove(p.problemId);
                            } else {
                              _selectedProblemIds.add(p.problemId);
                            }
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              border: i < _allProblems!.length - 1
                                  ? Border(
                                      bottom: BorderSide(color: AppTheme.divider))
                                  : null,
                            ),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppTheme.accent
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: selected
                                          ? AppTheme.accent
                                          : AppTheme.text2,
                                    ),
                                  ),
                                  child: selected
                                      ? const Icon(Icons.check,
                                          size: 13, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    p.title,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppTheme.text0,
                                    ),
                                  ),
                                ),
                                PointsChip(p.points),
                                const SizedBox(width: 8),
                                DifficultyBadge(p.difficulty),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const SizedBox(height: 24),

              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.red.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: AppTheme.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13))),
                  ]),
                ),

              GradientButton(
                label: 'Create Contest',
                loading: _submitting,
                width: double.infinity,
                onPressed: _create,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppTheme.text1,
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final DateTime dateTime;
  final VoidCallback onTap;
  const _DateTile({required this.dateTime, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatted =
        '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} '
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppTheme.bg2,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 15, color: AppTheme.text2),
            const SizedBox(width: 8),
            Text(
              formatted,
              style: GoogleFonts.inter(fontSize: 13, color: AppTheme.text0),
            ),
          ],
        ),
      ),
    );
  }
}