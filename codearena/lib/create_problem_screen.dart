import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'api_service.dart';
import 'auth_provider.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class CreateProblemScreen extends StatefulWidget {
  final int? problemId;
  const CreateProblemScreen({super.key, this.problemId});

  @override
  State<CreateProblemScreen> createState() => _CreateProblemScreenState();
}

class _CreateProblemScreenState extends State<CreateProblemScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // ── Problem fields ────────────────────────────────────────────────────────
  final _titleCtrl      = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _tagsCtrl       = TextEditingController();
  String _difficulty    = 'Easy';

  // ── Harness ───────────────────────────────────────────────────────────────
  final _harnessCtrl    = TextEditingController();
  final _starterCtrl    = TextEditingController();

  // ── Test cases ────────────────────────────────────────────────────────────
  List<_TcEntry> _testCases = [];

  bool _loadingProblem = false;
  bool _savingProblem  = false;
  bool _savingTcs      = false;
  String? _error;

  bool get _isEdit => widget.problemId != null;



  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    if (_isEdit) _loadExisting();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _tagsCtrl.dispose();
    _harnessCtrl.dispose();
    _starterCtrl.dispose();
    for (final e in _testCases) e.dispose();
    super.dispose();
  }

  // ── Load existing ─────────────────────────────────────────────────────────
  Future<void> _loadExisting() async {
    setState(() => _loadingProblem = true);
    try {
      final results = await Future.wait([
        ApiService.getProblem(widget.problemId!),
        ApiService.getTestCases(widget.problemId!),
      ]);
      final p   = results[0] as Problem;
      final tcs = results[1] as List<TestCase>;

      if (mounted) {
        _titleCtrl.text = p.title;
        _descCtrl.text  = p.description;
        _tagsCtrl.text  = p.tags.join(', ');

        if (p.harnessTemplate != null && p.harnessTemplate!.isNotEmpty) {
          _harnessCtrl.text = p.harnessTemplate!;
        }
        if (p.starterCode != null && p.starterCode!.isNotEmpty) {
          _starterCtrl.text = p.starterCode!;
        }

        _testCases = tcs
            .map((tc) => _TcEntry(
                  id: tc.testcaseId,
                  inputCtrl:  TextEditingController(text: tc.input),
                  outputCtrl: TextEditingController(text: tc.expectedOutput),
                ))
            .toList();
        setState(() => _difficulty = p.difficulty);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loadingProblem = false);
    }
  }

  // ── Save problem ──────────────────────────────────────────────────────────
  Future<void> _saveProblem() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    if (_harnessCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Harness template is required');
      return;
    }
    setState(() { _savingProblem = true; _error = null; });

    final tags = _tagsCtrl.text
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();

    try {
      if (_isEdit) {
        await ApiService.updateProblem(
          problemId:       widget.problemId!,
          title:           _titleCtrl.text.trim(),
          difficulty:      _difficulty,
          description:     _descCtrl.text,
          tags:            tags,
          harnessTemplate: _harnessCtrl.text,
          starterCode:     _starterCtrl.text,
        );
        _showSnack('Problem updated!', AppTheme.green);
      } else {
        final user = context.read<AuthProvider>().user!;
        final newId = await ApiService.createProblem(
          title:           _titleCtrl.text.trim(),
          difficulty:      _difficulty,
          description:     _descCtrl.text,
          tags:            tags,
          harnessTemplate: _harnessCtrl.text,
          starterCode:     _starterCtrl.text,
          createdBy:       user.userId,
        );

        if (_testCases.isNotEmpty) {
          await ApiService.addTestCasesBulk(
            problemId: newId,
            testCases: _testCases
                .map((e) => {
                      'input':           e.inputCtrl.text,
                      'expected_output': e.outputCtrl.text,
                    })
                .toList(),
          );
        }

        _showSnack('Problem created!', AppTheme.green);
        if (mounted) context.go('/home');
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingProblem = false);
    }
  }

  // ── Save test cases (edit mode) ───────────────────────────────────────────
  Future<void> _saveTestCases() async {
    if (!_isEdit) return;
    setState(() { _savingTcs = true; _error = null; });
    try {
      for (final entry in _testCases) {
        if (entry.id == -1) {
          await ApiService.addTestCase(
            problemId:      widget.problemId!,
            input:          entry.inputCtrl.text,
            expectedOutput: entry.outputCtrl.text,
          );
        } else if (entry.dirty) {
          await ApiService.updateTestCase(
            testcaseId:     entry.id,
            input:          entry.inputCtrl.text,
            expectedOutput: entry.outputCtrl.text,
          );
        }
      }
      _showSnack('Test cases saved!', AppTheme.green);
      await _reloadTestCases();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _savingTcs = false);
    }
  }

  Future<void> _reloadTestCases() async {
    if (!_isEdit) return;
    final tcs = await ApiService.getTestCases(widget.problemId!);
    for (final e in _testCases) e.dispose();
    if (mounted) {
      setState(() {
        _testCases = tcs
            .map((tc) => _TcEntry(
                  id:         tc.testcaseId,
                  inputCtrl:  TextEditingController(text: tc.input),
                  outputCtrl: TextEditingController(text: tc.expectedOutput),
                ))
            .toList();
      });
    }
  }

  Future<void> _deleteTestCase(_TcEntry entry) async {
    final confirmed = await _confirmDelete('Delete this test case?', 'Cannot be undone.');
    if (!confirmed) return;
    if (entry.id == -1) {
      setState(() => _testCases.remove(entry));
      return;
    }
    try {
      await ApiService.deleteTestCase(entry.id);
      entry.dispose();
      if (mounted) setState(() => _testCases.remove(entry));
      _showSnack('Deleted', AppTheme.red);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _addEmptyTestCase() {
    setState(() {
      _testCases.add(_TcEntry(
        id: -1,
        inputCtrl:  TextEditingController(),
        outputCtrl: TextEditingController(),
      ));
    });
    _tabCtrl.animateTo(2);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.inter()),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<bool> _confirmDelete(String title, String body) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppTheme.bg2,
            title: Text(title,
                style: GoogleFonts.spaceGrotesk(
                    fontWeight: FontWeight.w700, color: AppTheme.text0)),
            content: Text(body,
                style: GoogleFonts.inter(color: AppTheme.text1)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text('Cancel',
                      style: GoogleFonts.spaceGrotesk(color: AppTheme.text2))),
              TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text('Delete',
                      style: GoogleFonts.spaceGrotesk(color: AppTheme.red))),
            ],
          ),
        ) ??
        false;
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_loadingProblem) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => context.go('/home'),
        ),
        title: Text(_isEdit ? 'Edit Problem' : 'Create Problem'),
        actions: [
          if (_isEdit)
            _ToolbarBtn(
              icon: Icons.save_outlined,
              label: 'Save Test Cases',
              onTap: _saveTestCases,
              loading: _savingTcs,
            ),
          const SizedBox(width: 8),
          _ToolbarBtn(
            icon: Icons.check,
            label: _isEdit ? 'Update Problem' : 'Create Problem',
            onTap: _saveProblem,
            loading: _savingProblem,
            primary: true,
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.text2,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          labelStyle: GoogleFonts.spaceGrotesk(
              fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Harness'),
            Tab(text: 'Test Cases'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _DetailsTab(
            titleCtrl:  _titleCtrl,
            descCtrl:   _descCtrl,
            tagsCtrl:   _tagsCtrl,
            difficulty: _difficulty,
            onDifficultyChanged: (v) => setState(() => _difficulty = v),
            error:      _error,
          ),
          _HarnessTab(
            harnessCtrl: _harnessCtrl,
            starterCtrl: _starterCtrl,
          ),
          _TestCasesTab(
            testCases: _testCases,
            onAdd:     _addEmptyTestCase,
            onDelete:  _deleteTestCase,
            onChanged: () => setState(() {}),
            isEdit:    _isEdit,
            onSave:    _isEdit ? _saveTestCases : null,
            saving:    _savingTcs,
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Details ────────────────────────────────────────────────────────────
class _DetailsTab extends StatelessWidget {
  final TextEditingController titleCtrl, descCtrl, tagsCtrl;
  final String difficulty;
  final ValueChanged<String> onDifficultyChanged;
  final String? error;

  const _DetailsTab({
    required this.titleCtrl,
    required this.descCtrl,
    required this.tagsCtrl,
    required this.difficulty,
    required this.onDifficultyChanged,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FieldLabel('Title'),
            const SizedBox(height: 6),
            TextField(
              controller: titleCtrl,
              style: GoogleFonts.spaceGrotesk(color: AppTheme.text0),
              decoration: const InputDecoration(
                hintText: 'Two Sum',
                prefixIcon: Icon(Icons.title, size: 18, color: AppTheme.text2),
              ),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Difficulty'),
            const SizedBox(height: 8),
            Row(
              children: ['Easy', 'Medium', 'Hard'].map((d) {
                final selected = d == difficulty;
                final color = AppTheme.difficultyColor(d);
                return GestureDetector(
                  onTap: () => onDifficultyChanged(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected
                          ? color.withOpacity(0.15)
                          : AppTheme.bg2,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? color : AppTheme.divider,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      d,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : AppTheme.text2,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Description (Markdown supported)'),
            const SizedBox(height: 6),
            TextField(
              controller: descCtrl,
              maxLines: 14,
              style: GoogleFonts.inter(color: AppTheme.text0, fontSize: 13),
              decoration: InputDecoration(
                hintText:
                    'Describe the problem clearly.\n\nInclude:\n• Constraints\n• Examples\n• Edge cases',
                hintStyle:
                    GoogleFonts.inter(color: AppTheme.text2, fontSize: 13),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            _FieldLabel('Tags (comma-separated)'),
            const SizedBox(height: 6),
            TextField(
              controller: tagsCtrl,
              style: GoogleFonts.inter(color: AppTheme.text0),
              decoration: const InputDecoration(
                hintText: 'array, hashmap, two-pointers',
                prefixIcon:
                    Icon(Icons.label_outline, size: 18, color: AppTheme.text2),
              ),
            ),

            if (error != null) ...[
              const SizedBox(height: 16),
              _ErrorBanner(error!),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tab 2: Harness ────────────────────────────────────────────────────────────
class _HarnessTab extends StatelessWidget {
  final TextEditingController harnessCtrl;
  final TextEditingController starterCtrl;

  const _HarnessTab({
    required this.harnessCtrl,
    required this.starterCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Info banner ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.accent.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.accent.withOpacity(0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline,
                      size: 16, color: AppTheme.accentLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Write the full Python test harness. '
                      'The backend substitutes three placeholders at runtime:\n\n'
                      '  {{USER_CODE}}  — the user\'s submitted code\n'
                      '  {{INPUT}}      — the test case input (JSON string)\n'
                      '  {{EXPECTED}}   — the expected output (JSON string)\n\n'
                      'Your harness must print exactly "PASS" or "FAIL" to stdout.',
                      style: GoogleFonts.firaCode(
                          fontSize: 12,
                          color: AppTheme.accentLight,
                          height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Harness editor ───────────────────────────────────────────────
            _FieldLabel('Harness Template'),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: TextField(
                controller: harnessCtrl,
                maxLines: null,
                minLines: 18,
                style: GoogleFonts.firaCode(
                    fontSize: 13, color: AppTheme.text0, height: 1.6),
                decoration: InputDecoration(
                  hintText: '# Write your harness here...',
                  hintStyle: GoogleFonts.firaCode(
                      fontSize: 13, color: AppTheme.text2),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Quick-reference placeholder chips
            Wrap(
              spacing: 8,
              children: [
                _PlaceholderChip('{{USER_CODE}}'),
                _PlaceholderChip('{{INPUT}}'),
                _PlaceholderChip('{{EXPECTED}}'),
              ],
            ),
            const SizedBox(height: 28),

            const Divider(color: AppTheme.divider),
            const SizedBox(height: 20),

            // ── Starter code ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _FieldLabel('Starter Code (shown to users)')),
                Text('Shown in the editor when a user opens this problem',
                    style: GoogleFonts.inter(
                        fontSize: 12, color: AppTheme.text2)),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.divider),
              ),
              child: TextField(
                controller: starterCtrl,
                maxLines: null,
                minLines: 8,
                style: GoogleFonts.firaCode(
                    fontSize: 13, color: AppTheme.text0, height: 1.6),
                decoration: InputDecoration(
                  hintText: 'class Solution:\n    def myFunction(self, ...):\n        pass',
                  hintStyle: GoogleFonts.firaCode(
                      fontSize: 13, color: AppTheme.text2),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderChip extends StatelessWidget {
  final String label;
  const _PlaceholderChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(
        label,
        style: GoogleFonts.firaCode(
            fontSize: 12, color: AppTheme.accentLight),
      ),
    );
  }
}

// ── Tab 3: Test Cases ─────────────────────────────────────────────────────────
class _TestCasesTab extends StatelessWidget {
  final List<_TcEntry> testCases;
  final VoidCallback onAdd;
  final Future<void> Function(_TcEntry) onDelete;
  final VoidCallback onChanged;
  final bool isEdit;
  final Future<void> Function()? onSave;
  final bool saving;

  const _TestCasesTab({
    required this.testCases,
    required this.onAdd,
    required this.onDelete,
    required this.onChanged,
    required this.isEdit,
    required this.saving,
    this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Toolbar ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${testCases.length} test case${testCases.length == 1 ? '' : 's'}',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.text1),
              ),
              const Spacer(),
              if (isEdit && onSave != null)
                _ToolbarBtn(
                  icon: Icons.save_outlined,
                  label: 'Save All',
                  onTap: onSave!,
                  loading: saving,
                ),
              const SizedBox(width: 8),
              _ToolbarBtn(
                icon: Icons.add,
                label: 'Add Test Case',
                onTap: onAdd,
                primary: true,
              ),
            ],
          ),
        ),

        // ── Input format note ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.accent.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.accent.withOpacity(0.15)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.help_outline,
                    size: 14, color: AppTheme.accentLight),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Input and Expected Output are substituted into your harness as '
                    '{{INPUT}} and {{EXPECTED}} exactly as you type them here. '
                    'Use any format your harness expects (e.g. JSON).',
                    style: GoogleFonts.firaCode(
                        fontSize: 11,
                        color: AppTheme.accentLight,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),

        const Divider(height: 1, color: AppTheme.divider),

        // ── Test case list ────────────────────────────────────────────────
        Expanded(
          child: testCases.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.checklist_outlined,
                          size: 40, color: AppTheme.text2),
                      const SizedBox(height: 12),
                      Text('No test cases yet',
                          style: GoogleFonts.inter(
                              color: AppTheme.text2, fontSize: 14)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onAdd,
                        child: Text('Add one',
                            style:
                                GoogleFonts.inter(color: AppTheme.accent)),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: testCases.length,
                  itemBuilder: (_, i) => _TcCard(
                    entry: testCases[i],
                    index: i,
                    onDelete: () => onDelete(testCases[i]),
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }
}

// ── Test Case Card ────────────────────────────────────────────────────────────
class _TcCard extends StatefulWidget {
  final _TcEntry entry;
  final int index;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _TcCard({
    required this.entry,
    required this.index,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_TcCard> createState() => _TcCardState();
}

class _TcCardState extends State<_TcCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final isNew = widget.entry.id == -1;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isNew ? AppTheme.accent.withOpacity(0.35) : AppTheme.divider,
        ),
      ),
      child: Column(
        children: [
          // Header
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(10)),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isNew
                          ? AppTheme.accent.withOpacity(0.15)
                          : AppTheme.bg2,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isNew
                                ? AppTheme.accentLight
                                : AppTheme.text1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Test Case ${widget.index + 1}',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.text0),
                  ),
                  if (isNew) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('NEW',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.accentLight)),
                    ),
                  ],
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 16, color: AppTheme.red),
                    onPressed: widget.onDelete,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 18,
                    color: AppTheme.text2,
                  ),
                ],
              ),
            ),
          ),

          if (_expanded) ...[
            const Divider(height: 1, color: AppTheme.divider),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _TcField(
                      label: 'INPUT',
                      controller: widget.entry.inputCtrl,
                      hint: '[[2, 7, 11, 15], 9]',
                      onChanged: () {
                        widget.entry.dirty = true;
                        widget.onChanged();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TcField(
                      label: 'EXPECTED OUTPUT',
                      controller: widget.entry.outputCtrl,
                      hint: '[0, 1]',
                      onChanged: () {
                        widget.entry.dirty = true;
                        widget.onChanged();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared small widgets ──────────────────────────────────────────────────────
class _TcField extends StatelessWidget {
  final String label, hint;
  final TextEditingController controller;
  final VoidCallback onChanged;

  const _TcField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.text2,
                letterSpacing: 0.5)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          maxLines: 5,
          onChanged: (_) => onChanged(),
          style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.text0),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                GoogleFonts.firaCode(fontSize: 12, color: AppTheme.text2),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.spaceGrotesk(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.text1));
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
            child: Text(message,
                style: GoogleFonts.inter(color: AppTheme.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _ToolbarBtn extends StatefulWidget {
  final IconData icon;
  final String label;
  final dynamic onTap;
  final bool primary;
  final bool loading;

  const _ToolbarBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.loading = false,
  });

  @override
  State<_ToolbarBtn> createState() => _ToolbarBtnState();
}

class _ToolbarBtnState extends State<_ToolbarBtn> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.primary ? AppTheme.accent : AppTheme.text2;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hover
                ? (widget.primary
                    ? AppTheme.accent.withOpacity(0.15)
                    : AppTheme.bg3)
                : AppTheme.bg2,
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.primary
                  ? AppTheme.accent.withOpacity(0.5)
                  : AppTheme.divider,
            ),
          ),
          child: widget.loading
              ? SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: color))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 14, color: color),
                    const SizedBox(width: 6),
                    Text(widget.label,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: color)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── Internal state helpers ────────────────────────────────────────────────────
class _TcEntry {
  final int id;
  final TextEditingController inputCtrl;
  final TextEditingController outputCtrl;
  bool dirty;

  _TcEntry({
    required this.id,
    required this.inputCtrl,
    required this.outputCtrl,
    this.dirty = false,
  });

  void dispose() {
    inputCtrl.dispose();
    outputCtrl.dispose();
  }
}