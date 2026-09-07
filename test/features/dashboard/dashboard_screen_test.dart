import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/widgets/tc_hero_stat_tile.dart';
import 'package:tc_starter/features/dashboard/widgets/dashboard_classroom_row.dart';
import 'package:tc_starter/features/dashboard/widgets/school_card.dart';
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
  // The two classrooms as seed.js writes them, so the rows the dashboard now
  // renders have real names rather than falling back to ids.
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

List<Classroom> authoritativeClassrooms() => [
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

      // teacherMeta wins over the top-level "Intern Teacher", and the greeting
      // uses the FIRST name only: "Good afternoon, Divya Jain" reads like a
      // letter from an institution. Matched on a fragment because the rest of
      // the line is the time of day, which changes through the day.
      expect(find.textContaining('Divya'), findsWidgets);
      expect(find.text('Divya Jain'), findsNothing);
      // Twice now, and correctly so: once as the hero subtitle and once on the
      // ET club's card, whose subtitle is the institution alone because that
      // classroom has no grade or section.
      expect(find.text('Test School Oak'), findsWidgets);
      // THREE tiles, always. The row is a fixed shape rather than one that
      // grows a slot when a number happens to be knowable.
      expect(find.byType(TcHeroStatTile), findsNWidgets(3));
      expect(find.text('Classes'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
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

      // Two classrooms, both running the same single programme. No
      // authoritative documents were readable, so the student total is not
      // knowable and says so rather than claiming zero.
      final tiles = tester
          .widgetList<TcHeroStatTile>(find.byType(TcHeroStatTile))
          .toList();
      expect(tiles.map((t) => t.value), ['2', '–', '1']);
    });
  });

  group('the hero totals across every school', () {
    testWidgets('counts all the classrooms, not just the named school\'s', (
      tester,
    ) async {
      // The teacher's own institution is one of four. The hero answers "how
      // much am I carrying", which is a question about the teacher rather than
      // about a building, so all four count. The per-school split is the
      // schools section below.
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'teacherMeta': {
              'firstName': 'Divya',
              'institutionName': 'Beacon Hill',
            },
            'classrooms': {
              'a': {
                'classroomName': '8 D',
                'institutionName': 'Beacon Hill',
                'programmes': {
                  'prg_one': {'displayName': 'One'},
                },
              },
              'b': {
                'classroomName': '4 D',
                'institutionName': 'Jnana Syhadri',
                'programmes': {
                  'prg_two': {'displayName': 'Two'},
                },
              },
              'c': {
                'classroomName': '1 A',
                'institutionName': 'Dayananda Sagar',
                'programmes': {
                  'prg_two': {'displayName': 'Two'},
                  'prg_three': {'displayName': 'Three'},
                },
              },
            },
          }),
        ),
      );

      final tiles = tester
          .widgetList<TcHeroStatTile>(find.byType(TcHeroStatTile))
          .toList();
      // Three classrooms across three schools, and three DISTINCT programmes:
      // "Two" runs at two of them and is one programme, not two.
      expect(tiles.first.value, '3');
      expect(tiles.last.value, '3');
    });

    testWidgets('every school gets a row, counting only its own', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'teacherMeta': {'firstName': 'Divya'},
            'classrooms': {
              'a': {'classroomName': '1 A', 'institutionName': 'Dayananda'},
              'b': {'classroomName': '2 B', 'institutionName': 'Dayananda'},
              'c': {'classroomName': '4 D', 'institutionName': 'Jnana'},
            },
          }),
        ),
      );

      // Asserted on the cards themselves, not on find.text: a school's name
      // also appears in the hero subtitle and in every classroom row that
      // names it, so a bare text search counts four "Dayananda"s and proves
      // nothing about this section.
      final cards = tester.widgetList<SchoolCard>(find.byType(SchoolCard));
      expect(cards.map((c) => c.school.name), ['Dayananda', 'Jnana']);
      expect(cards.map((c) => c.school.classroomCount), [2, 1]);
    });
  });

  group('signed in with no teaching record linked', () {
    testWidgets('says so plainly instead of showing zeros as a failure', (
      tester,
    ) async {
      await pumpDashboard(tester, firestore: FakeFirestoreService());

      // Names the ACTIONABLE fact: an administrator has to register this
      // number. The old copy said the profile had not been "set up", which
      // pointed the teacher at a setting that does not exist.
      expect(
        find.textContaining('no teacher record is linked to this number'),
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
      expect(find.textContaining('Divya'), findsWidgets);
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

  group('the classrooms section', () {
    testWidgets('lists the classrooms, reading the teacher once and the '
        'classroom documents once', (tester) async {
      // The contract CHANGED here, deliberately. It used to be one read, and
      // the dashboard showed no student count as a result. studentCounter lives
      // only on the authoritative documents, so showing it costs a second,
      // batched round of reads. Recorded rather than assumed, so an accidental
      // read-per-row would fail this.
      final fake = FakeFirestoreService(
        teacher: seededTeacher(),
        classrooms: authoritativeClassrooms(),
      );
      await pumpDashboard(tester, firestore: fake);

      expect(find.byType(DashboardClassroomRow), findsNWidgets(2));
      expect(find.text('7 A'), findsOneWidget);
      expect(find.text('Oak ET Club'), findsOneWidget);
      expect(fake.teacherReads, 1);
      expect(fake.classroomReads, 1);
    });

    testWidgets('totals the students across the classrooms', (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: authoritativeClassrooms(),
        ),
      );

      // 32 + 12.
      expect(find.text('Students'), findsOneWidget);
      expect(find.text('44'), findsOneWidget);
    });

    testWidgets('gives each row its school and programmes on one line', (
      tester,
    ) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: authoritativeClassrooms(),
        ),
      );

      // ONE LINE, school then programmes, unlike the classrooms screen where
      // each gets a line of its own. Three of these rows sit above a schools
      // section here, so the row trades detail for height.
      expect(find.text('Test School Oak · TIP 2026'), findsNWidgets(2));
      // Per-row student counts are not on the dashboard at all: the hero
      // already totals them, and repeating the parts under the sum is noise.
      expect(find.textContaining('students'), findsNothing);
    });

    testWidgets('a failed classroom read costs the total, not the screen',
        (tester) async {
      // The second round of reads is an enhancement. Losing it must not lose
      // the teacher's name, institution or counts.
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          throwsOnClassroom: StateError('permission denied'),
        ),
      );

      expect(find.textContaining('Divya'), findsWidgets);
      expect(find.text('Classes'), findsOneWidget);
      expect(find.byType(DashboardClassroomRow), findsNWidgets(2));
      // No partial total: one missing document would make any sum understate
      // the real figure while looking exact. The tile STAYS, because its slot
      // is part of a fixed three-tile row, and reports that it does not know.
      expect(find.text('Students'), findsOneWidget);
      final students = tester
          .widgetList<TcHeroStatTile>(find.byType(TcHeroStatTile))
          .elementAt(1);
      expect(students.value, '–');
      expect(find.textContaining('students'), findsNothing);
    });

    testWidgets('a classroom whose count is unknown suppresses the total',
        (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          // Only one of the two authoritative documents is readable.
          classrooms: [authoritativeClassrooms().first],
        ),
      );

      // The tile is still there and still refuses to guess.
      expect(find.text('Students'), findsOneWidget);
      final students = tester
          .widgetList<TcHeroStatTile>(find.byType(TcHeroStatTile))
          .elementAt(1);
      expect(students.value, '–');
      // And no row quietly reports the half of the data that did load.
      expect(find.textContaining('students'), findsNothing);
    });

    testWidgets('no classrooms means zero students, which is a fact',
        (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'teacherMeta': {'firstName': 'Divya', 'lastName': 'Jain'},
          }),
        ),
      );

      expect(find.text('Students'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
    });

    testWidgets('omits a row\'s count when that document is missing',
        (tester) async {
      // Rewritten, not deleted: the dashboard DOES read the authoritative
      // documents now, but a row whose document is absent must still omit the
      // line rather than render zero.
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
      );

      expect(find.textContaining('students'), findsNothing);
      expect(find.textContaining('null'), findsNothing);
      expect(find.byType(DashboardClassroomRow), findsNWidgets(2));
    });

    testWidgets('no longer renders a heading with nothing under it',
        (tester) async {
      // The bug: a "Classrooms" section label above empty space, which read as
      // unfinished rather than as scoped.
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
      );

      expect(find.byType(DashboardClassroomRow), findsWidgets);
    });

    testWidgets('a teacher with no classrooms gets an empty state',
        (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'teacherMeta': {'firstName': 'Divya', 'lastName': 'Jain'},
          }),
        ),
      );

      expect(find.text('No classrooms yet'), findsOneWidget);
      expect(find.byType(DashboardClassroomRow), findsNothing);
      // And no schools heading above empty space: with no classrooms there are
      // no schools to derive, and a second panel repeating the empty state
      // would only make the screen look broken.
      expect(find.text('MY SCHOOLS'), findsNothing);
      expect(find.byType(SchoolCard), findsNothing);
    });

    testWidgets('caps the rows and offers See all when there are more',
        (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: Teacher.fromMap('uid_1', {
            'classrooms': {
              for (var i = 0; i < 5; i++)
                'cls_$i': {'classroomName': 'Class $i'},
            },
          }),
        ),
      );

      // A dashboard is a place to start from; past a few rows the searchable
      // tab is the better tool.
      expect(find.byType(DashboardClassroomRow), findsNWidgets(3));
      // One "See all", not two: these classrooms name no school, so there is
      // no schools section under them to carry a second.
      expect(find.text('See all'), findsOneWidget);
    });

    testWidgets('offers See all on both sections, even when everything fits',
        (tester) async {
      // THE RULE CHANGED. "See all" used to appear only once a fourth
      // classroom existed, which made the section header change shape
      // according to data the teacher cannot see the size of, and left the
      // schools section below carrying an affordance its twin above lacked.
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
      );

      expect(find.byType(DashboardClassroomRow), findsNWidgets(2));
      expect(find.byType(SchoolCard), findsOneWidget);
      expect(find.text('See all'), findsNWidgets(2));
    });

    testWidgets('groups the classrooms into the schools that name them',
        (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(
          teacher: seededTeacher(),
          classrooms: authoritativeClassrooms(),
        ),
      );

      // Both classrooms are at one school, so one row, and it counts the
      // programme ONCE though two classrooms run it: a school running the same
      // programme in two classes runs one programme.
      expect(find.byType(SchoolCard), findsOneWidget);
      expect(find.text('2 classrooms · 1 programme'), findsOneWidget);
    });

    testWidgets('the section survives landscape and the font ceiling',
        (tester) async {
      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
        surfaceSize: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);

      await pumpDashboard(
        tester,
        firestore: FakeFirestoreService(teacher: seededTeacher()),
        textScaler: const TextScaler.linear(3.0),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
