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
import '../../features/learning_unit/learning_unit_overview_screen.dart';
import '../../features/learning_unit/learning_unit_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/shell/main_shell.dart';
import '../../features/quizzes/quiz_player_provider.dart';
import '../../features/quizzes/quiz_player_screen.dart';
import '../../features/quizzes/quizzes_provider.dart';
import '../../features/quizzes/quizzes_screen.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/reports/reports_hub_screen.dart';
import '../../features/reports/submissions_screen.dart';
import '../../features/reports/submission_activities_screen.dart';
import '../../features/reports/submissions_provider.dart';
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
              // `?q=` seeds the search. A dashboard school row lands here with
              // its own name already typed in; see ClassroomListScreen.
              builder: (context, state) => ClassroomListScreen(
                key: ValueKey(state.uri.queryParameters['q'] ?? ''),
                initialQuery: state.uri.queryParameters['q'],
              ),
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
              builder: (context, state) => const ReportsHubScreen(),
              routes: [
                // NESTED, so the hub stays in the stack and Back returns to it
                // rather than to whichever tab was open before.
                GoRoute(
                  path: 'submissions',
                  builder: (context, state) =>
                      ChangeNotifierProvider<SubmissionsProvider>(
                        create: (ctx) {
                          final auth = ctx.read<AuthProvider>();
                          return SubmissionsProvider(
                            firestore: ctx.read<FirestoreService>(),
                            uid: auth.uid,
                            phoneNumber: auth.phoneNumber,
                          );
                        },
                        child: const SubmissionsScreen(),
                      ),
                  routes: [
                    // BOTH IDS IN THE PATH, not carried in provider state. The
                    // report is a place a teacher can be sent back to, and a
                    // screen whose subject lives only in memory cannot be
                    // restored after the process is killed mid-lesson.
                    GoRoute(
                      path: ':classroomId/:programmeId',
                      builder: (context, state) {
                        final classroomId =
                            state.pathParameters['classroomId'] ?? '';
                        final programmeId =
                            state.pathParameters['programmeId'] ?? '';
                        return ChangeNotifierProvider<
                          ActivitySubmissionsProvider
                        >(
                          create: (ctx) => ActivitySubmissionsProvider(
                            firestore: ctx.read<FirestoreService>(),
                            uid: ctx.read<AuthProvider>().uid,
                            classroomId: classroomId,
                            programmeId: programmeId,
                          ),
                          child: const SubmissionActivitiesScreen(),
                        );
                      },
                    ),
                  ],
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
        //
        // `workflowId` arrives as a query parameter rather than being looked up
        // here, because which workflow runs for this unit is a property of the
        // CLASSROOM that opened it. A link without it is not resolvable, and
        // guessing one would silently walk the teacher through the wrong steps.
        GoRoute(
          path: '/help',
          builder: (context, state) => const HelpGuideScreen(),
        ),
        /*
         * THE QUIZ PLAYER IS TOP-LEVEL, NOT NESTED UNDER `/quizzes`.
         *
         * It used to be a nested route inside the ShellRoute, and that threw
         * "A GlobalKey was used multiple times inside one widget's child list"
         * and painted the red error screen the moment a quiz was opened from a
         * workflow step. The step player at `/lu/:id/steps` is itself a
         * top-level route, deliberately outside the shell, so pushing a
         * shell-nested route from it asked go_router to build the shell's
         * Navigator underneath a route already mounted on the root one. Two
         * Navigators cannot share a GlobalKey, so the build asserted.
         *
         * REACHED FROM BOTH SIDES OF THE SHELL BOUNDARY, which is the real
         * reason it cannot live inside: the Quizzes tab pushes it from within
         * the shell and a workflow step pushes it from outside. A route with
         * two callers on opposite sides of a shell has to sit above both.
         *
         * It also belongs here on the app's own terms. `LearningUnitScreen`
         * is outside the shell because "a teacher in the middle of a step
         * should not be one stray tap from another tab", and a teacher in the
         * middle of a timed, attempt-capped quiz has the stronger claim to
         * the same protection.
         *
         * THE PATH IS UNCHANGED, so every call site still pushes
         * `/quizzes/play`. It keeps the URL honest about which tab the quiz
         * belongs to without nesting the ROUTE inside that tab.
         *
         * THE TARGET COMES THROUGH `extra` rather than the path: the player
         * needs a whole parsed Assignment, and the classroom and programme
         * that allotted it are properties of the list ROW, which an id in the
         * URL could not express without three more reads.
         */
        GoRoute(
          path: '/quizzes/play',
          builder: (context, state) {
            final extra = state.extra;

            // A DEEP LINK CANNOT CARRY `extra`, so this is reachable with
            // nothing to play. Show the list rather than crash.
            if (extra is! QuizPlayTarget) {
              return ChangeNotifierProvider<QuizzesProvider>(
                create: (ctx) => QuizzesProvider(
                  firestore: ctx.read<FirestoreService>(),
                ),
                child: const QuizzesScreen(),
              );
            }

            return ChangeNotifierProvider<QuizPlayerProvider>(
              create: (ctx) => QuizPlayerProvider(
                firestore: ctx.read<FirestoreService>(),
                assignment: extra.assignment,
                teacherDocId: extra.teacherDocId,
                uid: extra.uid,
                classroomId: extra.classroomId,
                programmeId: extra.programmeId,
              ),
              child: const QuizPlayerScreen(),
            );
          },
        ),
        // An activity is TWO screens: what it is, and running it.
        //
        // `/lu/:id` is the overview a teacher lands on, and `/lu/:id/steps` the
        // player it hands over to. Nested, so back from a step returns to the
        // overview rather than all the way out to the classroom, and so the
        // path itself records which of the two a teacher is on.
        GoRoute(
          path: '/lu/:id',
          builder: (context, state) => _luScreen(
            state,
            (learningUnitId, workflowId, query) =>
                LearningUnitOverviewScreen(
                  learningUnitId: learningUnitId,
                  workflowId: workflowId,
                  // Progress is per classroom. Without one it can be shown but
                  // not recorded; see LearningUnitProvider.canRecordProgress.
                  classroomId: query['classroomId']?.trim(),
                  programmeId: query['programmeId']?.trim(),
                  breadcrumb: _breadcrumb(query),
                ),
          ),
          routes: [
            GoRoute(
              path: 'steps',
              builder: (context, state) => _luScreen(
                state,
                (learningUnitId, workflowId, query) => LearningUnitScreen(
                  learningUnitId: learningUnitId,
                  workflowId: workflowId,
                  // Both needed to address the evidence document, which is one
                  // per classroom+programme. Absent, the steps still work and
                  // only the evidence pane says it cannot be reached.
                  classroomId: query['classroomId']?.trim(),
                  programmeId: query['programmeId']?.trim(),
                  initialStep: int.tryParse(query['step'] ?? ''),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// The guard and the provider both activity screens need.
  ///
  /// SHARED, because the workflow check is the load-bearing half. The workflow
  /// id is a property of the CLASSROOM's binding rather than of the unit, so a
  /// link that arrives without one cannot be repaired by reading anything, and
  /// both screens have to refuse it the same way rather than one of them
  /// rendering an activity with no steps.
  static Widget _luScreen(
    GoRouterState state,
    Widget Function(
      String learningUnitId,
      String workflowId,
      Map<String, String> query,
    )
    build,
  ) {
    final learningUnitId = state.pathParameters['id']!;
    final query = state.uri.queryParameters;
    final workflowId = query['workflowId']?.trim() ?? '';
    if (workflowId.isEmpty) return const MissingWorkflowScreen();
    return ChangeNotifierProvider<LearningUnitProvider>(
      create: (ctx) =>
          LearningUnitProvider(firestore: ctx.read<FirestoreService>()),
      child: build(learningUnitId, workflowId, query),
    );
  }

  /// "test school oak Science Grade ET · 7 A", from what the caller already
  /// knew. Null when neither name travelled, so the header drops the line
  /// rather than drawing an empty one.
  static String? _breadcrumb(Map<String, String> query) {
    final parts = [
      query['classroomName']?.trim(),
      query['programmeName']?.trim(),
    ].whereType<String>().where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? null : parts.join(' \u00b7 ');
  }
}
