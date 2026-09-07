import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/router/app_router.dart';
import 'package:tc_starter/core/services/firestore_service.dart';
import 'package:tc_starter/core/theme/app_theme.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_screen.dart';
import 'package:tc_starter/features/quizzes/quiz_player_provider.dart';
import 'package:tc_starter/features/quizzes/quiz_player_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

/// Opening a quiz from a WORKFLOW STEP, across the bottom-nav shell boundary.
///
/// WHY THIS EXISTS. On a device this threw "A GlobalKey was used multiple times
/// inside one widget's child list" and painted the red error screen instead of
/// the player. Nothing in the suite caught it, because every other navigation
/// test builds its own small router (see `pumpShell`) rather than the real one,
/// and the fault is in how the REAL router's routes are nested.
///
/// The activity player at `/lu/:id/steps` is a TOP-LEVEL route, deliberately
/// outside the shell. The quiz player used to be nested INSIDE the shell, under
/// `/quizzes`. Pushing the second from the first therefore asked go_router to
/// build the shell's Navigator underneath a route that was already mounted on
/// the root one, and two Navigators cannot share a GlobalKey.
///
/// This test drives the real router, so it fails if the player is ever moved
/// back inside the shell.
void main() {
  setUp(initLocalizationForTest);

  /// Pumps until [ready] holds, or gives up after [frames].
  ///
  /// NOT `pumpAndSettle`, which never returns on these screens: the activity
  /// player shows a CircularProgressIndicator while it loads and an endless
  /// animation is exactly what pumpAndSettle waits for. This is the same reason
  /// `pumpScreen(settle: false)` exists in the shared harness.
  ///
  /// NOT A FIXED NUMBER OF PUMPS EITHER, which is what this test did first and
  /// why it failed once in a full parallel run while passing every time on its
  /// own: two frames is enough on an idle machine and not always enough on a
  /// loaded one, so the test was timing-dependent rather than deterministic.
  /// Waiting on the CONDITION removes the timing from it.
  Future<void> pumpUntil(
    WidgetTester tester,
    bool Function() ready, {
    int frames = 60,
  }) async {
    for (var i = 0; i < frames && !ready(); i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  Future<void> pumpRealRouter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final firestore = FakeFirestoreService();
    final auth = StubAuthProvider();
    final refresh = ChangeNotifier();

    final router = AppRouter.router(
      refreshListenable: refresh,
      isAuthenticated: () => true,
      isAuthLoaded: () => true,
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<FirestoreService>.value(value: firestore),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(firestore: firestore),
          ),
          ChangeNotifierProvider<ClassroomProvider>(
            create: (_) => ClassroomProvider(firestore: firestore),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(360, 800),
          minTextAdapt: true,
          fontSizeResolver: FontSizeResolvers.width,
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            debugShowCheckedModeBanner: false,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await pumpUntil(tester, () => find.byType(Navigator).evaluate().isNotEmpty);
  }

  testWidgets(
    'a quiz opens from a workflow step, which is outside the bottom-nav shell',
    (tester) async {
      await pumpRealRouter(tester);

      final context = tester.element(find.byType(Navigator).first);

      // Onto the activity player: a TOP-LEVEL route, outside the shell. This is
      // where a teacher taps "Open Quiz" from a step.
      GoRouter.of(context).push(
        '/lu/lu_1/steps?workflowId=wf_1&classroomId=c1&programmeId=p1',
      );
      await tester.pump();
      await pumpUntil(
        tester,
        () => find.byType(LearningUnitScreen).evaluate().isNotEmpty,
      );

      // Now the push that crashed: the quiz player, reached from outside the
      // shell it used to live inside.
      GoRouter.of(context).push(
        '/quizzes/play',
        extra: QuizPlayTarget(
          assignment: const Assignment(
            docId: 'a1',
            displayName: 'Quizzzz',
            type: 'QUIZ',
          ),
          teacherDocId: 't1',
          uid: 'uid-1',
          classroomId: 'c1',
          programmeId: 'p1',
        ),
      );
      await tester.pump();
      // WAITS ON THE WIDGET ALONE, and deliberately not on `takeException()`:
      // that call CONSUMES the exception, so testing it here would swallow the
      // very duplicate-GlobalKey error the assertion below exists to report and
      // the test would pass while the bug was live. When the build does throw,
      // the player never appears, this loop simply runs out its frames, and the
      // exception is still there to be found. The frames are virtual, so
      // exhausting them costs no real time.
      await pumpUntil(
        tester,
        () => find.byType(QuizPlayerScreen).evaluate().isNotEmpty,
      );

      // The whole point. A duplicate-GlobalKey build throws here rather than
      // returning, so this assertion is what the red screen looked like.
      expect(
        tester.takeException(),
        isNull,
        reason: 'pushing the quiz player from a top-level route must not '
            'rebuild the shell Navigator',
      );
      expect(find.byType(QuizPlayerScreen), findsOneWidget);
    },
  );
}
