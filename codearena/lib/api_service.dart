import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // ── Auth ──────────────────────────────────────────────────────────────────
  static Future<UserModel> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) return UserModel.fromJson(jsonDecode(res.body));
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Login failed');
  }

  static Future<UserModel> register(
      String username, String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    );
    if (res.statusCode == 200) return UserModel.fromJson(jsonDecode(res.body));
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Registration failed');
  }

  // ── Problems ──────────────────────────────────────────────────────────────
  static Future<List<Problem>> getProblems() async {
    final res = await http.get(Uri.parse('$baseUrl/problems'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Problem.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception('Failed to load problems');
  }

  static Future<Problem> getProblem(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/problems/$id'));
    if (res.statusCode == 200) return Problem.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load problem');
  }

  // ── Contests ──────────────────────────────────────────────────────────────

  /// Contests the user has joined (persisted in DB — survives logout)
  static Future<List<Contest>> getJoinedContests(int userId) async {
    final res = await http.get(Uri.parse('$baseUrl/contests/joined/$userId'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Contest.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception('Failed to load joined contests');
  }

  static Future<List<Contest>> getContests() async {
    final res = await http.get(Uri.parse('$baseUrl/contests'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => Contest.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception('Failed to load contests');
  }

  static Future<Contest> getContest(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/contests/$id'));
    if (res.statusCode == 200) return Contest.fromJson(jsonDecode(res.body));
    throw Exception('Failed to load contest');
  }

  static Future<Map<String, dynamic>> createContest({
    required String title,
    required String startTime,
    required String endTime,
    required List<int> problemIds,
    int? createdBy,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/contests'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'start_time': startTime,
        'end_time': endTime,
        'problem_ids': problemIds,
        'created_by': createdBy,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to create contest');
  }

  /// Join a contest by its human-readable join code.
  /// Returns {'contest_id': int, 'title': String, 'message': String}
  static Future<Map<String, dynamic>> joinContest({
    required int userId,
    required String joinCode,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/contests/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId, 'join_code': joinCode}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to join contest');
  }

  // ── Run / Submit ──────────────────────────────────────────────────────────
  static Future<List<RunResult>> runCode({
    required int userId,
    required int problemId,
    int? contestId,
    required String language,
    required String sourceCode,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/run'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'problem_id': problemId,
        'contest_id': contestId,
        'language': language,
        'source_code': sourceCode,
      }),
    );
    if (res.statusCode == 200) {
      final body = jsonDecode(res.body);
      final list = body['results'] as List;
      return list.map((e) => RunResult.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Run failed');
  }

  static Future<Map<String, dynamic>> submitCode({
    required int userId,
    required int problemId,
    int? contestId,
    required String language,
    required String sourceCode,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/submit_code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'problem_id': problemId,
        'contest_id': contestId,
        'language': language,
        'source_code': sourceCode,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Submission failed');
  }

  // ── Leaderboard ───────────────────────────────────────────────────────────
  static Future<List<LeaderboardEntry>> getLeaderboard(int contestId) async {
    final res = await http.get(Uri.parse('$baseUrl/leaderboard/$contestId'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => LeaderboardEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Failed to load leaderboard');
  }

  // ── Problem CRUD ──────────────────────────────────────────────────────────
  static Future<int> createProblem({
    required String title,
    required String difficulty,
    required String description,
    required List<String> tags,
    String? harnessTemplate,
    String? starterCode,
    int? createdBy,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/problems'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'difficulty': difficulty,
        'description': description,
        'tags': tags,
        'harness_template': harnessTemplate ?? '',
        'starter_code': starterCode ?? '',
        'created_by': createdBy,
      }),
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['problem_id'];
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to create problem');
  }

  static Future<void> updateProblem({
    required int problemId,
    String? title,
    String? difficulty,
    String? description,
    List<String>? tags,
    String? harnessTemplate,
    String? starterCode,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (difficulty != null) body['difficulty'] = difficulty;
    if (description != null) body['description'] = description;
    if (tags != null) body['tags'] = tags;
    if (harnessTemplate != null) body['harness_template'] = harnessTemplate;
    if (starterCode != null) body['starter_code'] = starterCode;
    final res = await http.put(
      Uri.parse('$baseUrl/problems/$problemId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to update problem');
    }
  }

  static Future<void> deleteProblem(int problemId, int userId) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/problems/$problemId?user_id=$userId'),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to delete problem');
    }
  }

  // ── Test Cases ────────────────────────────────────────────────────────────
  static Future<List<TestCase>> getTestCases(int problemId) async {
    final res = await http.get(Uri.parse('$baseUrl/problems/$problemId/testcases'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list.map((e) => TestCase.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    throw Exception('Failed to load test cases');
  }

  static Future<int> addTestCase({
    required int problemId,
    required String input,
    required String expectedOutput,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/problems/$problemId/testcases'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'problem_id': problemId, 'input': input, 'expected_output': expectedOutput}),
    );
    if (res.statusCode == 200) return jsonDecode(res.body)['testcase_id'];
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to add test case');
  }

  static Future<void> addTestCasesBulk({
    required int problemId,
    required List<Map<String, String>> testCases,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/problems/$problemId/testcases/bulk'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'problem_id': problemId, 'test_cases': testCases}),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to bulk-add test cases');
    }
  }

  static Future<void> updateTestCase({
    required int testcaseId,
    String? input,
    String? expectedOutput,
  }) async {
    final body = <String, dynamic>{};
    if (input != null) body['input'] = input;
    if (expectedOutput != null) body['expected_output'] = expectedOutput;
    final res = await http.put(
      Uri.parse('$baseUrl/testcases/$testcaseId'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to update test case');
    }
  }

  static Future<void> deleteTestCase(int testcaseId) async {
    final res = await http.delete(Uri.parse('$baseUrl/testcases/$testcaseId'));
    if (res.statusCode != 200) {
      throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to delete test case');
    }
  }

  // ── Submissions ───────────────────────────────────────────────────────────
  static Future<List<Submission>> getUserSubmissions(int userId) async {
    final res = await http.get(Uri.parse('$baseUrl/submissions/$userId'));
    if (res.statusCode == 200) {
      final list = jsonDecode(res.body) as List;
      return list
          .map((e) => Submission.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    throw Exception('Failed to load submissions');
  }
}