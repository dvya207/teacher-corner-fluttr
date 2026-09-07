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
  TextScaler textScaler = TextScaler.noScaling,
  String? initialQuery,
}) {
  return pumpScreen(
    tester,
    settle: settle,
    surfaceSize: surfaceSize,
    textScaler: textScaler,
    providers: [
      ChangeNotifierProvider<AuthProvider>(create: (_) => StubAuthProvider()),
      ChangeNotifierProvider<ClassroomProvider>(
        create: (_) =>
            ClassroomProvider(firestore: firestore, timeout: timeout),
      ),
    ],
    child: ClassroomListScreen(initialQuery: initialQuery),
  );
}

void main() {
  // Per test, not once: each test gets an independent localization state.
  setUp(initLocalizationForTest);

  testWidgets('renders a card per classroom, naming its school and programmes', (
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
    // The school gets its own line on every row. Both classrooms are at the
    // same one, and it is repeated rather than grouped: this list is scanned
    // for a single classroom, and a row that does not name its school is
    // ambiguous the moment a teacher works at two.
    expect(find.text('Test School Oak'), findsNWidgets(2));
    // Programmes as a count rather than names. Both run TIP 2026 alone, so
    // both read "1 Programme" and neither says "1 Programmes".
    expect(find.text('1 Programme'), findsNWidgets(2));
    // The student count left this row deliberately. It is a fact ABOUT a
    // classroom rather than a way to recognise one, and it is still on the
    // classroom's own screen. `studentCounter` is loaded here regardless,
    // because the search and the detail screen both want it.
    expect(find.textContaining('students'), findsNothing);
  });

  testWidgets('no row shows a grade, and none ever shows the word null', (
    tester,
  ) async {
    await pumpList(
      tester,
      firestore: FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: seededClassrooms(),
      ),
    );

    // The ET club's `grade` is the String "ET", which SafeParse turns into
    // null. That null must never reach a teacher, whatever the row happens to
    // render this month.
    expect(find.textContaining('null'), findsNothing);
    // The grade left the row along with the student count. It duplicated the
    // name in this data: "7 A" IS the classroom's name, and "Grade 7 · A"
    // said it a second time. Dropping it is what let the school move up to its
    // own line.
    expect(find.textContaining('Grade'), findsNothing);
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

  group('arriving with a search already typed', () {
    // How a school row on the dashboard opens "its" classrooms. There is no
    // schools screen, so tapping one seeds the search that already matches on
    // institution rather than building a second, narrower list beside it.

    testWidgets('a school name filters the list on arrival', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'classrooms': {
              'cls_oak': {
                'classroomName': '7 A',
                'institutionName': 'Test School Oak',
              },
              'cls_airaa': {
                'classroomName': '4 A',
                'institutionName': 'Airaa Academy',
              },
            },
          }),
        ),
        initialQuery: 'Airaa Academy',
      );

      expect(find.byType(ClassroomCard), findsOneWidget);
      expect(find.text('4 A'), findsOneWidget);
      expect(find.text('7 A'), findsNothing);
    });

    testWidgets('the term is in the search bar, and can be cleared', (
      tester,
    ) async {
      // A SUGGESTION, NOT A LOCK. The teacher has to be able to see why the
      // list is short and undo it without leaving the screen, which is the
      // whole reason this seeds the existing search instead of applying a
      // filter of its own.
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: seededClassrooms(),
        ),
        initialQuery: 'Oak ET Club',
      );

      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'Oak ET Club',
      );
      expect(find.byType(ClassroomCard), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pumpAndSettle();

      expect(find.byType(ClassroomCard), findsNWidgets(2));
    });

    testWidgets('seeding survives the load that clears the previous query', (
      tester,
    ) async {
      // The ordering trap. `load` wipes the query synchronously before its
      // first await, so seeding before it would leave the teacher looking at
      // an unfiltered list with text sitting in the search bar.
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: seededClassrooms(),
        ),
        initialQuery: 'zzzz',
      );

      expect(find.text('No classrooms match'), findsOneWidget);
    });

    testWidgets('no query behaves exactly as arriving from the tab', (
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
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '',
      );
    });
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

  group('at the maximum system font size', () {
    // clampTextScaler caps the system contribution at 1.3x, so this is the
    // largest the layout ever has to survive.
    testWidgets('the list does not overflow or clip its cards', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: seededClassrooms(),
        ),
        textScaler: const TextScaler.linear(3.0),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(ClassroomCard), findsNWidgets(2));
      expect(find.text('7 A'), findsOneWidget);
    });

    testWidgets('the empty state does not overflow', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
        textScaler: const TextScaler.linear(3.0),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a long institution name still fits', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'classrooms': {
              'cls_long': {
                'classroomName': '7 A',
                'grade': 7,
                'section': 'A',
                'institutionName': 'Government Higher Secondary School for '
                    'Girls, Thiruvananthapuram North',
              },
            },
          }),
        ),
        textScaler: const TextScaler.linear(3.0),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
