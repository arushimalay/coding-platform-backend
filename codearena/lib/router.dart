import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'landing_screen.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'contest_screen.dart';
import 'problem_screen.dart';
import 'create_contest_screen.dart';
import 'create_problem_screen.dart';
import 'submissions_screen.dart';
import 'auth_provider.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final loggedIn = auth.isLoggedIn;
      final loc = state.matchedLocation;

      final publicRoutes = ['/', '/login', '/register'];
      final isPublic = publicRoutes.contains(loc);

      if (!loggedIn && !isPublic) return '/login';
      if (loggedIn && isPublic && loc != '/') return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const LandingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/contest/:id',
        builder: (_, state) => ContestScreen(
          contestId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/problem/:id',
        builder: (_, state) {
          final contestId = state.uri.queryParameters['contest'];
          return ProblemScreen(
            problemId: int.parse(state.pathParameters['id']!),
            contestId: contestId != null ? int.parse(contestId) : null,
          );
        },
      ),
      GoRoute(
          path: '/create-contest',
          builder: (_, __) => const CreateContestScreen()),
      GoRoute(
          path: '/create-problem',
          builder: (_, __) => const CreateProblemScreen()),
      GoRoute(
          path: '/edit-problem/:id',
          builder: (_, state) => CreateProblemScreen(
                problemId: int.parse(state.pathParameters['id']!),
              )),
      GoRoute(
          path: '/submissions',
          builder: (_, __) => const SubmissionsScreen()),
    ],
  );
}