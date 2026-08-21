import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/auth/login_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_list_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_screen.dart';
import 'package:tc_starter/features/profile/profile_screen.dart';
import 'package:tc_starter/features/splash/splash_screen.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

/// Renders every screen and state to a PNG under `test/golden/goldens/`.
///
/// Regenerate with:
///   flutter test --update-goldens test/golden/screens_golden_test.dart
///
/// These are for LOOKING at. They are rendered against fake data on a 360x800
/// surface, so they show layout, type and colour, and they prove nothing about
/// whether the real reads work.
Teacher aTeacher() => Teacher.fromMap('uid_1', {
      'name': 'Intern Teacher',
      'teacherMeta': {
        'firstName': 'Divya',
        'lastName': 'Jain',
        'institutionName': 'Test School Oak',
        'designation': 'Teacher',
      },
      'classrooms': {
        'cls_oak_7a': {
          'classroomName': '7 A',
          'type': 'CLASSROOM',
          'grade': 7,
          'section': 'A',
          'institutionName': 'Test School Oak',
          'programmes': {
            'prog_tip_2026': {'displayName': 'TIP 2026'},
          },
        },
        'cls_oak_et': {
          'stemClubName': 'Oak ET Club',
          'type': 'STEM-CLUB',
          'grade': 'ET',
          'institutionName': 'Test School Oak',
          'programmes': {
            'prog_tip_2026': {'displayName': 'TIP 2026'},
          },
        },
      },
    });

List<Classroom> theClassrooms() => [
      Classroom.fromMap('cls_oak_7a', {
        'classroomName': '7 A',
        'grade': 7,
        'section': 'A',
        'board': 'CBSE',
        'institutionName': 'Test School Oak',
        'studentCounter': 32,
      }),
      Classroom.fromMap('cls_oak_et', {
        'stemClubName': 'Oak ET Club',
        'type': 'STEM-CLUB',
        'grade': 'ET',
        'institutionName': 'Test School Oak',
        'studentCounter': 12,
      }),
    ];

void main() {
  setUpAll(loadAppFonts);
  setUp(initLocalizationForTest);

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('auth', () {
    testWidgets('splash', (tester) async {
      await pumpScreen(tester, child: const SplashScreen(), settle: false);
      // Let the spinner sweep, so the image shows an arc rather than the dot it
      // is on its very first frame.
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, '01_splash');
    });

    testWidgets('login, entering a number', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => StubAuthProvider()),
        ],
        child: const LoginScreen(),
      );
      await shoot(tester, '02_login_phone');
    });

    testWidgets('login, entering the code', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(
              stubStage: LoginStage.codeEntry,
              stubPendingPhone: '+919999900000',
            ),
          ),
        ],
        child: const LoginScreen(),
      );
      await shoot(tester, '03_login_code');
    });

    testWidgets('login, showing a wrong-code error', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(
              stubStage: LoginStage.codeEntry,
              stubPendingPhone: '+919999900000',
              stubErrorKey: 'auth.error_invalid_code',
            ),
          ),
        ],
        child: const LoginScreen(),
      );
      await shoot(tester, '04_login_error');
    });
  });

  group('dashboard', () {
    Future<void> pumpDash(
      WidgetTester tester, {
      required FakeFirestoreService firestore,
      bool settle = true,
      Duration timeout = const Duration(seconds: 15),
    }) =>
        pumpScreen(
          tester,
          settle: settle,
          providers: [
            ChangeNotifierProvider<AuthProvider>(
                create: (_) => StubAuthProvider()),
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) =>
                  DashboardProvider(firestore: firestore, timeout: timeout),
            ),
          ],
          child: const DashboardScreen(),
        );

    testWidgets('loading', (tester) async {
      final gate = Completer<void>();
      await pumpDash(
        tester,
        firestore: FakeFirestoreService(gate: gate),
        settle: false,
        timeout: const Duration(seconds: 5),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, '05_dashboard_loading');
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('loaded', (tester) async {
      await pumpDash(tester, firestore: FakeFirestoreService(teacher: aTeacher()));
      await shoot(tester, '06_dashboard_loaded');
    });

    testWidgets('error', (tester) async {
      await pumpDash(
        tester,
        firestore: FakeFirestoreService(throws: StateError('boom')),
      );
      await shoot(tester, '07_dashboard_error');
    });

    testWidgets('signed in, no profile provisioned', (tester) async {
      await pumpDash(tester, firestore: FakeFirestoreService());
      await shoot(tester, '08_dashboard_no_profile');
    });
  });

  group('classrooms', () {
    Future<void> pumpList(
      WidgetTester tester, {
      required FakeFirestoreService firestore,
      Size surfaceSize = const Size(360, 800),
    }) =>
        pumpScreen(
          tester,
          surfaceSize: surfaceSize,
          providers: [
            ChangeNotifierProvider<AuthProvider>(
                create: (_) => StubAuthProvider()),
            ChangeNotifierProvider<ClassroomProvider>(
              create: (_) => ClassroomProvider(firestore: firestore),
            ),
          ],
          child: const ClassroomListScreen(),
        );

    FakeFirestoreService populated() => FakeFirestoreService(
          teacher: aTeacher(),
          classrooms: theClassrooms(),
        );

    testWidgets('the list', (tester) async {
      await pumpList(tester, firestore: populated());
      await shoot(tester, '09_classrooms_list');
    });

    testWidgets('searching by school', (tester) async {
      await pumpList(tester, firestore: populated());
      await tester.enterText(find.byType(TextField), 'oak 7');
      await tester.pumpAndSettle();
      await shoot(tester, '10_classrooms_search');
    });

    testWidgets('search matching nothing', (tester) async {
      await pumpList(tester, firestore: populated());
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      await shoot(tester, '11_classrooms_no_matches');
    });

    testWidgets('a teacher with no classrooms', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
      );
      await shoot(tester, '12_classrooms_empty');
    });

    testWidgets('failed to load', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(throws: StateError('boom')),
      );
      await shoot(tester, '13_classrooms_error');
    });

    testWidgets('the empty state in landscape, after the overflow fix',
        (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
        surfaceSize: const Size(800, 360),
      );
      await shoot(tester, '14_classrooms_empty_landscape');
    });
  });

  group('profile', () {
    testWidgets('with a loaded teacher', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(stubTeacher: aTeacher()),
          ),
        ],
        child: const ProfileScreen(),
      );
      await shoot(tester, '15_profile');
    });
  });
}
