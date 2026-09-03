import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/programme.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/features/quizzes/quizzes_provider.dart';

import '../../support/fakes.dart';

/// Grouping assignments under the classrooms that set them.
///
/// WHY THIS NEEDS TESTS. An assignment is not attached to a classroom: the chain
/// is classroom -> programmes -> `assignmentIds` -> `Assignments/{docId}`, and
/// every join in it is somewhere the wrong row can appear under the wrong class.
/// Two of the three links are many-to-many, so the same assignment legitimately
/// shows under several classrooms and must be read only once.

Classroom classroom(String id, String name, List<String> programmeIds) =>
    Classroom.fromMap(id, {
      'classroomName': name,
      'institutionName': 'Airaa Academy',
      'programmes': {
        for (final p in programmeIds) p: {'programmeId': p, 'displayName': p},
      },
    });

Programme programme(String id, Map<String, dynamic> assignmentIds) =>
    Programme.fromMap(id, {
      'programmeId': id,
      'displayName': id,
      'assignmentIds': assignmentIds,
    });

Assignment assignment(String id, {String type = 'QUIZ'}) =>
    Assignment.fromMap(id, {'displayName': id, 'type': type});

TeacherAccount accountWith(List<String> classroomIds) => TeacherAccount(
  uid: 'uid-1',
  teaching: Teacher.fromMap('t1', {
    'docId': 't1',
    'classrooms': {
      for (final id in classroomIds)
        id: {'classroomId': id, 'classroomName': id},
    },
  }),
);

void main() {
  test('starts in loading, before anything has been asked for', () {
    final provider = QuizzesProvider(firestore: FakeFirestoreService());

    expect(provider.status, QuizzesStatus.loading);
    expect(provider.rows, isEmpty);
  });

  test(
    'groups an assignment under the classroom whose programme sets it',
    () async {
      final provider = QuizzesProvider(
        firestore: FakeFirestoreService(
          classrooms: [
            classroom('c1', '4 A', ['p1']),
          ],
          programmes: [
            programme('p1', {
              'a1': {'assignmentId': 'a1', 'assignmentDueDate': null},
            }),
          ],
          assignments: [assignment('a1')],
        ),
      );

      await provider.load(accountWith(['c1']));

      expect(provider.status, QuizzesStatus.loaded);
      expect(provider.rows, hasLength(1));
      expect(
        provider.rows.single.assignments.map((row) => row.assignment.docId),
        ['a1'],
      );
    },
  );

  test('a classroom with nothing set still appears, and reports empty', () async {
    // "No assignments in this classroom yet" is an answer. A missing row is not.
    final provider = QuizzesProvider(
      firestore: FakeFirestoreService(
        classrooms: [
          classroom('c1', '4 A', ['p1']),
        ],
        programmes: [programme('p1', <String, dynamic>{})],
      ),
    );

    await provider.load(accountWith(['c1']));

    expect(provider.rows, hasLength(1));
    expect(provider.rows.single.isEmpty, isTrue);
  });

  test('the same assignment under two classrooms is counted ONCE', () async {
    // Both the programme-to-classroom and assignment-to-programme links are
    // many-to-many, so this is the normal case rather than an edge one.
    final provider = QuizzesProvider(
      firestore: FakeFirestoreService(
        classrooms: [
          classroom('c1', '4 A', ['p1']),
          classroom('c2', '5 B', ['p1']),
        ],
        programmes: [
          programme('p1', {
            'a1': {'assignmentId': 'a1', 'assignmentDueDate': null},
          }),
        ],
        assignments: [assignment('a1')],
      ),
    );

    await provider.load(accountWith(['c1', 'c2']));

    expect(provider.rows, hasLength(2));
    expect(provider.rows.every((r) => r.assignments.length == 1), isTrue);
    expect(
      provider.assignmentCount,
      1,
      reason: 'deduplicated across classrooms',
    );
    expect(provider.classroomCount, 2);
  });

  test('an id pointing at nothing is dropped, not rendered blank', () async {
    final provider = QuizzesProvider(
      firestore: FakeFirestoreService(
        classrooms: [
          classroom('c1', '4 A', ['p1']),
        ],
        programmes: [
          programme('p1', {
            'a1': {'assignmentId': 'a1', 'assignmentDueDate': null},
            'gone': {'assignmentId': 'gone', 'assignmentDueDate': null},
          }),
        ],
        assignments: [assignment('a1')],
      ),
    );

    await provider.load(accountWith(['c1']));

    expect(
      provider.rows.single.assignments.map((row) => row.assignment.docId),
      ['a1'],
    );
  });

  test('dated assignments come first, undated last', () async {
    final provider = QuizzesProvider(
      firestore: FakeFirestoreService(
        classrooms: [
          classroom('c1', '4 A', ['p1']),
        ],
        programmes: [
          programme('p1', {
            'later': {
              'assignmentId': 'later',
              'assignmentDueDate': Timestamp.fromDate(DateTime.utc(2026, 9, 1)),
            },
            'undated': {'assignmentId': 'undated', 'assignmentDueDate': null},
            'sooner': {
              'assignmentId': 'sooner',
              'assignmentDueDate': Timestamp.fromDate(DateTime.utc(2026, 6, 1)),
            },
          }),
        ],
        assignments: [
          assignment('later'),
          assignment('undated'),
          assignment('sooner'),
        ],
      ),
    );

    await provider.load(accountWith(['c1']));

    expect(
      provider.rows.single.assignments.map((row) => row.assignment.docId),
      ['sooner', 'later', 'undated'],
    );
  });

  test(
    'an account with no classrooms reports empty rather than loaded',
    () async {
      final provider = QuizzesProvider(firestore: FakeFirestoreService());

      await provider.load(accountWith(const []));

      expect(provider.status, QuizzesStatus.empty);
    },
  );
}
