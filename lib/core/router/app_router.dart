import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../features/auth/login_screen.dart';
import '../../features/classrooms/classroom_detail_provider.dart';
import '../../features/programmes/programme_detail_provider.dart';
import '../../features/classrooms/classroom_detail_screen.dart';
import '../../features/programmes/programme_detail_screen.dart';
import '../../features/classrooms/classroom_list_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/learning_unit/learning_unit_provider.dart';
import '../../features/learning_unit/missing_workflow_screen.dart';
import '../../features/learning_unit/learning_unit_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/quizzes/quizzes_provider.dart';
import '../../features/quizzes/quizzes_screen.dart';
import '../../features/shell/not_built_screen.dart';
import '../../features/profile/help_guide_screen.dart';
import '../../features/splash/splash_screen.dart';
import '../services/firestore_service.dart';

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

  /// The whole routing policy, as a pure function of three inputs.
  ///
  /// Extracted from the `GoRouter` closure so it can be tested without pumping
  /// a widget tree: this is the piece that regresses, and a test that needs a
  /// Firebase-backed app running is a test nobody runs.
  ///
  /// Returns the location to redirect to, or null to stay put.
  static String? resolveRedirect({
    required String location,
    required bool authLoaded,
    required bool isAuthenticated,
    bool splashHoldElapsed = true,
  }) {
    // THREE states, not two: signed in, signed out, and not-yet-known.
    // Treating the third as "signed out" is what makes every cold start flash
    // the login screen before landing on the dashboard, so hold on the splash
    // until Firebase has actually answered.
    // The splash also holds for its own minimum window, so the branding is
    // seen rather than flashed past when auth resolves in under 200ms. Both
    // conditions land on the same branch: there is one reason to be on the
    // splash, "we are not ready to route yet".
    if (!authLoaded || !splashHoldElapsed) {
      return location == splash ? null : splash;
    }

    if (!isAuthenticated) {
      // Everything except the login screen funnels back to it, so there is no
      // route, deep link or back gesture that reaches a signed-in screen
      // without a session.
      return location == login ? null : login;
    }

    // Signed in: the splash and the login form are no longer destinations.
    if (location == splash || location == login) return dashboard;
    return null;
  }

  static GoRouter router({
    required Listenable refreshListenable,
    required bool Function() isAuthenticated,
    required bool Function() isAuthLoaded,
    bool Function()? isSplashHoldElapsed,
  }) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: refreshListenable,
      redirect: (context, state) => resolveRedirect(
        location: state.matchedLocation,
        authLoaded: isAuthLoaded(),
        isAuthenticated: isAuthenticated(),
        splashHoldElapsed: isSplashHoldElapsed?.call() ?? true,
      ),
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const SplashScreen(),
        ),
        GoRoute(path: login, builder: (context, state) => const LoginScreen()),

        // ── The bottom-nav shell. Children keep their own navigation stack. ──
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: dashboard,
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              path: '/classrooms',
              builder: (context, state) => const ClassroomListScreen(),
              routes: [
                // Nested so the breadcrumb/back stack works: /classrooms/:id
                GoRoute(
                  path: ':id',
                  // The provider is created per route rather than app-wide, so
                  // opening a second classroom starts from a clean load instead
                  // of briefly showing the previous one's data.
                  builder: (context, state) {
                    final id = state.pathParameters['id']!;
                    return ChangeNotifierProvider<ClassroomDetailProvider>(
                      create: (ctx) => ClassroomDetailProvider(
                        firestore: ctx.read<FirestoreService>(),
                      ),
                      child: ClassroomDetailScreen(classroomId: id),
                    );
                  },
                  routes: [
                    // /classrooms/:id/programmes/:programmeId
                    //
                    // NESTED, so back returns to the classroom rather than the
                    // list, and the path itself records which classroom the
                    // teacher came in through. The programme document is shared
                    // across classrooms, so the classroom id is CONTEXT here,
                    // not part of the programme's identity — it is used for the
                    // breadcrumb and nothing else.
                    //
                    // Its own provider, created per route: a nested GoRoute
                    // does not inherit the parent route's providers, and one
                    // instance per programme means opening a second starts from
                    // a clean load instead of briefly showing the first one's
                    // name.
                    GoRoute(
                      path: 'programmes/:programmeId',
                      builder: (context, state) {
                        final programmeId =
                            state.pathParameters['programmeId']!;
                        return ChangeNotifierProvider<ProgrammeDetailProvider>(
                          create: (ctx) => ProgrammeDetailProvider(
                            firestore: ctx.read<FirestoreService>(),
                          ),
                          child: ProgrammeDetailScreen(
                            programmeId: programmeId,
                            // Passed through the query string rather than
                            // re-read: the classroom screen already has the
                            // name, and a read to render a breadcrumb would be
                            // a whole round trip for one line of text.
                            classroomName:
                                state.uri.queryParameters['classroomName'],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
            // Present in the shell because the bottom nav is part of the app's
            // shape, and honest about being outside this slice.
            GoRoute(
              path: '/quizzes',
              // PER ROUTE, like the classroom detail below it: leaving the tab
              // and coming back should re-read rather than show a list built
              // before an assignment was set.
              builder: (context, state) =>
                  ChangeNotifierProvider<QuizzesProvider>(
                    create: (ctx) => QuizzesProvider(
                      firestore: ctx.read<FirestoreService>(),
                    ),
                    child: const QuizzesScreen(),
                  ),
            ),
            GoRoute(
              path: '/reports',
              builder: (context, state) => const NotBuiltScreen(
                titleKey: 'nav.reports',
                icon: Icons.bar_chart_outlined,
              ),
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),

        // Learning unit sits OUTSIDE the shell: it is a full-screen task view,
        // so the bottom nav should not be showing while a teacher is in it.
        //
        // `workflowId` arrives as a query parameter rather than being looked up
        // here, because which workflow runs for this unit is a property of the
        // CLASSROOM that opened it. A link without it is not resolvable, and
        // guessing one would silently walk the teacher through the wrong steps.
        GoRoute(
          path: '/help',
          builder: (context, state) => const HelpGuideScreen(),
        ),
        GoRoute(
          path: '/lu/:id',
          builder: (context, state) {
            final learningUnitId = state.pathParameters['id']!;
            final workflowId =
                state.uri.queryParameters['workflowId']?.trim() ?? '';
            if (workflowId.isEmpty) {
              return const MissingWorkflowScreen();
            }
            final query = state.uri.queryParameters;
            return ChangeNotifierProvider<LearningUnitProvider>(
              create: (ctx) =>
                  LearningUnitProvider(firestore: ctx.read<FirestoreService>()),
              child: LearningUnitScreen(
                learningUnitId: learningUnitId,
                workflowId: workflowId,
                // Both needed to address the evidence document, which is one
                // per classroom+programme. Absent, the steps still work and
                // only the evidence pane says it cannot be reached.
                classroomId: query['classroomId']?.trim(),
                programmeId: query['programmeId']?.trim(),
              ),
            );
          },
        ),
      ],
    );
  }
}
