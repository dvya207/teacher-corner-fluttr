import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/utils/parse_diagnostics.dart';

const _lu = 'lu_magnetic_pen_stand';
const _workflow = 'wf_mps_v1';
const _programme = 'prog_tip_2026';

/// `Classrooms/cls_oak_7a` as seeded: workflowIds in LIST form.
Map<String, dynamic> seededClassroom() => {
      'classroomName': '7 A',
      'type': 'CLASSROOM',
      'grade': 7,
      'section': 'A',
      'board': 'CBSE',
      'institutionName': 'Test School Oak',
      'studentCounter': 32,
      'programmes': {
        _programme: {
          'displayName': 'TIP 2026',
          'workflowIds': [
            {'learningUnitId': _lu, 'workflowId': _workflow},
          ],
        },
      },
    };

/// `Classrooms/cls_oak_et` as seeded: grade is the String "ET", the name comes
/// from stemClubName, and workflowIds is in MAP form.
Map<String, dynamic> seededStemClub() => {
      'stemClubName': 'Oak ET Club',
      'type': 'STEM-CLUB',
      'grade': 'ET',
      'institutionName': 'Test School Oak',
      'studentCounter': 12,
      'programmes': {
        _programme: {
          'displayName': 'TIP 2026',
          'workflowIds': {
            '0': {'learningUnitId': _lu, 'workflowId': _workflow},
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

  group('the ordinary seeded classroom', () {
    test('parses the fields the list card shows', () {
      final classroom = Classroom.fromMap('cls_oak_7a', seededClassroom());

      expect(classroom.displayName, '7 A');
      expect(classroom.grade, 7);
      expect(classroom.section, 'A');
      expect(classroom.board, 'CBSE');
      expect(classroom.institutionName, 'Test School Oak');
      // The field is studentCounter, not studentCount.
      expect(classroom.studentCounter, 32);
      expect(classroom.gradeSectionLabel, 'Grade 7 · A');
    });

    test('reads workflowIds in LIST form', () {
      final classroom = Classroom.fromMap('cls_oak_7a', seededClassroom());
      expect(classroom.allWorkflows, hasLength(1));
      expect(classroom.workflowIdFor(_lu), _workflow);
    });
  });

  group('the STEM-CLUB with grade "ET"', () {
    test('renders a name without crashing and without printing null', () {
      final classroom = Classroom.fromMap('cls_oak_et', seededStemClub());

      expect(classroom.isStemClub, isTrue);
      // stemClubName is used INSTEAD of classroomName for this type.
      expect(classroom.displayName, 'Oak ET Club');
      expect(classroom.displayName, isNot(contains('null')));
    });

    test('grade "ET" becomes null, not 0, and is logged', () {
      final classroom = Classroom.fromMap('cls_oak_et', seededStemClub());

      // Null means "no grade". Defaulting to 0 would put "Grade 0" on a card.
      expect(classroom.grade, isNull);
      expect(
        ParseDiagnostics.captured!.where((r) => r.field == 'grade'),
        isNotEmpty,
      );
    });

    test('omits the grade line entirely rather than showing a placeholder', () {
      final classroom = Classroom.fromMap('cls_oak_et', seededStemClub());
      // No section either, so there is nothing to say and the caller can skip
      // the whole line.
      expect(classroom.gradeSectionLabel, isNull);
    });

    test('reads workflowIds in MAP form', () {
      final classroom = Classroom.fromMap('cls_oak_et', seededStemClub());
      expect(classroom.allWorkflows, hasLength(1));
      expect(classroom.workflowIdFor(_lu), _workflow);
    });
  });

  group('the workflow binding lives on the classroom', () {
    test('the same learning unit maps to a different workflow per classroom',
        () {
      // This is the most counter-intuitive thing in the data model, so it gets
      // an explicit test rather than a comment.
      final a = Classroom.fromMap('cls_a', {
        'programmes': {
          _programme: {
            'workflowIds': [
              {'learningUnitId': _lu, 'workflowId': 'wf_version_one'},
            ],
          },
        },
      });
      final b = Classroom.fromMap('cls_b', {
        'programmes': {
          _programme: {
            'workflowIds': [
              {'learningUnitId': _lu, 'workflowId': 'wf_version_two'},
            ],
          },
        },
      });

      expect(a.workflowIdFor(_lu), 'wf_version_one');
      expect(b.workflowIdFor(_lu), 'wf_version_two');
    });

    test('returns null for a learning unit this classroom is not running', () {
      final classroom = Classroom.fromMap('cls_oak_7a', seededClassroom());
      expect(classroom.workflowIdFor('lu_not_running_here'), isNull);
    });

    test('a binding missing its workflowId is dropped, never half-resolved', () {
      final classroom = Classroom.fromMap('cls_a', {
        'programmes': {
          _programme: {
            'workflowIds': [
              {'learningUnitId': _lu},
              {'learningUnitId': 'lu_ok', 'workflowId': 'wf_ok'},
            ],
          },
        },
      });

      expect(classroom.allWorkflows, hasLength(1));
      expect(classroom.workflowIdFor(_lu), isNull);
      expect(classroom.workflowIdFor('lu_ok'), 'wf_ok');
    });

    test('map-form keys order numerically, so "10" follows "9"', () {
      final classroom = Classroom.fromMap('cls_a', {
        'programmes': {
          _programme: {
            'workflowIds': {
              '10': {'learningUnitId': 'lu_ten', 'workflowId': 'wf_ten'},
              '9': {'learningUnitId': 'lu_nine', 'workflowId': 'wf_nine'},
              '0': {'learningUnitId': 'lu_zero', 'workflowId': 'wf_zero'},
            },
          },
        },
      });

      expect(
        classroom.allWorkflows.map((w) => w.learningUnitId),
        ['lu_zero', 'lu_nine', 'lu_ten'],
      );
    });
  });

  group('older and messier documents', () {
    test('falls back to the legacy "name" field', () {
      final classroom = Classroom.fromMap('cls_old', {'name': '6 B'});
      expect(classroom.displayName, '6 B');
    });

    test('falls back to the id when no name field is populated at all', () {
      final classroom = Classroom.fromMap('cls_nameless', const {});
      expect(classroom.displayName, 'cls_nameless');
      expect(classroom.displayName, isNot(contains('null')));
    });

    test('a STEM-CLUB whose stemClubName is missing still shows something', () {
      // Type and populated field disagree. Show the name that does exist rather
      // than falling all the way through to the raw id.
      final classroom = Classroom.fromMap('cls_x', {
        'type': 'STEM-CLUB',
        'classroomName': 'Fallback Club Name',
      });
      expect(classroom.displayName, 'Fallback Club Name');
    });

    test('studentCounter stored as a String still counts', () {
      final classroom = Classroom.fromMap('cls_a', {'studentCounter': '32'});
      expect(classroom.studentCounter, 32);
    });

    test('studentCounter that is not a number degrades to null', () {
      final classroom = Classroom.fromMap('cls_a', {'studentCounter': 'many'});
      expect(classroom.studentCounter, isNull);
    });

    test('a programme with no id is dropped', () {
      final classroom = Classroom.fromMap('cls_a', {
        'programmes': [
          {'displayName': 'Nameless programme'},
        ],
      });
      expect(classroom.programmes, isEmpty);
    });

    test('programme label falls back to the id, never to blank', () {
      final classroom = Classroom.fromMap('cls_a', {
        'programmes': {
          'prog_no_display_name': <String, dynamic>{},
        },
      });
      expect(classroom.programmes.single.label, 'prog_no_display_name');
    });
  });
}
