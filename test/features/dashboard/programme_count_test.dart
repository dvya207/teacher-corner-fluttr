import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';

import '../../support/fakes.dart';

/// The dashboard's "N Programmes".
///
/// It is counted from the AUTHORITATIVE classroom documents, not the teacher
/// record's denormalised copy, because the two diverge in live data: one
/// classroom's entry on the teacher named a single programme while the
/// classroom's own document named two different ones, so the header read
/// "2 Programmes" directly above cards showing four distinct names.

const String kUid = 'uid_count_00000000000001';

/// A teacher record whose copy of `cls_a` is STALE — it says one programme,
/// where the classroom document below says two others. This is the live shape.
Teacher staleTeacherRecord() => Teacher.fromMap('tch_count_doc', {
  'teacherMeta': {'uid': kUid, 'firstName': 'Any', 'lastName': 'Teacher'},
  'classrooms': {
    'cls_a': {
      'classroomId': 'cls_a',
      'classroomName': 'A',
      'institutionName': 'School',
      'programmes': [
        {'programmeId': 'prg_shared', 'displayName': 'Shared'},
      ],
    },
    'cls_b': {
      'classroomId': 'cls_b',
      'classroomName': 'B',
      'institutionName': 'School',
      'programmes': [
        {'programmeId': 'prg_shared', 'displayName': 'Shared'},
      ],
    },
  },
});

Classroom classroomDoc(String id, Map<String, String> programmes) =>
    Classroom.fromMap(id, {
      'classroomName': id.toUpperCase(),
      'type': 'CLASSROOM',
      'institutionName': 'School',
      'studentCounter': 0,
      'programmes': {
        for (final entry in programmes.entries)
          entry.key: {'displayName': entry.value},
      },
    });

void main() {
  test('counts what the classroom documents say, not the teacher record',
      () async {
    // The record says {prg_shared} = 1. The documents say
    // {prg_one, prg_two, prg_shared} = 3. The header must say 3, because those
    // are the names the cards display.
    final firestore = FakeFirestoreService(
      teachersByUid: {kUid: staleTeacherRecord()},
      classroomsByUid: {
        kUid: [
          classroomDoc('cls_a', {'prg_one': 'One', 'prg_two': 'Two'}),
          classroomDoc('cls_b', {'prg_shared': 'Shared'}),
        ],
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);

    expect(dashboard.programmeCount, 3);
    // The account's own count still reflects the record, and still disagrees.
    // Kept as evidence of WHY the provider has its own: if these two ever
    // matched by accident this test would stop proving anything.
    expect(dashboard.account!.programmeCount, 1);
  });

  test('counts by identity, so a programme in two classrooms counts once',
      () async {
    final firestore = FakeFirestoreService(
      teachersByUid: {kUid: staleTeacherRecord()},
      classroomsByUid: {
        kUid: [
          classroomDoc('cls_a', {'prg_shared': 'Shared'}),
          classroomDoc('cls_b', {'prg_shared': 'Shared'}),
        ],
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);

    expect(dashboard.programmeCount, 1);
  });

  test('a shared display name is still two programmes', () async {
    // Counted by id, not by label: two programmes can carry the same name and
    // a name is not an identity.
    final firestore = FakeFirestoreService(
      teachersByUid: {kUid: staleTeacherRecord()},
      classroomsByUid: {
        kUid: [
          classroomDoc('cls_a', {'prg_one': 'Same Name'}),
          classroomDoc('cls_b', {'prg_two': 'Same Name'}),
        ],
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);

    expect(dashboard.programmeCount, 2);
  });

  test('falls back per row when a classroom document did not load', () async {
    // cls_a's document is absent, so that row uses the teacher record's copy
    // (prg_shared) while cls_b uses its own document. One failed read costs one
    // row's accuracy, not the whole number.
    final firestore = FakeFirestoreService(
      teachersByUid: {kUid: staleTeacherRecord()},
      classroomsByUid: {
        kUid: [classroomDoc('cls_b', {'prg_two': 'Two'})],
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);

    expect(dashboard.programmeCount, 2); // {prg_shared from the record, prg_two}
  });

  test('no classrooms is zero, not an error', () async {
    final firestore = FakeFirestoreService(
      teachersByUid: {
        kUid: Teacher.fromMap('tch_empty', {
          'teacherMeta': {'uid': kUid, 'firstName': 'No', 'lastName': 'Classes'},
        }),
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);

    expect(dashboard.programmeCount, 0);
    expect(dashboard.status, DashboardStatus.loaded);
  });

  test('an unlinked teacher counts zero', () async {
    final dashboard = DashboardProvider(firestore: FakeFirestoreService());

    await dashboard.load(kUid);

    expect(dashboard.programmeCount, 0);
    expect(dashboard.isTeacherNotLinked, isTrue);
  });

  test('the count is cleared on reset, not carried to the next teacher',
      () async {
    final firestore = FakeFirestoreService(
      teachersByUid: {kUid: staleTeacherRecord()},
      classroomsByUid: {
        kUid: [classroomDoc('cls_a', {'prg_one': 'One', 'prg_two': 'Two'})],
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);
    expect(dashboard.programmeCount, greaterThan(0));

    dashboard.reset();

    expect(dashboard.programmeCount, 0);
  });

  test('the ids and the labels on a row come from the same source', () async {
    // The whole point of carrying both: a chip must never name a programme the
    // count did not include.
    final firestore = FakeFirestoreService(
      teachersByUid: {kUid: staleTeacherRecord()},
      classroomsByUid: {
        kUid: [
          classroomDoc('cls_a', {'prg_one': 'One', 'prg_two': 'Two'}),
          classroomDoc('cls_b', {'prg_shared': 'Shared'}),
        ],
      },
    );
    final dashboard = DashboardProvider(firestore: firestore);

    await dashboard.load(kUid);

    for (final row in dashboard.classrooms) {
      expect(
        row.programmeIds.length,
        row.programmeLabels.length,
        reason: '${row.classroomId} has mismatched ids and labels',
      );
    }
    // And the labels on screen are the authoritative ones, not the record's.
    final a = dashboard.classrooms.firstWhere((c) => c.classroomId == 'cls_a');
    expect(a.programmeLabels, ['One', 'Two']);
    expect(a.programmeIds, ['prg_one', 'prg_two']);
  });
}
