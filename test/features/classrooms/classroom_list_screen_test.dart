import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_list_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';
import 'package:tc_starter/features/classrooms/widgets/classroom_card.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

Teacher seededTeacher() => Teacher.fromMap('uid_1', {
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

List<Classroom> seededClassrooms() => [
  Classroom.fromMap('cls_oak_7a', {
    'classroomName': '7 A',
    'grade': 7,
    'section': 'A',
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

Future<void> pumpList(
  WidgetTester tester, {
  required FakeFirestoreService firestore,
  bool settle = true,
  Duration timeout = const Duration(seconds: 15),
  Size surfaceSize = const Size(360, 800),
}) {
  return pumpScreen(
    tester,
    settle: settle,
    surfaceSize: surfaceSize,
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => StubAuthProvider()),
      ChangeNotifierProvider<ClassroomProvider>(
        create: (_) =>
            ClassroomProvider(firestore: firestore, timeout: timeout),
      ),
    ],
    child: const ClassroomListScreen(),
  );
}

void main() {
  // Per test, not once: each test gets an independent localization state.
  setUp(initLocalizationForTest);

  testWidgets('renders a card per classroom, with the student count', (
    tester,
  ) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    expect(find.byType(ClassroomCard), findsNWidgets(2));
    expect(find.text('7 A'), findsOneWidget);
    expect(find.text('Oak ET Club'), findsOneWidget);
    // studentCounter comes from the authoritative document, not the teacher's
    // denormalised copy.
    expect(find.text('32 students'), findsOneWidget);
    expect(find.text('12 students'), findsOneWidget);
  });

  testWidgets('the ET club shows no grade and never the word null', (
    tester,
  ) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    expect(find.textContaining('null'), findsNothing);
    expect(find.textContaining('Grade 0'), findsNothing);
    // The 7 A card does show its grade.
    expect(find.textContaining('Grade 7'), findsOneWidget);
  });

  testWidgets('typing "oak" keeps both, because it matches the institution', (
    tester,
  ) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'oak');
    await tester.pumpAndSettle();

    // "7 A" contains no "oak"; it survives only because the search reaches the
    // institution.
    expect(find.byType(ClassroomCard), findsNWidgets(2));
  });

  testWidgets('typing a school-and-grade query narrows to one', (tester) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'oak 7');
    await tester.pumpAndSettle();

    expect(find.byType(ClassroomCard), findsOneWidget);
    expect(find.text('7 A'), findsOneWidget);
  });

  testWidgets('a query matching nothing says so, and keeps the search bar', (
    tester,
  ) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.byType(ClassroomCard), findsNothing);
    expect(find.text('No classrooms match'), findsOneWidget);
    // The teacher must be able to correct the query without leaving.
    expect(find.byType(TextField), findsOneWidget);
    // And must NOT be told they have no classrooms.
    expect(find.text('No classrooms yet'), findsNothing);
  });

  testWidgets('clearing the query brings the classrooms back', (tester) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();

    expect(find.byType(ClassroomCard), findsNWidgets(2));
  });

  testWidgets(
    'a teacher with no classrooms gets the empty state, no search bar',
    (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
      );

      expect(find.text('No classrooms yet'), findsOneWidget);
      expect(find.byType(ClassroomCard), findsNothing);
      // Nothing to filter, so the search bar would be furniture.
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('a failed load shows the error state with a working Retry', (
    tester,
  ) async {
    final firestore = FakeFirestoreService(throws: StateError('boom'));
    await pumpList(tester, firestore: firestore);

    expect(find.text('Could not load your classrooms'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(firestore.teacherReads, 1);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Retry actually retried.
    expect(firestore.teacherReads, 2);
  });

  testWidgets('a load that never answers ends in an error, not a spinner', (
    tester,
  ) async {
    // The acceptance check: wifi off must not leave a teacher watching a
    // spinner that never stops.
    await pumpList(
      tester,
      firestore: FakeFirestoreService(gate: Completer<void>()),
      timeout: const Duration(milliseconds: 50),
      settle: false,
    );

    // Spinner first.
    expect(find.byType(CircularProgressIndicator), findsWidgets);

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Could not load your classrooms'), findsOneWidget);
  });

  group('rotated to landscape', () {
    // Phase 6 asks for rotation on every screen. A phone on its side is
    // 800x360, and the design tokens scale `.w` against a 360-wide baseline, so
    // horizontal space triples while vertical space collapses. Anything laid
    // out as a fixed Column is where that shows up first.
    const landscape = Size(800, 360);

    testWidgets('the classroom list does not overflow', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: seededClassrooms(),
        ),
        surfaceSize: landscape,
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ClassroomCard), findsWidgets);
    });

    testWidgets('the empty state does not overflow', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
        surfaceSize: landscape,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('the no-matches state does not overflow', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: seededClassrooms(),
        ),
        surfaceSize: landscape,
      );
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the error state does not overflow', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(throws: StateError('boom')),
        surfaceSize: landscape,
      );

      expect(tester.takeException(), isNull);
    });
  });
}
