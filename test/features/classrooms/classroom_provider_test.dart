import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/classroom_ref.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/features/classrooms/classroom_list_item.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';

import '../../support/fakes.dart';

Teacher teacherWithBothSeededClassrooms() => Teacher.fromMap('uid_1', {
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

void main() {
  group('merging the two descriptions of a classroom', () {
    test('takes the student count from the authoritative document', () {
      // The teacher's denormalised copy has no studentCounter at all, which is
      // why the list cannot be built from it alone.
      final ref = ClassroomRef.fromMap('cls_oak_7a', {
        'classroomName': '7 A',
        'institutionName': 'Test School Oak',
      });
      final full = Classroom.fromMap('cls_oak_7a', {'studentCounter': 32});

      final item = ClassroomListItem.merge(ref: ref, full: full);

      expect(item.studentCounter, 32);
      // And keeps the institution the authoritative document left blank.
      expect(item.institutionName, 'Test School Oak');
      expect(item.hasAuthoritativeDoc, isTrue);
    });

    test('still renders a row when the authoritative document is missing', () {
      // A teacher document can reference a classroom whose real document has
      // been deleted. The row degrades; it does not disappear.
      final ref = ClassroomRef.fromMap('cls_gone', {
        'classroomName': '9 C',
        'institutionName': 'Test School Oak',
      });

      final item = ClassroomListItem.merge(ref: ref, full: null);

      expect(item.displayName, '9 C');
      expect(item.institutionName, 'Test School Oak');
      expect(item.studentCounter, isNull);
      expect(item.hasAuthoritativeDoc, isFalse);
    });
  });

  group('loading', () {
    test('builds one row per classroom, with counts', () async {
      final provider = ClassroomProvider(
        firestore: FakeFirestoreService(
          teacher: teacherWithBothSeededClassrooms(),
          classrooms: authoritativeClassrooms(),
        ),
      );

      await provider.load('uid_1');

      expect(provider.status, ClassroomListStatus.loaded);
      expect(provider.all, hasLength(2));
      expect(provider.all.map((c) => c.studentCounter), containsAll([32, 12]));
      // The ET club keeps its name and gains no fake grade.
      final club = provider.all.firstWhere((c) => c.isStemClub);
      expect(club.displayName, 'Oak ET Club');
      expect(club.gradeSectionLabel, isNull);
    });

    test('a teacher with no classrooms is empty, not an error', () async {
      final fake = FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {}));
      final provider = ClassroomProvider(firestore: fake);

      await provider.load('uid_1');

      expect(provider.status, ClassroomListStatus.loaded);
      expect(provider.isEmpty, isTrue);
      expect(provider.hasNoMatches, isFalse);
      // No ids to look up, so no second round of reads was issued.
      expect(fake.classroomReads, 0);
    });

    test('a thrown read becomes the error state', () async {
      final provider = ClassroomProvider(
        firestore: FakeFirestoreService(throws: StateError('boom')),
      );

      await provider.load('uid_1');

      expect(provider.status, ClassroomListStatus.error);
      expect(provider.errorKey, 'classrooms.error_generic');
    });

    test('a read that never answers times out', () async {
      final gate = Completer<void>();
      final provider = ClassroomProvider(
        firestore: FakeFirestoreService(gate: gate),
        timeout: const Duration(milliseconds: 20),
      );

      await provider.load('uid_1');

      expect(provider.status, ClassroomListStatus.error);
      expect(provider.errorKey, 'classrooms.error_offline');
      gate.complete();
    });
  });

  group('searching', () {
    Future<ClassroomProvider> loaded() async {
      final provider = ClassroomProvider(
        firestore: FakeFirestoreService(
          teacher: teacherWithBothSeededClassrooms(),
          classrooms: authoritativeClassrooms(),
        ),
      );
      await provider.load('uid_1');
      return provider;
    }

    test('never touches the network', () async {
      final fake = FakeFirestoreService(
        teacher: teacherWithBothSeededClassrooms(),
        classrooms: authoritativeClassrooms(),
      );
      final provider = ClassroomProvider(firestore: fake);
      await provider.load('uid_1');

      provider.search('oak');
      provider.search('7');
      provider.search('');

      // Filtering is local. A teacher typing on school wifi must not issue a
      // read per keystroke.
      expect(fake.teacherReads, 1);
      expect(fake.classroomReads, 1);
    });

    test('"oak" matches on institution, so both classrooms survive', () async {
      final provider = await loaded();
      provider.search('oak');
      expect(provider.visible, hasLength(2));
    });

    test('a query that hides everything is no-matches, not empty', () async {
      final provider = await loaded();
      provider.search('zzzz');

      // Two different empty states with two different messages: "you have no
      // classrooms" would be a lie here.
      expect(provider.visible, isEmpty);
      expect(provider.hasNoMatches, isTrue);
      expect(provider.isEmpty, isFalse);
    });

    test('clearing the query restores the full list', () async {
      final provider = await loaded();
      provider.search('zzzz');
      provider.search('');

      expect(provider.visible, hasLength(2));
      expect(provider.hasNoMatches, isFalse);
    });

    test('setting the same query again does not notify', () async {
      final provider = await loaded();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.search('oak');
      provider.search('oak');

      expect(notifications, 1);
    });
  });
}
