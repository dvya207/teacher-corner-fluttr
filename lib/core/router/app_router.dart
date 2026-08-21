import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/shell/main_shell.dart';
import '../../features/placeholder_screen.dart';

/// Router SKELETON. The shell + the auth redirect are wired; the screens are
/// placeholders for you to replace, one per phase of the plan.
///
/// Two rules that the production app learned the hard way:
///
///  1. Build the router ONCE, in a StatefulWidget's `initState`, and hold it in
///     a field. If you build it inside a `Consumer`/`build` method it gets
///     recreated on every `notifyListeners()` and the whole navigation stack is
///     wiped, the user gets bounced to the first route mid-task.
///
///  2. `refreshListenable` is how the redirect learns about auth changes. Pass
///     a stable object; a new instance each build has the same effect as (1).
class AppRouter {
  AppRouter._();

  static GoRouter router({
    required Listenable refreshListenable,
    required bool Function() isAuthenticated,
  }) {
    return GoRouter(
      initialLocation: '/splash',
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        final loggingIn = state.matchedLocation == '/login' ||
            state.matchedLocation == '/splash';
        if (!isAuthenticated() && !loggingIn) return '/login';
        if (isAuthenticated() && loggingIn) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const PlaceholderScreen(title: 'Splash'),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const PlaceholderScreen(title: 'Login'),
        ),

        // ── The bottom-nav shell. Children keep their own navigation stack. ──
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/dashboard',
              builder: (context, state) => const PlaceholderScreen(title: 'Dashboard'),
            ),
            GoRoute(
              path: '/classrooms',
              builder: (context, state) => const PlaceholderScreen(title: 'Classrooms'),
              routes: [
                // Nested so the breadcrumb/back stack works: /classrooms/:id
                GoRoute(
                  path: ':id',
                  builder: (context, state) => PlaceholderScreen(
                    title: 'Classroom ${state.pathParameters['id']}',
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const PlaceholderScreen(title: 'Profile'),
            ),
          ],
        ),

        // Learning unit sits OUTSIDE the shell: it is a full-screen task view,
        // so the bottom nav should not be showing while a teacher is in it.
        GoRoute(
          path: '/lu/:id',
          builder: (context, state) => PlaceholderScreen(
            title: 'Learning Unit ${state.pathParameters['id']}',
          ),
        ),
      ],
    );
  }
}
