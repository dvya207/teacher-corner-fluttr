import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/widgets/tc_hero_stat_tile.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

Teacher seededTeacher() => Teacher.fromMap('uid_1', {
  'name': 'Intern Teacher',
  'teacherMeta': {
    'firstName': 'Divya',
    'lastName': 'Jain',
    'institutionName': 'Test School Oak',
  },
  'classrooms': {
    'cls_oak_7a': {
      'programmes': {
        'prog_tip_2026': {'displayName': 'TIP 2026'},
      },
    },
    'cls_oak_et': {
      'programmes': {
        'prog_tip_2026': {'displayName': 'TIP 2026'},
      },
    },
  },
});

Future<void> pumpDashboard(
  WidgetTester tester, {
  required FakeFirestoreService firestore,
  bool settle = true,
  Duration timeout = const Duration(seconds: 15),
  Size surfaceSize = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return pumpScreen(
    tester,
    settle: settle,
    surfaceSize: surfaceSize,
    textScaler: textScaler,
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => StubAuthProvider()),
      ChangeNotifierProvider<DashboardProvider>(
        create: (_) =>
            DashboardProvider(firestore: firestore, timeout: timeout),
      ),
    ],
    child: const DashboardScreen(),
  );
}

void main() {
  setUp(initLocalizationForTest);

  group('three visibly distinct states', () {
    testWidgets('loading shows a spinner and no content', (tester) async {
      final gate = Completer<void>();
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(gate: gate),
        settle: false,
        // Short, so the load's own timeout timer cannot outlive the widget
        // tree; the test framework fails on a pending timer at teardown.
        timeout: const Duration(milliseconds: 50),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      expect(find.byType(TcHeroStatTile), findsNothing);
      expect(find.text('Retry'), findsNothing);

      // Let the read finish so nothing is left in flight at teardown.
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('loaded shows the name, institution and both counts', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
      );

      // teacherMeta wins over the top-level "Intern Teacher".
      expect(find.text('Divya Jain'), findsOneWidget);
      expect(find.text('Test School Oak'), findsOneWidget);
      expect(find.byType(TcHeroStatTile), findsNWidgets(2));
      expect(find.text('Classrooms'), findsWidgets);
      expect(find.text('Programmes'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('error shows the message and a Retry that retries', (
      tester,
    ) async {
      final firestore = FakeFirestoreService(throws: StateError('boom'));
      await pumpDashboard(tester, firestore: firestore);

      expect(find.text('Could not load your dashboard'), findsOneWidget);
      expect(find.byType(TcHeroStatTile), findsNothing);
      expect(firestore.teacherReads, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(firestore.teacherReads, 2);
    });
  });

  group('the counts', () {
    testWidgets('count distinct programmes, not one per classroom', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
      );

      // Two classrooms, both running the same single programme.
      final tiles = tester
          .widgetList<TcHeroStatTile>(find.byType(TcHeroStatTile))
          .toList();
      expect(tiles.map((t) => t.value), ['2', '1']);
    });
  });

  group('signed in with nothing provisioned', () {
    testWidgets('says so plainly instead of showing zeros as a failure', (
      tester,
    ) async {
      await pumpDashboard(tester, firestore: FakeFirestoreService());

      expect(
        find.textContaining('no teacher profile has been set up'),
        findsOneWidget,
      );
      // Not the error state: retrying cannot fix it.
      expect(find.text('Could not load your dashboard'), findsNothing);
      expect(find.text('Retry'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  group('surviving the device', () {
    testWidgets('does not overflow in landscape', (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
        surfaceSize: const Size(800, 360),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at the maximum system font size', (
      tester,
    ) async {
      // The clamp in text_scaling.dart caps the system contribution at 1.3x, so
      // this is the largest the layout ever has to survive.
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
        textScaler: const TextScaler.linear(3.0),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Divya Jain'), findsOneWidget);
    });

    testWidgets('a long name and institution do not overflow', (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'teacherMeta': {
              'firstName': 'Lakshmi Priyadarshini',
              'lastName': 'Venkataraghavan Subramanian',
              'institutionName':
                  'Government Higher Secondary School for Girls, Thiruvananthapuram North',
            },
          }),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
