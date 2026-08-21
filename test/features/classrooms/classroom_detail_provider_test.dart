import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_provider.dart';

import '../../support/fakes.dart';

const _lu = 'lu_magnetic_pen_stand';
const _wf = 'wf_mps_v1';
const _prog = 'prog_tip_2026';

Classroom seededClassroom() => Classroom.fromMap('cls_oak_7a', {
      'classroomName': '7 A',
      'type': 'CLASSROOM',
      'grade': 7,
      'section': 'A',
      'institutionName': 'Test School Oak',
      'studentCounter': 32,
      'programmes': {
        _prog: {
          'displayName': 'TIP 2026',
          'workflowIds': [
            {'learningUnitId': _lu, 'workflowId': _wf},
          ],
        },
      },
    });

/// The awkward one: grade "ET", name from stemClubName, workflowIds as a map.
Classroom seededStemClub() => Classroom.fromMap('cls_oak_et', {
      'stemClubName': 'Oak ET Club',
      'type': 'STEM-CLUB',
      'grade': 'ET',
      'institutionName': 'Test School Oak',
      'studentCounter': 12,
      'programmes': {
        _prog: {
          'displayName': 'TIP 2026',
          'workflowIds': {
            '0': {'learningUnitId': _lu, 'workflowId': _wf},
          },
        },
      },
    });

LearningUnit theUnit() => LearningUnit.fromMap(_lu, {
      'learningUnitDisplayName': 'Magnetic Pen Stand',
      'type': 'TACtivity',
      'shortDescription': 'Build a pen stand that holds itself up with magnets.',
      'stepCount': 6,
      'subjectName': 'Science',
    });

void main() {
  group('loading a classroom', () {
    test('groups activities under their programme', () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [seededClassroom()],
          learningUnits: [theUnit()],
        ),
      );

      await provider.load('cls_oak_7a');

      expect(provider.status, ClassroomDetailStatus.loaded);
      expect(provider.programmes, hasLength(1));
      expect(provider.programmes.single.programme.label, 'TIP 2026');
      expect(provider.programmes.single.activities, hasLength(1));
      expect(provider.programmes.single.activities.single.label,
          'Magnetic Pen Stand');
    });

    test('carries the workflow id from the CLASSROOM binding', () async {
      // The unit itself has no workflow. The binding does, and it has to reach
      // the learning unit screen.
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [seededClassroom()],
          learningUnits: [theUnit()],
        ),
      );

      await provider.load('cls_oak_7a');

      final activity = provider.programmes.single.activities.single;
      expect(activity.learningUnitId, _lu);
      expect(activity.workflowId, _wf);
    });

    test('the same unit resolves to a different workflow per classroom',
        () async {
      final a = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [
            Classroom.fromMap('cls_a', {
              'programmes': {
                _prog: {
                  'workflowIds': [
                    {'learningUnitId': _lu, 'workflowId': 'wf_one'},
                  ],
                },
              },
            }),
          ],
          learningUnits: [theUnit()],
        ),
      );
      final b = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [
            Classroom.fromMap('cls_b', {
              'programmes': {
                _prog: {
                  'workflowIds': [
                    {'learningUnitId': _lu, 'workflowId': 'wf_two'},
                  ],
                },
              },
            }),
          ],
          learningUnits: [theUnit()],
        ),
      );

      await a.load('cls_a');
      await b.load('cls_b');

      expect(a.programmes.single.activities.single.workflowId, 'wf_one');
      expect(b.programmes.single.activities.single.workflowId, 'wf_two');
    });

    test('reads each distinct unit once, not once per binding', () async {
      final fake = FakeFirestoreService(
        classrooms: [
          Classroom.fromMap('cls_a', {
            'programmes': {
              'prog_one': {
                'workflowIds': [
                  {'learningUnitId': _lu, 'workflowId': 'wf_one'},
                ],
              },
              'prog_two': {
                'workflowIds': [
                  {'learningUnitId': _lu, 'workflowId': 'wf_two'},
                ],
              },
            },
          }),
        ],
        learningUnits: [theUnit()],
      );
      final provider = ClassroomDetailProvider(firestore: fake);

      await provider.load('cls_a');

      // Same unit in two programmes on one classroom.
      expect(provider.programmes, hasLength(2));
      expect(fake.learningUnitReads, 1);
    });
  });

  group('the STEM club', () {
    test('renders a name and no fabricated grade', () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [seededStemClub()],
          learningUnits: [theUnit()],
        ),
      );

      await provider.load('cls_oak_et');

      final classroom = provider.classroom!;
      expect(classroom.displayName, 'Oak ET Club');
      expect(classroom.displayName, isNot(contains('null')));
      // grade "ET" is not an int, so there is no grade line to render at all.
      expect(classroom.grade, isNull);
      expect(classroom.gradeSectionLabel, isNull);
    });

    test('its map-form workflowIds still produce an activity', () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [seededStemClub()],
          learningUnits: [theUnit()],
        ),
      );

      await provider.load('cls_oak_et');

      expect(provider.programmes.single.activities.single.workflowId, _wf);
    });
  });

  group('states', () {
    test('a missing classroom document is notFound, not an error', () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(),
      );

      await provider.load('cls_gone');

      // Referenced by the teacher but deleted. Retrying cannot fix it.
      expect(provider.status, ClassroomDetailStatus.notFound);
      expect(provider.classroom, isNull);
    });

    test('a classroom with no programmes loads empty', () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [Classroom.fromMap('cls_bare', {'classroomName': '8 B'})],
        ),
      );

      await provider.load('cls_bare');

      expect(provider.status, ClassroomDetailStatus.loaded);
      expect(provider.hasNoProgrammes, isTrue);
    });

    test('a binding whose unit document is missing still lists the row',
        () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(
          classrooms: [seededClassroom()],
          learningUnits: const [],
        ),
      );

      await provider.load('cls_oak_7a');

      final activity = provider.programmes.single.activities.single;
      expect(activity.unit, isNull);
      // Falls back to the id so the row is identifiable, never blank or "null".
      expect(activity.label, _lu);
      expect(activity.label, isNot(contains('null')));
    });

    test('a thrown read becomes the error state', () async {
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(throwsOnClassroom: StateError('boom')),
      );

      await provider.load('cls_oak_7a');

      expect(provider.status, ClassroomDetailStatus.error);
      expect(provider.errorKey, 'classroom.error_generic');
    });

    test('a read that never answers times out', () async {
      final gate = Completer<void>();
      final provider = ClassroomDetailProvider(
        firestore: FakeFirestoreService(gate: gate),
        timeout: const Duration(milliseconds: 20),
      );

      await provider.load('cls_oak_7a');

      expect(provider.status, ClassroomDetailStatus.error);
      expect(provider.errorKey, 'classroom.error_offline');
      gate.complete();
    });

    test('loading the same classroom twice reads once', () async {
      final fake = FakeFirestoreService(
        classrooms: [seededClassroom()],
        learningUnits: [theUnit()],
      );
      final provider = ClassroomDetailProvider(firestore: fake);

      await provider.load('cls_oak_7a');
      await provider.load('cls_oak_7a');

      expect(fake.classroomReads, 1);
    });
  });
}
