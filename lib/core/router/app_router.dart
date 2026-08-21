import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_screen.dart';
import '../../features/placeholder_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/splash/splash_screen.dart';

/// Router skeleton. The shell and the auth redirect are wired; the screens are
/// replaced one per phase of the plan.
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

  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';

  static GoRouter router({
    required Listenable refreshListenable,
    required bool Function() isAuthenticated,
    required bool Function() isAuthLoaded,
  }) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: refreshListenable,
      redirect: (context, state) {
        final location = state.matchedLocation;

        // Auth has not resolved yet. THREE states, not two: signed in, signed
        // out, and not-yet-known. Treating the third as "signed out" is what
        // makes every cold start flash the login screen before landing on the
        // dashboard, so hold on the splash until Firebase has actually
        // answered.
        if (!isAuthLoaded()) {
          return location == splash ? null : splash;
        }

        if (!isAuthenticated()) {
          // Everything except the login screen funnels back to it, so there is
          // no route, deep link or back gesture that reaches a signed-in screen
          // without a session.
          return location == login ? null : login;
        }

        // Signed in: the splash and the login form are no longer destinations.
        if (location == splash || location == login) return dashboard;
        return null;
      },
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),

        // ── The bottom-nav shell. Children keep their own navigation stack. ──
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: dashboard,
              builder: (context, state) =>
                  const PlaceholderScreen(title: 'Dashboard'),
            ),
            GoRoute(
              path: '/classrooms',
              builder: (context, state) =>
                  const PlaceholderScreen(title: 'Classrooms'),
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
              builder: (context, state) => const ProfileScreen(),
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
