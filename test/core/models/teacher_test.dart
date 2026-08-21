import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/utils/parse_diagnostics.dart';

/// The teacher document exactly as `tools/seed.js` writes it, including the
/// deliberately awkward second classroom.
Map<String, dynamic> seededTeacher() => {
      'name': 'Intern Teacher',
      'teacherMeta': {
        'firstName': 'Intern',
        'lastName': 'Teacher',
        'phoneNumber': '+919999900000',
        'institutionName': 'Test School Oak',
        'designation': 'Teacher',
      },
      'classrooms': {
        'cls_oak_7a': {
          'classroomId': 'cls_oak_7a',
          'classroomName': '7 A',
          'type': 'CLASSROOM',
          'grade': 7,
          'section': 'A',
          'institutionName': 'Test School Oak',
          'programmes': {
            'prog_tip_2026': {
              'programmeId': 'prog_tip_2026',
              'displayName': 'TIP 2026',
            },
          },
        },
        'cls_oak_et': {
          'classroomId': 'cls_oak_et',
          'stemClubName': 'Oak ET Club',
          'type': 'STEM-CLUB',
          'grade': 'ET',
          'institutionName': 'Test School Oak',
          'programmes': {
            'prog_tip_2026': {
              'programmeId': 'prog_tip_2026',
              'displayName': 'TIP 2026',
            },
          },
        },
      },
    };

void main() {
  setUp(() {
    ParseDiagnostics.captured = <ParseDiagnosticRecord>[];
    ParseDiagnostics.reset();
  });

  tearDown(() {
    ParseDiagnostics.captured = null;
  });

  group('the seeded document', () {
    test('parses name, institution and both classrooms', () {
      final teacher = Teacher.fromMap('uid_1', seededTeacher());

      expect(teacher.uid, 'uid_1');
      expect(teacher.displayName, 'Intern Teacher');
      expect(teacher.institutionName, 'Test School Oak');
      expect(teacher.classroomCount, 2);
    });

    test('counts one programme, not two, when both classrooms share it', () {
      // Both seeded classrooms run prog_tip_2026. Summing per classroom would
      // put "2 Programmes" on the dashboard, which is simply untrue.
      expect(Teacher.fromMap('uid_1', seededTeacher()).programmeCount, 1);
    });

    test('prefers the map key over the nested classroomId', () {
      final data = seededTeacher();
      // SCHEMA.md: the nested id is a duplicate and is sometimes missing or
      // wrong. The key is authoritative.
      (data['classrooms'] as Map)['cls_oak_7a']['classroomId'] = 'WRONG';

      final teacher = Teacher.fromMap('uid_1', data);
      expect(
        teacher.classrooms.map((c) => c.classroomId),
        containsAll(['cls_oak_7a', 'cls_oak_et']),
      );
    });
  });

  group('displayName', () {
    test('prefers the teacherMeta pair over the top-level name', () {
      final teacher = Teacher.fromMap('uid_1', {
        'name': 'Stale Name',
        'teacherMeta': {'firstName': 'Divya', 'lastName': 'Jain'},
      });
      expect(teacher.displayName, 'Divya Jain');
    });

    test('falls back to the top-level name when teacherMeta is absent', () {
      final teacher = Teacher.fromMap('uid_1', {'name': 'Only A Name'});
      expect(teacher.displayName, 'Only A Name');
    });

    test('survives only half of the name pair', () {
      final teacher = Teacher.fromMap('uid_1', {
        'teacherMeta': {'firstName': 'Divya'},
      });
      // Not "Divya " with a trailing space, and not "Divya null".
      expect(teacher.displayName, 'Divya');
    });

    test('is empty rather than the string "null" on an empty document', () {
      final teacher = Teacher.fromMap('uid_1', const {});
      expect(teacher.displayName, isEmpty);
      expect(teacher.displayName, isNot(contains('null')));
      expect(teacher.classrooms, isEmpty);
      expect(teacher.programmeCount, 0);
    });
  });

  group('degrading rather than throwing', () {
    test('teacherMeta arriving as a String falls back to name, and logs', () {
      final teacher = Teacher.fromMap('uid_1', {
        'name': 'Fallback Name',
        'teacherMeta': 'not a map at all',
      });

      expect(teacher.meta, isNull);
      expect(teacher.displayName, 'Fallback Name');
      expect(
        ParseDiagnostics.captured!.map((r) => r.field),
        contains('teacherMeta'),
      );
    });

    test('classrooms arriving as a List still parses via the inner id', () {
      final teacher = Teacher.fromMap('uid_1', {
        'classrooms': [
          {'classroomId': 'cls_from_list', 'classroomName': '8 B'},
        ],
      });

      expect(teacher.classroomCount, 1);
      expect(teacher.classrooms.single.classroomId, 'cls_from_list');
      expect(teacher.classrooms.single.displayName, '8 B');
    });

    test('a list entry with no id anywhere is dropped, not faked', () {
      final teacher = Teacher.fromMap('uid_1', {
        'classrooms': [
          {'classroomName': 'Unidentifiable'},
          {'classroomId': 'cls_ok', 'classroomName': 'Fine'},
        ],
      });

      // An entry with no id cannot be routed to or read back, so carrying it
      // would only produce a row that breaks when tapped.
      expect(teacher.classrooms.map((c) => c.classroomId), ['cls_ok']);
    });

    test('one malformed classroom does not lose the good ones', () {
      final teacher = Teacher.fromMap('uid_1', {
        'classrooms': {
          'cls_bad': 'this should have been a map',
          'cls_good': {'classroomName': '9 C'},
        },
      });

      expect(teacher.classrooms.map((c) => c.classroomId), ['cls_good']);
    });

    test('classrooms arriving as a number degrades to empty and logs', () {
      final teacher = Teacher.fromMap('uid_1', {'classrooms': 42});
      expect(teacher.classrooms, isEmpty);
      expect(ParseDiagnostics.captured, isNotEmpty);
    });
  });
}
