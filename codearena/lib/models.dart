class UserModel {
  final int userId;
  final String username;
  final String email;

  UserModel({required this.userId, required this.username, required this.email});

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        userId: j['user_id'],
        username: j['username'],
        email: j['email'],
      );
}

// ── FunctionSignature ─────────────────────────────────────────────────────────
class FunctionParam {
  final String name;
  final String type;

  const FunctionParam({required this.name, required this.type});

  factory FunctionParam.fromJson(Map<String, dynamic> j) => FunctionParam(
        name: j['name'] as String,
        type: j['type'] as String,
      );

  Map<String, dynamic> toJson() => {'name': name, 'type': type};
}

class FunctionSignature {
  final String name;
  final String returnType;
  final List<FunctionParam> params;

  const FunctionSignature({
    required this.name,
    required this.returnType,
    this.params = const [],
  });

  factory FunctionSignature.fromJson(Map<String, dynamic> j) => FunctionSignature(
        name:       j['name'] as String,
        returnType: j['return_type'] as String,
        params:     (j['params'] as List?)
                        ?.map((e) => FunctionParam.fromJson(Map<String, dynamic>.from(e)))
                        .toList() ??
                    [],
      );

  Map<String, dynamic> toJson() => {
        'name':        name,
        'return_type': returnType,
        'params':      params.map((p) => p.toJson()).toList(),
      };

  /// Boilerplate Python starter derived from this signature.
  String get pythonStarter {
    final paramList = params.map((p) => '${p.name}: ${p.type}').join(', ');
    return 'from typing import List\n\nclass Solution:\n    def $name(self, $paramList) -> $returnType:\n        # Write your solution here\n        pass\n';
  }

  /// Boilerplate C++ starter derived from this signature.
  String get cppStarter {
    final paramList = params.map((p) => '${p.type} ${p.name}').join(', ');
    return '#include <bits/stdc++.h>\nusing namespace std;\n\nclass Solution {\npublic:\n    $returnType $name($paramList) {\n        // Write your solution here\n    }\n};\n';
  }
}

// ── Problem ───────────────────────────────────────────────────────────────────
class Problem {
  final int problemId;
  final String title;
  final String difficulty;
  final int points;
  final String description;
  final List<String> tags;
  final List<Map<String, dynamic>> sampleTests;
  /// Full Python harness template with {{USER_CODE}}, {{INPUT}}, {{EXPECTED}} placeholders.
  final String? harnessTemplate;
  /// Boilerplate shown to users in the code editor.
  final String? starterCode;
  /// Structured function signature used to generate language-specific starters.
  final FunctionSignature? functionSignature;
  /// The user_id of the user who created this problem.
  final int? createdBy;

  Problem({
    required this.problemId,
    required this.title,
    required this.difficulty,
    required this.points,
    this.description = '',
    this.tags = const [],
    this.sampleTests = const [],
    this.harnessTemplate,
    this.starterCode,
    this.functionSignature,
    this.createdBy,
  });

  factory Problem.fromJson(Map<String, dynamic> j) {
    return Problem(
      problemId:         j['problem_id'],
      title:             j['title'],
      difficulty:        j['difficulty'] ?? 'Easy',
      points:            j['points'] ?? 50,
      description:       j['description'] ?? '',
      tags:              (j['tags'] as List?)?.cast<String>() ?? [],
      sampleTests:       (j['sample_tests'] as List?)
                             ?.map((e) => Map<String, dynamic>.from(e))
                             .toList() ??
                         [],
      harnessTemplate:   j['harness_template'] as String?,
      starterCode:       j['starter_code'] as String?,
      functionSignature: j['function_signature'] != null
                             ? FunctionSignature.fromJson(
                                 Map<String, dynamic>.from(j['function_signature']))
                             : null,
      createdBy:         j['created_by'] as int?,
    );
  }
}

// ── Contest ───────────────────────────────────────────────────────────────────
class Contest {
  final int contestId;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final List<Problem> problems;
  final String? joinCode;

  Contest({
    required this.contestId,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.problems = const [],
    this.joinCode,
  });

  bool get isActive =>
      DateTime.now().isAfter(startTime) && DateTime.now().isBefore(endTime);
  bool get isUpcoming => DateTime.now().isBefore(startTime);
  bool get isEnded => DateTime.now().isAfter(endTime);

  String get statusLabel =>
      isActive ? 'Live' : isUpcoming ? 'Upcoming' : 'Ended';

  factory Contest.fromJson(Map<String, dynamic> j) => Contest(
        contestId: j['contest_id'],
        title: j['title'],
        startTime: DateTime.parse(j['start_time']),
        endTime: DateTime.parse(j['end_time']),
        joinCode: j['join_code'] as String?,
        problems: (j['problems'] as List?)
                ?.map((e) => Problem.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

// ── LeaderboardEntry ──────────────────────────────────────────────────────────
class LeaderboardEntry {
  final int rank;
  final String username;
  final int totalScore;
  final double totalTime;
  final int problemsSolved;

  LeaderboardEntry({
    required this.rank,
    required this.username,
    required this.totalScore,
    required this.totalTime,
    required this.problemsSolved,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> j) => LeaderboardEntry(
        rank: j['rank'] ?? 0,
        username: j['username'],
        totalScore: (j['total_score'] as num?)?.toInt() ?? 0,
        totalTime: (j['total_time'] as num?)?.toDouble() ?? 0.0,
        problemsSolved: (j['problems_solved'] as num?)?.toInt() ?? 0,
      );
}

// ── Submission ────────────────────────────────────────────────────────────────
class Submission {
  final int submissionId;
  final String problemTitle;
  final String status;
  final double executionTime;
  final DateTime submissionTime;
  final String? contestTitle;

  Submission({
    required this.submissionId,
    required this.problemTitle,
    required this.status,
    required this.executionTime,
    required this.submissionTime,
    this.contestTitle,
  });

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        submissionId: j['submission_id'],
        problemTitle: j['title'],
        status: j['status'],
        executionTime: (j['execution_time'] as num?)?.toDouble() ?? 0.0,
        submissionTime: DateTime.parse(j['submission_time']),
        contestTitle: j['contest_title'],
      );
}

// ── TestCase ──────────────────────────────────────────────────────────────────
class TestCase {
  final int testcaseId;
  final int problemId;
  final String input;
  final String expectedOutput;

  TestCase({
    required this.testcaseId,
    required this.problemId,
    required this.input,
    required this.expectedOutput,
  });

  factory TestCase.fromJson(Map<String, dynamic> j) => TestCase(
        testcaseId: j['testcase_id'],
        problemId: j['problem_id'],
        input: j['input'] ?? '',
        expectedOutput: j['expected_output'] ?? '',
      );

  TestCase copyWith({String? input, String? expectedOutput}) => TestCase(
        testcaseId: testcaseId,
        problemId: problemId,
        input: input ?? this.input,
        expectedOutput: expectedOutput ?? this.expectedOutput,
      );
}

// ── RunResult ─────────────────────────────────────────────────────────────────
class RunResult {
  final String input;
  final String expectedOutput;
  final String actualOutput;
  final String status;
  final double executionTime;
  final String stderr;

  RunResult({
    required this.input,
    required this.expectedOutput,
    required this.actualOutput,
    required this.status,
    required this.executionTime,
    required this.stderr,
  });

  factory RunResult.fromJson(Map<String, dynamic> j) => RunResult(
        input: j['input'] ?? '',
        expectedOutput: j['expected_output'] ?? '',
        actualOutput: j['actual_output'] ?? '',
        status: j['status'] ?? '',
        executionTime: (j['execution_time'] as num?)?.toDouble() ?? 0.0,
        stderr: j['stderr'] ?? '',
      );
}