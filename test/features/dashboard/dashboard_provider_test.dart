import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_profile.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';

import '../../support/fakes.dart';

/// A `teachers/{docId}` record, shaped the way `teacher-corner-dev` shapes one.
///
/// Note what is NOT here: the document id is a client-allocated `tch_*`, not the
/// uid, and the uid lives at `teacherMeta.uid`. That is the real relationship,
/// and a fixture keyed by uid would let a doc-by-id read pass in a test and fail
/// against the database.
Teacher aTeacher() => Teacher.fromMap('tch_alloc_1', {
  'teacherMeta': {
    'uid': 'uid_1',
    'firstName': 'Divya',
    'lastName': 'Jain',
  },
  'classrooms': {
    'cls_oak_7a': {
      // The school is denormalised onto the CLASSROOM here, not onto
      // teacherMeta, which is where the web app actually puts it.
      'institutionName': 'Test School Oak',
      'programmes': {'prog_tip_2026': <String, dynamic>{}},
    },
    'cls_oak_et': {
      'institutionName': 'Test School Oak',
      'programmes': {'prog_tip_2026': <String, dynamic>{}},
    },
  },
});

/// The `users/{uid}` half. Carries a DIFFERENT name from the teaching record on
/// purpose: live data does exactly this, and the profile is supposed to win.
TeacherProfile aProfile() => TeacherProfile.fromMap('uid_1', {
  'firstName': 'Divya',
  'lastName': 'Jain',
  'institutionName': 'KUVEMPU UNIVERSITY',
});

void main() {
  test('starts in loading, before anything has been asked for', () {
    final provider = DashboardProvider(firestore: FakeFirestoreService());
    expect(provider.status, DashboardStatus.loading);
    expect(provider.account, isNull);
  });

  test('a successful load exposes the teacher and the counts', () async {
    final provider = DashboardProvider(
      firestore: FakeFirestoreService(teacher: aTeacher(), profile: aProfile()),
    );

    await provider.load('uid_1');

    expect(provider.status, DashboardStatus.loaded);
    expect(provider.account!.displayName, 'Divya Jain');
    expect(provider.account!.classroomCount, 2);
    // Both classrooms share one programme.
    expect(provider.account!.programmeCount, 1);
    expect(provider.errorKey, isNull);
  });

  test('the profile wins the name and the school, the record wins the classes',
      () async {
    // The two documents disagree, which is the state live data is in. The
    // profile is what the teacher controls, so it decides identity; only the
    // teaching record knows the classrooms.
    final provider = DashboardProvider(
      firestore: FakeFirestoreService(teacher: aTeacher(), profile: aProfile()),
    );

    await provider.load('uid_1');

    expect(provider.account!.institutionName, 'KUVEMPU UNIVERSITY');
    expect(provider.account!.classroomCount, 2);
    expect(provider.isTeacherNotLinked, isFalse);
  });

  test('a profile with no teaching record is linked=false, not an error',
      () async {
    // Signed in, `users/{uid}` present, and no `teachers` document carries this
    // uid. The header still has a name and a school to show; what is missing is
    // the classrooms, and the screen says so rather than erroring.
    final provider = DashboardProvider(
      firestore: FakeFirestoreService(profile: aProfile()),
    );

    await provider.load('uid_1');

    expect(provider.status, DashboardStatus.loaded);
    expect(provider.isTeacherNotLinked, isTrue);
    expect(provider.account!.displayName, 'Divya Jain');
    expect(provider.account!.institutionName, 'KUVEMPU UNIVERSITY');
    expect(provider.classrooms, isEmpty);
  });

  test('falls back to the teaching record when there is no profile', () async {
    // A teacher who has only ever signed into THIS app has no users/{uid}: that
    // document is written by the web app. The name has to come from the record.
    final provider = DashboardProvider(
      firestore: FakeFirestoreService(teacher: aTeacher()),
    );

    await provider.load('uid_1');

    expect(provider.account!.displayName, 'Divya Jain');
    // Sourced from the classroom entry, because teacherMeta has no school.
    expect(provider.account!.institutionName, 'Test School Oak');
    expect(provider.isTeacherNotLinked, isFalse);
  });

  test(
    'neither document present is loaded-and-unlinked, not an error',
    () async {
      final provider = DashboardProvider(firestore: FakeFirestoreService());

      await provider.load('uid_1');

      // Signed in, nothing provisioned. Retrying cannot fix it, so it must not
      // present as a failure.
      expect(provider.status, DashboardStatus.loaded);
      expect(provider.isTeacherNotLinked, isTrue);
      expect(provider.account!.isEmpty, isTrue);
    },
  );

  test('a thrown read becomes the error state with a generic key', () async {
    final provider = DashboardProvider(
      firestore: FakeFirestoreService(throws: StateError('boom')),
    );

    await provider.load('uid_1');

    expect(provider.status, DashboardStatus.error);
    expect(provider.errorKey, 'dashboard.error_generic');
    // An error is NOT "not linked": the difference is whether we managed to
    // ask. Conflating them would show a teacher a "register with your admin"
    // message when the real problem was the network.
    expect(provider.isTeacherNotLinked, isFalse);
  });

  test(
    'a read that never answers times out instead of spinning forever',
    () async {
      // The acceptance check for this phase: wifi off must produce the error
      // state, never a spinner that never stops.
      final gate = Completer<void>();
      final provider = DashboardProvider(
        firestore: FakeFirestoreService(gate: gate),
        timeout: const Duration(milliseconds: 20),
      );

      await provider.load('uid_1');

      expect(provider.status, DashboardStatus.error);
      expect(provider.errorKey, 'dashboard.error_offline');
      gate.complete();
    },
  );

  group('not refetching needlessly', () {
    test('loading the same uid twice reads once', () async {
      final fake = FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.load('uid_1');

      // The screen's initState fires on every navigation back to the tab.
      expect(fake.teacherReads, 1);
    });

    test('a different uid does refetch', () async {
      final fake = FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.load('uid_2');

      expect(fake.teacherReads, 2);
      expect(fake.requestedUids, ['uid_1', 'uid_2']);
    });

    test('load retries after a failure', () async {
      final fake = FakeFirestoreService(throws: StateError('boom'));
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.load('uid_1');

      // Same uid, but the last attempt failed, so asking again must try again.
      expect(fake.teacherReads, 2);
    });
  });

  group('retry', () {
    test('always refetches, even after a success', () async {
      final fake = FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.load('uid_1');
      await provider.retry();

      expect(fake.teacherReads, 2);
    });

    test('does nothing before any uid is known', () async {
      final fake = FakeFirestoreService(teacher: aTeacher());
      final provider = DashboardProvider(firestore: fake);

      await provider.retry();

      expect(fake.teacherReads, 0);
    });

    test(
      'repeated taps while a read is in flight start only one read',
      () async {
        // Retry is a button a frustrated teacher taps repeatedly.
        final gate = Completer<void>();
        final fake = FakeFirestoreService(teacher: aTeacher(), gate: gate);
        final provider = DashboardProvider(firestore: fake);

        final first = provider.load('uid_1');
        final second = provider.retry();
        final third = provider.retry();

        gate.complete();
        await Future.wait([first, second, third]);

        expect(fake.teacherReads, 1);
      },
    );
  });
}
