import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/utils/parse_diagnostics.dart';

/// A ThinkTac-PRODUCTION-shaped teacher document, including the deliberately
/// awkward second classroom.
///
/// Kept after the repoint even though nothing writes this shape any more: the
/// parser is supposed to tolerate it, and `teacherMeta.institutionName` and the
/// int `grade` only exist on production documents. [devTeacher] below is the
/// shape live `teacher-corner-dev` data actually has.
Map<String, dynamic> productionTeacher() => {
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

/// A `teachers/{docId}` document shaped the way the Teacher Corner WEB APP
/// writes one, taken from the live record verified in teacher-corner-dev.
///
/// Four differences from [productionTeacher], every one of them load-bearing:
///   * the document id is client-allocated, and the uid is on `teacherMeta`;
///   * `teacherMeta` carries NO institutionName and NO designation;
///   * the school is denormalised onto each CLASSROOM entry;
///   * `programmes` is an ARRAY, not a map keyed by id.
Map<String, dynamic> devTeacher() => {
  'ownerId': '7vbKdBSqG3YRI6X1GzFNeQD24Rm1',
  'teacherMeta': {
    'uid': '7vbKdBSqG3YRI6X1GzFNeQD24Rm1',
    'firstName': 'Divya',
    'lastName': 'Jain',
    'email': 'divya.jain@intern.thinktac.com',
    'phone': '6362398700',
    'phoneNumber': '6362398700',
    'countryCode': '+91',
  },
  'classrooms': {
    '0BjL4c151I9W3xZ34ZEP': {
      'classroomId': '0BjL4c151I9W3xZ34ZEP',
      'classroomName': '9 B',
      'type': 'CLASSROOM',
      'grade': '9',
      'section': 'B',
      'institutionId': 'Fe2yDslU74Cp9SfOclda',
      'institutionName': 'KUVEMPU UNIVERSITY',
      'userRole': 'ThinkTac Coach',
      'programmes': [
        {'programmeId': '96HxMlMZzyGhyh0vpQhl', 'displayName': 'abcd'},
      ],
    },
    'pOy1JGWhNzLFY9uVBzHP': {
      'classroomId': 'pOy1JGWhNzLFY9uVBzHP',
      'classroomName': 'Pre-primary 2',
      'type': 'CLASSROOM',
      // A STRING grade that is not a number. Production has "ET"; the web app
      // has this. Either way it must parse to null, not zero.
      'grade': 'Pre-primary 2',
      'section': 'L',
      'institutionName': 'KUVEMPU UNIVERSITY',
      'programmes': [
        {'programmeId': '96HxMlMZzyGhyh0vpQhl', 'displayName': 'abcd'},
      ],
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
      final teacher = Teacher.fromMap('tch_alloc_1', productionTeacher());

      // The FIRST ARGUMENT IS THE DOCUMENT ID, not the uid. A production
      // document happens to be keyed by uid; a teacher-corner-dev one is not,
      // and the model must not conflate the two.
      expect(teacher.docId, 'tch_alloc_1');
      expect(teacher.displayName, 'Intern Teacher');
      expect(teacher.institutionName, 'Test School Oak');
      expect(teacher.classroomCount, 2);
    });

    test('counts one programme, not two, when both classrooms share it', () {
      // Both seeded classrooms run prog_tip_2026. Summing per classroom would
      // put "2 Programmes" on the dashboard, which is simply untrue.
      expect(Teacher.fromMap('tch_alloc_1', productionTeacher()).programmeCount, 1);
    });

    test('prefers the map key over the nested classroomId', () {
      final data = productionTeacher();
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

  group('the teacher-corner-dev shape', () {
    test('takes the uid from teacherMeta, not from the document id', () {
      final teacher = Teacher.fromMap('hY66fSjdzmYM06ciOIdH', devTeacher());

      expect(teacher.docId, 'hY66fSjdzmYM06ciOIdH');
      expect(teacher.uid, '7vbKdBSqG3YRI6X1GzFNeQD24Rm1');
    });

    test('an unlinked record parses with a null uid', () {
      // Registering a teacher creates no Auth user, so a record sits unlinked
      // until that person signs in. Absent must not become the string "null".
      final data = devTeacher();
      (data['teacherMeta'] as Map).remove('uid');

      final teacher = Teacher.fromMap('hY66fSjdzmYM06ciOIdH', data);
      expect(teacher.uid, isNull);
      expect(teacher.displayName, 'Divya Jain');
    });

    test('resolves the school from a classroom when teacherMeta has none', () {
      // The web app's TeacherMeta has no institutionName at all. Reading only
      // the meta would leave the dashboard subtitle blank against real data.
      final teacher = Teacher.fromMap('hY66fSjdzmYM06ciOIdH', devTeacher());

      expect(teacher.meta!.institutionName, isNull);
      expect(teacher.institutionName, 'KUVEMPU UNIVERSITY');
    });

    test('reads programmes stored as an array, not only as a map', () {
      // The web app writes TeacherProgramme[] on each classroom entry, where
      // production writes a map keyed by programmeId.
      final teacher = Teacher.fromMap('hY66fSjdzmYM06ciOIdH', devTeacher());

      expect(teacher.classroomCount, 2);
      // Both classrooms run the same programme, counted once.
      expect(teacher.programmeCount, 1);
      expect(
        teacher.classrooms.first.programmes.single.programmeId,
        '96HxMlMZzyGhyh0vpQhl',
      );
    });

    test('a non-numeric grade is null, never zero', () {
      final teacher = Teacher.fromMap('hY66fSjdzmYM06ciOIdH', devTeacher());
      final preprimary = teacher.classrooms
          .firstWhere((c) => c.classroomId == 'pOy1JGWhNzLFY9uVBzHP');

      expect(preprimary.grade, isNull);
      // The name still reads correctly, which is what the card shows.
      expect(preprimary.displayName, 'Pre-primary 2');
    });

    test('reads the phone from `phone` when `phoneNumber` is absent', () {
      final data = devTeacher();
      (data['teacherMeta'] as Map).remove('phoneNumber');

      final teacher = Teacher.fromMap('hY66fSjdzmYM06ciOIdH', data);
      expect(teacher.meta!.phoneNumber, '6362398700');
    });
  });
}
