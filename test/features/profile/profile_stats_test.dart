import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/core/models/teacher_profile.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/profile/profile_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

/// The profile screen's two stat tiles.
///
/// The rule under test: the tiles are part of the screen's SHAPE, so both render
/// for every state of the account. A stat that disappears reads as a broken
/// layout; a zero reads as "none yet". The classroom count must also not depend
/// on the dashboard tab having been opened first, which is exactly what the old
/// implementation did by reading `DashboardProvider.studentTotal`.

/// A teaching record with [count] classrooms, shaped as `teacher-corner-dev`
/// shapes one: client-allocated document id, uid on `teacherMeta`, school
/// denormalised onto each classroom, programmes as an array.
Teacher teachingWith(int count, {String uid = 'uid_any_000000000000001'}) =>
    Teacher.fromMap('tch_any_doc', {
      'teacherMeta': {'uid': uid, 'firstName': 'Any', 'lastName': 'Teacher'},
      'classrooms': {
        for (var i = 0; i < count; i++)
          'cls_$i': {
            'classroomId': 'cls_$i',
            'classroomName': 'Class $i',
            'type': 'CLASSROOM',
            'institutionName': 'Some School',
            'programmes': [
              {'programmeId': 'prg_$i', 'displayName': 'Programme $i'},
            ],
          },
      },
    });

Future<void> pumpProfile(WidgetTester tester, {TeacherAccount? account}) =>
    pumpScreen(
      tester,
      child: const ProfileScreen(),
      // ONLY AuthProvider. No DashboardProvider is supplied, deliberately: if
      // this screen ever reaches for one again, these tests fail with a
      // ProviderNotFoundException instead of silently regressing.
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(stubAccount: account),
        ),
      ],
    );

/// The value rendered on the stat tile whose label is [label].
///
/// Located by walking up from the label to the card it shares with its value,
/// rather than by index, so reordering the row does not silently pass.
String statValue(WidgetTester tester, String label) {
  final labelFinder = find.text(label);
  expect(labelFinder, findsOneWidget, reason: 'no "$label" tile on screen');

  final card =
      find.ancestor(of: labelFinder, matching: find.byType(Column)).first;
  final values = tester
      .widgetList<Text>(find.descendant(of: card, matching: find.byType(Text)))
      .map((t) => t.data)
      .whereType<String>()
      .where((t) => t != label)
      .toList();

  expect(values, isNotEmpty, reason: 'no value beside "$label"');
  return values.first;
}

void main() {
  setUp(initLocalizationForTest);

  group('both tiles always render', () {
    testWidgets('a linked teacher sees their classroom count and 0 students',
        (tester) async {
      await pumpProfile(
        tester,
        account: TeacherAccount(
          uid: 'uid_any_000000000000001',
          profile: TeacherProfile.fromMap('uid_any_000000000000001', {
            'firstName': 'Any',
            'lastName': 'Teacher',
            'institutionName': 'Some School',
          }),
          teaching: teachingWith(3),
        ),
      );

      expect(statValue(tester, 'Classrooms'), '3');
      expect(statValue(tester, 'Students'), '0');
    });

    testWidgets('one classroom renders as 1', (tester) async {
      await pumpProfile(
        tester,
        account: TeacherAccount(
          uid: 'uid_any_000000000000001',
          teaching: teachingWith(1),
        ),
      );

      expect(statValue(tester, 'Classrooms'), '1');
      expect(statValue(tester, 'Students'), '0');
    });

    testWidgets('an unlinked teacher still sees both tiles, at 0',
        (tester) async {
      // Authenticated, no `teachers` record. The not-linked banner explains it;
      // the tiles must not vanish on top of that.
      await pumpProfile(
        tester,
        account: const TeacherAccount(uid: 'uid_unlinked_00000000001'),
      );

      expect(statValue(tester, 'Classrooms'), '0');
      expect(statValue(tester, 'Students'), '0');
      expect(
        find.textContaining('No teacher record is linked to this number'),
        findsOneWidget,
      );
    });

    testWidgets('a null account, before the load finishes, still has the tiles',
        (tester) async {
      await pumpProfile(tester);

      expect(statValue(tester, 'Classrooms'), '0');
      expect(statValue(tester, 'Students'), '0');
    });
  });

  group('the screen stands on its own', () {
    testWidgets('renders with no DashboardProvider in the tree at all',
        (tester) async {
      // The regression this guards: the tiles used to read
      // DashboardProvider.studentTotal, so Profile only worked once the
      // dashboard tab had been opened, and the students tile disappeared
      // whenever that total was unknown.
      await pumpProfile(
        tester,
        account: TeacherAccount(
          uid: 'uid_any_000000000000001',
          teaching: teachingWith(2),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(statValue(tester, 'Classrooms'), '2');
      expect(statValue(tester, 'Students'), '0');
    });

    // TWO TESTS, NOT ONE WITH TWO PUMPS. Pumping the same widget type twice
    // reuses the provider's element, so `create` does not run again and the
    // second account never reaches the screen — the assertion passes against
    // the FIRST teacher's data. Separate tests get separate trees.
    testWidgets('teacher A sees four classrooms', (tester) async {
      await pumpProfile(
        tester,
        account: TeacherAccount(
          uid: 'uid_a_00000000000000001',
          teaching: teachingWith(4, uid: 'uid_a_00000000000000001'),
        ),
      );
      expect(statValue(tester, 'Classrooms'), '4');
    });

    testWidgets('teacher B sees one classroom, from the same widget',
        (tester) async {
      await pumpProfile(
        tester,
        account: TeacherAccount(
          uid: 'uid_b_00000000000000002',
          teaching: teachingWith(1, uid: 'uid_b_00000000000000002'),
        ),
      );
      expect(statValue(tester, 'Classrooms'), '1');
    });
  });
}
