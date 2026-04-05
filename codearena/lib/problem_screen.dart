import 'package:flutter/material.dart';
import 'package:flutter_code_editor/flutter_code_editor.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:highlight/languages/python.dart';
import 'package:highlight/languages/cpp.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'api_service.dart';
import 'auth_provider.dart';
import 'app_theme.dart';
import 'common_widgets.dart';

class ProblemScreen extends StatefulWidget {
  final int problemId;
  final int? contestId;

  const ProblemScreen({super.key, required this.problemId, this.contestId});

  @override
  State<ProblemScreen> createState() => _ProblemScreenState();
}

class _ProblemScreenState extends State<ProblemScreen>
    with SingleTickerProviderStateMixin {
  Problem? _problem;
  String? _error;

  String _language = 'python';
  late CodeController _codeCtrl;

  bool _running = false;
  bool _submitting = false;
  List<RunResult> _runResults = [];
  Map<String, dynamic>? _submitResult;
  String _outputTab = 'output';

  late final TabController _descTabCtrl;

  // ── Starter code generation ───────────────────────────────────────────────
  /// Returns the appropriate starter stub for [lang] based on the problem's
  /// function signature. Falls back to a generic stub if no signature exists.
  String _starterFor(String lang, Problem? p) {
    // Use the problem's stored starter code if available
    if (p?.starterCode != null && p!.starterCode!.isNotEmpty) {
      return p.starterCode!;
    }
    // Generic fallback
    if (lang == 'python') {
      return 'class Solution:\n    def solution(self):\n        # Write your solution here\n        pass\n';
    }
    return '#include <bits/stdc++.h>\nusing namespace std;\n\nclass Solution {\npublic:\n    int solution() {\n        // Write your solution here\n    }\n};\n';
  }

  @override
  void initState() {
    super.initState();
    _descTabCtrl = TabController(length: 2, vsync: this);
    // Initialise with generic stub; will be replaced once problem loads
    _codeCtrl = CodeController(
      text: _starterFor('python', null),
      language: python,
    );
    _loadProblem();
  }

  void _setLanguage(String lang) {
    final mode = lang == 'python' ? python : cpp;
    setState(() {
      _language = lang;
      _codeCtrl = CodeController(
        text: _starterFor(lang, _problem),
        language: mode,
      );
    });
  }

  Future<void> _loadProblem() async {
    try {
      final p = await ApiService.getProblem(widget.problemId);
      if (mounted) {
        setState(() {
          _problem = p;
          // Replace starter code with signature-aware stub now that we have the problem
          _codeCtrl = CodeController(
            text: _starterFor(_language, p),
            language: python,
          );
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _run() async {
    final user = context.read<AuthProvider>().user!;
    setState(() {
      _running = true;
      _runResults = [];
      _submitResult = null;
      _outputTab = 'output';
    });
    try {
      final results = await ApiService.runCode(
        userId: user.userId,
        problemId: widget.problemId,
        contestId: widget.contestId,
        language: _language,
        sourceCode: _codeCtrl.text,
      );
      if (mounted) setState(() => _runResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user!;
    setState(() {
      _submitting = true;
      _submitResult = null;
      _outputTab = 'verdict';
    });
    try {
      final result = await ApiService.submitCode(
        userId: user.userId,
        problemId: widget.problemId,
        contestId: widget.contestId,
        language: _language,
        sourceCode: _codeCtrl.text,
      );
      if (mounted) setState(() => _submitResult = result);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _descTabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
          body: Center(child: Text(_error!, style: const TextStyle(color: AppTheme.red))));
    }
    if (_problem == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = _problem!;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: AppTheme.bg0,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 16),
          onPressed: () => widget.contestId != null
              ? context.go('/contest/${widget.contestId}')
              : context.go('/home'),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Flexible(
              child: Text(p.title,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            DifficultyBadge(p.difficulty),
            const SizedBox(width: 8),
            PointsChip(p.points),
          ],
        ),
        actions: [
          // Language selector
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.bg2,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.divider),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _language,
                dropdownColor: AppTheme.bg2,
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text0),
                icon: const Icon(Icons.expand_more, size: 16, color: AppTheme.text2),
                items: const [
                  DropdownMenuItem(value: 'python', child: Text('Python')),
                ],
                onChanged: (v) { if (v != null) _setLanguage(v); },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'Run',
            loading: _running,
            color: AppTheme.bg2,
            textColor: AppTheme.text0,
            onTap: _run,
            icon: Icons.play_arrow_rounded,
          ),
          const SizedBox(width: 8),
          _ActionButton(
            label: 'Submit',
            loading: _submitting,
            color: AppTheme.accent,
            textColor: Colors.white,
            onTap: _submit,
            icon: Icons.upload_outlined,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: isWide ? _wideLayout(p) : _narrowLayout(p),
    );
  }

  // ── Wide layout: description left, editor right ───────────────────────────
  Widget _wideLayout(Problem p) {
    return Row(
      children: [
        SizedBox(
          width: 420,
          child: _DescriptionPanel(problem: p, tabCtrl: _descTabCtrl),
        ),
        const VerticalDivider(width: 1, color: AppTheme.divider),
        Expanded(
          child: Column(
            children: [
              Expanded(child: _editor()),
              const Divider(height: 1, color: AppTheme.divider),
              SizedBox(height: 240, child: _outputPanel()),
            ],
          ),
        ),
      ],
    );
  }

  // ── Narrow layout: stacked ────────────────────────────────────────────────
  Widget _narrowLayout(Problem p) {
    return Column(
      children: [
        SizedBox(
          height: 280,
          child: _DescriptionPanel(problem: p, tabCtrl: _descTabCtrl),
        ),
        const Divider(height: 1, color: AppTheme.divider),
        Expanded(child: _editor()),
        const Divider(height: 1, color: AppTheme.divider),
        SizedBox(height: 200, child: _outputPanel()),
      ],
    );
  }

  Widget _editor() {
    return CodeTheme(
      data: CodeThemeData(styles: atomOneDarkTheme),
      child: SingleChildScrollView(
        child: CodeField(
          controller: _codeCtrl,
          textStyle: GoogleFonts.firaCode(fontSize: 13),
          background: AppTheme.surface,
          gutterStyle: GutterStyle(
            textStyle: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.text2),
            background: AppTheme.bg1,
          ),
        ),
      ),
    );
  }

  Widget _outputPanel() {
    return Column(
      children: [
        // Tab bar
        Container(
          color: AppTheme.bg1,
          child: Row(
            children: [
              _OutputTab(
                label: 'Test Output',
                active: _outputTab == 'output',
                onTap: () => setState(() => _outputTab = 'output'),
                count: _runResults.isNotEmpty ? _runResults.length : null,
              ),
              _OutputTab(
                label: 'Verdict',
                active: _outputTab == 'verdict',
                onTap: () => setState(() => _outputTab = 'verdict'),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.divider),
        Expanded(
          child: _outputTab == 'output'
              ? _RunOutput(results: _runResults, running: _running)
              : _VerdictOutput(result: _submitResult),
        ),
      ],
    );
  }
}

// ── Description Panel ─────────────────────────────────────────────────────────
class _DescriptionPanel extends StatelessWidget {
  final Problem problem;
  final TabController tabCtrl;

  const _DescriptionPanel({required this.problem, required this.tabCtrl});

  @override
  Widget build(BuildContext context) {
    final p = problem;
    return Column(
      children: [
        // Function signature strip
        if (p.functionSignature != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppTheme.surface,
            child: Text(
              _signaturePreview(p.functionSignature!),
              style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.accentLight),
            ),
          ),
        TabBar(
          controller: tabCtrl,
          labelColor: AppTheme.accent,
          unselectedLabelColor: AppTheme.text2,
          indicatorColor: AppTheme.accent,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [Tab(text: 'Description'), Tab(text: 'Examples')],
        ),
        Expanded(
          child: TabBarView(
            controller: tabCtrl,
            children: [
              // ── Description ───────────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tags
                    if (p.tags.isNotEmpty)
                      Wrap(
                        spacing: 6, runSpacing: 6,
                        children: p.tags
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppTheme.bg3,
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(t,
                                      style: GoogleFonts.inter(
                                          fontSize: 11, color: AppTheme.text2)),
                                ))
                            .toList(),
                      ),
                    const SizedBox(height: 14),
                    Text(
                      p.description.isEmpty
                          ? 'No description provided.'
                          : p.description,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppTheme.text1, height: 1.7),
                    ),
                  ],
                ),
              ),

              // ── Examples ─────────────────────────────────────────────────
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: p.sampleTests.isEmpty
                    ? Center(
                        child: Text('No examples available',
                            style: GoogleFonts.inter(
                                color: AppTheme.text2, fontSize: 14)),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: p.sampleTests.asMap().entries.map((e) {
                          final i = e.key;
                          final tc = e.value;
                          return _ExampleCard(
                            index: i,
                            input: tc['input']?.toString() ?? '',
                            expected: tc['expected_output']?.toString() ?? '',
                            sig: p.functionSignature,
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _signaturePreview(FunctionSignature sig) {
    final params =
        sig.params.map((p) => '${p.name}: ${p.type}').join(', ');
    return 'def ${sig.name}(self, $params) -> ${sig.returnType}:';
  }
}

// ── Example Card ──────────────────────────────────────────────────────────────
class _ExampleCard extends StatelessWidget {
  final int index;
  final String input, expected;
  final FunctionSignature? sig;

  const _ExampleCard({
    required this.index,
    required this.input,
    required this.expected,
    this.sig,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Example ${index + 1}',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text1)),
          const SizedBox(height: 10),
          _IORow(label: 'Input', value: _formatInput(input, sig)),
          const SizedBox(height: 6),
          _IORow(label: 'Output', value: expected),
        ],
      ),
    );
  }

  String _formatInput(String raw, FunctionSignature? sig) {
    if (sig == null || sig.params.isEmpty) return raw;
    try {
      final args = List.from(
          (raw.startsWith('[') ? List.from(_parseJson(raw)) : [raw]));
      return sig.params.asMap().entries.map((e) {
        final idx = e.key;
        final param = e.value;
        final val = idx < args.length ? args[idx] : '?';
        return '${param.name} = $val';
      }).join('\n');
    } catch (_) {
      return raw;
    }
  }

  dynamic _parseJson(String s) {
    try {
      // Simple list extraction
      return s;
    } catch (_) {
      return s;
    }
  }
}

class _IORow extends StatelessWidget {
  final String label, value;
  const _IORow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text('$label:',
              style: GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.text2)),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              value,
              style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.text0),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Output tab ────────────────────────────────────────────────────────────────
class _OutputTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final int? count;

  const _OutputTab({
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? AppTheme.accent : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: active ? AppTheme.accent : AppTheme.text2,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.bg3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$count',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 11, color: AppTheme.text2)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Run Output ────────────────────────────────────────────────────────────────
class _RunOutput extends StatelessWidget {
  final List<RunResult> results;
  final bool running;

  const _RunOutput({required this.results, required this.running});

  @override
  Widget build(BuildContext context) {
    if (running) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Running test cases…',
                style: TextStyle(color: AppTheme.text2)),
          ],
        ),
      );
    }

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, size: 36, color: AppTheme.text2),
            const SizedBox(height: 8),
            Text('Press Run to test your code',
                style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 14)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: results.length,
      itemBuilder: (ctx, i) {
        final r = results[i];
        final color = AppTheme.statusColor(r.status);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bg1,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Test ${i + 1}',
                      style: GoogleFonts.spaceGrotesk(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text1)),
                  const SizedBox(width: 8),
                  StatusBadge(r.status),
                  const Spacer(),
                  Text('${r.executionTime.toStringAsFixed(3)}s',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.text2)),
                ],
              ),
              if (r.stderr.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(r.stderr,
                      style: GoogleFonts.firaCode(fontSize: 11, color: AppTheme.red)),
                ),
              ] else ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _IOBox(label: 'Your Output', content: r.actualOutput)),
                    const SizedBox(width: 8),
                    Expanded(child: _IOBox(label: 'Expected', content: r.expectedOutput)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _IOBox extends StatelessWidget {
  final String label, content;
  const _IOBox({required this.label, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.spaceGrotesk(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.text2)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            content.isEmpty ? '(empty)' : content,
            style: GoogleFonts.firaCode(fontSize: 12, color: AppTheme.text0),
          ),
        ),
      ],
    );
  }
}

// ── Verdict Output ────────────────────────────────────────────────────────────
class _VerdictOutput extends StatelessWidget {
  final Map<String, dynamic>? result;
  const _VerdictOutput({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.upload_outlined, size: 36, color: AppTheme.text2),
            const SizedBox(height: 8),
            Text('Submit to see your verdict',
                style: GoogleFonts.inter(color: AppTheme.text2, fontSize: 14)),
          ],
        ),
      );
    }

    final status = result!['status'] as String? ?? 'Unknown';
    final color  = AppTheme.statusColor(status);
    final passed = status == 'Accepted';
    final tests  = result!['test_results'] as List? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                  color: color, size: 28,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 20, fontWeight: FontWeight.w700, color: color)),
                    Text(result!['message'] ?? '',
                        style: GoogleFonts.inter(fontSize: 13, color: AppTheme.text2)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (tests.isNotEmpty) ...[
            Text('Test Cases',
                style: GoogleFonts.spaceGrotesk(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.text1)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: tests.map<Widget>((t) {
                final s = t['status'] as String;
                final c = AppTheme.statusColor(s);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: c.withOpacity(0.3)),
                  ),
                  child: Text('TC ${t['test_case']}: $s',
                      style: GoogleFonts.inter(
                          fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Action button ─────────────────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final String label;
  final bool loading;
  final Color color, textColor;
  final VoidCallback onTap;
  final IconData icon;

  const _ActionButton({
    required this.label,
    required this.loading,
    required this.color,
    required this.textColor,
    required this.onTap,
    required this.icon,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.loading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: _hover ? widget.color.withOpacity(0.85) : widget.color,
            borderRadius: BorderRadius.circular(8),
            border: widget.color == AppTheme.bg2
                ? Border.all(color: AppTheme.divider)
                : null,
          ),
          child: widget.loading
              ? SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: widget.textColor))
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon, size: 14, color: widget.textColor),
                    const SizedBox(width: 5),
                    Text(widget.label,
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: widget.textColor)),
                  ],
                ),
        ),
      ),
    );
  }
}