import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/core/models/teacher_profile.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';

import '../../support/fakes.dart';

/// PER-TEACHER ISOLATION.
///
/// The app must work for WHOEVER signs in, and show them only their own data.
/// Every uid, classroom id and programme id below is invented for the test —
/// nothing here is anyone's real account, and nothing in `lib/` names one.
///
/// Two teachers, deliberately different in every dimension that could be
/// accidentally shared: different uids, different `teachers` document ids,
/// different names, different schools, different classrooms, different
/// programmes. Plus a third uid that is authenticated and linked to nothing,
/// which is the case that must NOT fall back to either of them.

const String uidAsha = 'uid_asha_0000000000000001';
const String uidBenoy = 'uid_benoy_000000000000002';
const String uidUnlinked = 'uid_unlinked_00000000003';

/// Asha: two classrooms, two distinct programmes.
Teacher ashaTeaching() => Teacher.fromMap('tch_asha_doc', {
  'ownerId': 'uid_admin_00000000000001',
  'teacherMeta': {
    'uid': uidAsha,
    'firstName': 'Asha',
    'lastName': 'Rao',
    'phoneNumber': '9000000001',
  },
  'classrooms': {
    'cls_asha_8a': {
      'classroomId': 'cls_asha_8a',
      'classroomName': '8 A',
      'type': 'CLASSROOM',
      'grade': '8',
      'section': 'A',
      'institutionName': 'Sunrise Public School',
      'programmes': [
        {'programmeId': 'prg_asha_alpha', 'displayName': 'Alpha'},
      ],
    },
    'cls_asha_club': {
      'classroomId': 'cls_asha_club',
      'stemClubName': 'Sunrise Robotics Club',
      'type': 'STEM-CLUB',
      'institutionName': 'Sunrise Public School',
      'programmes': [
        {'programmeId': 'prg_asha_beta', 'displayName': 'Beta'},
      ],
    },
  },
});

TeacherProfile ashaProfile() => TeacherProfile.fromMap(uidAsha, {
  'firstName': 'Asha',
  'lastName': 'Rao',
  'institutionName': 'Sunrise Public School',
});

/// Benoy: ONE classroom, ONE programme. Different counts from Asha on purpose,
/// so a leaked value shows up as a wrong number rather than a coincidence.
Teacher benoyTeaching() => Teacher.fromMap('tch_benoy_doc', {
  'ownerId': 'uid_admin_00000000000002',
  'teacherMeta': {
    'uid': uidBenoy,
    'firstName': 'Benoy',
    'lastName': 'Thomas',
    'phone': '9000000002',
  },
  'classrooms': {
    'cls_benoy_5c': {
      'classroomId': 'cls_benoy_5c',
      'classroomName': '5 C',
      'type': 'CLASSROOM',
      'grade': '5',
      'section': 'C',
      'institutionName': 'Hillview High',
      'programmes': [
        {'programmeId': 'prg_benoy_gamma', 'displayName': 'Gamma'},
      ],
    },
  },
});

TeacherProfile benoyProfile() => TeacherProfile.fromMap(uidBenoy, {
  'firstName': 'Benoy',
  'lastName': 'Thomas',
  'institutionName': 'Hillview High',
});

Classroom classroomDoc(String id, String name, int students) =>
    Classroom.fromMap(id, {
      'classroomName': name,
      'type': 'CLASSROOM',
      'institutionName': 'ignored by these assertions',
      'studentCounter': students,
    });

/// A fake serving BOTH teachers at once, keyed by uid. An unlisted uid resolves
/// to null rather than to either of them.
FakeFirestoreService twoTeachers() => FakeFirestoreService(
  teachersByUid: {uidAsha: ashaTeaching(), uidBenoy: benoyTeaching()},
  profilesByUid: {uidAsha: ashaProfile(), uidBenoy: benoyProfile()},
  classroomsByUid: {
    uidAsha: [
      classroomDoc('cls_asha_8a', '8 A', 31),
      classroomDoc('cls_asha_club', 'Sunrise Robotics Club', 12),
    ],
    uidBenoy: [classroomDoc('cls_benoy_5c', '5 C', 7)],
  },
);

void main() {
  group('the lookup is keyed on the authenticated uid', () {
    test('the teacher is found by teacherMeta.uid, not by document id', () {
      // The constant IS the contract: FirestoreService.fetchTeacher queries this
      // path. If it ever became a doc-by-id read against `teachers`, every
      // teacher in teacher-corner-dev would silently resolve to "no record",
      // because those document ids are client-allocated and are not uids.
      expect(Teacher.uidFieldPath, 'teacherMeta.uid');

      // And the document id is genuinely not the uid, in both fixtures.
      expect(ashaTeaching().docId, isNot(uidAsha));
      expect(ashaTeaching().uid, uidAsha);
      expect(benoyTeaching().docId, isNot(uidBenoy));
      expect(benoyTeaching().uid, uidBenoy);
    });

    test('the profile is keyed by uid, because there the id IS the uid', () {
      expect(ashaProfile().uid, uidAsha);
      expect(benoyProfile().uid, uidBenoy);
    });

    test('both reads are issued for the uid that was asked for', () async {
      final firestore = twoTeachers();
      await firestore.fetchTeacherAccount(uidBenoy);

      // fetchTeacherAccount is NOT overridden by the fake, so this exercises the
      // real composition: whichever uid it is handed must reach both reads.
      expect(firestore.requestedUids, [uidBenoy]);
      expect(firestore.requestedProfileUids, [uidBenoy]);
    });
  });

  group('two teachers, one fake, each gets only their own', () {
    test('the service returns each teacher their own account', () async {
      final firestore = twoTeachers();

      final asha = await firestore.fetchTeacherAccount(uidAsha);
      final benoy = await firestore.fetchTeacherAccount(uidBenoy);

      expect(asha.uid, uidAsha);
      expect(asha.displayName, 'Asha Rao');
      expect(asha.institutionName, 'Sunrise Public School');
      expect(asha.classroomCount, 2);
      expect(asha.programmeCount, 2);

      expect(benoy.uid, uidBenoy);
      expect(benoy.displayName, 'Benoy Thomas');
      expect(benoy.institutionName, 'Hillview High');
      expect(benoy.classroomCount, 1);
      expect(benoy.programmeCount, 1);

      // Nothing of one appears in the other.
      expect(
        asha.classrooms.map((c) => c.classroomId),
        isNot(contains('cls_benoy_5c')),
      );
      expect(
        benoy.classrooms.map((c) => c.classroomId),
        isNot(contains('cls_asha_8a')),
      );
    });

    test('the dashboard shows each teacher their own name and counts', () async {
      final firestore = twoTeachers();

      final ashaDash = DashboardProvider(firestore: firestore);
      await ashaDash.load(uidAsha);

      final benoyDash = DashboardProvider(firestore: firestore);
      await benoyDash.load(uidBenoy);

      expect(ashaDash.account!.displayName, 'Asha Rao');
      expect(ashaDash.classrooms.map((c) => c.displayName),
          containsAll(<String>['8 A', 'Sunrise Robotics Club']));
      // Their own classroom documents, so their own student total.
      expect(ashaDash.studentTotal, 31 + 12);

      expect(benoyDash.account!.displayName, 'Benoy Thomas');
      expect(benoyDash.classrooms.map((c) => c.displayName), ['5 C']);
      expect(benoyDash.studentTotal, 7);
    });

    test('the classroom list shows each teacher their own rows', () async {
      final firestore = twoTeachers();

      final ashaList = ClassroomProvider(firestore: firestore);
      await ashaList.load(uidAsha);

      final benoyList = ClassroomProvider(firestore: firestore);
      await benoyList.load(uidBenoy);

      expect(ashaList.all.length, 2);
      expect(benoyList.all.length, 1);
      expect(benoyList.all.single.classroomId, 'cls_benoy_5c');
    });
  });

  group('an authenticated uid with no teacher record', () {
    test('is not linked, and inherits nobody else\'s data', () async {
      final firestore = twoTeachers();

      final account = await firestore.fetchTeacherAccount(uidUnlinked);

      expect(account.uid, uidUnlinked);
      expect(account.isLinked, isFalse);
      expect(account.isEmpty, isTrue);
      expect(account.classrooms, isEmpty);
      expect(account.classroomCount, 0);
      expect(account.programmeCount, 0);
      // Emphatically not a fallback to either real teacher.
      expect(account.displayName, '');
      expect(account.institutionName, isNull);
    });

    test('the dashboard reports not-linked rather than another teacher',
        () async {
      final firestore = twoTeachers();
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(uidUnlinked);

      expect(dashboard.status, DashboardStatus.loaded);
      expect(dashboard.isTeacherNotLinked, isTrue);
      expect(dashboard.classrooms, isEmpty);
      expect(dashboard.account!.displayName, '');
    });

    test('a profile with no teaching record shows the name but no classes',
        () async {
      // The middle case: users/{uid} exists, nothing in `teachers` points at
      // them. Their own name is theirs to show; the classrooms are not.
      final firestore = FakeFirestoreService(
        teachersByUid: {uidAsha: ashaTeaching()},
        profilesByUid: {uidBenoy: benoyProfile()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(uidBenoy);

      expect(dashboard.isTeacherNotLinked, isTrue);
      expect(dashboard.account!.displayName, 'Benoy Thomas');
      expect(dashboard.account!.classroomCount, 0);
    });
  });

  group('switching teacher on one device leaks nothing', () {
    test('loading a second uid replaces the first teacher entirely', () async {
      final firestore = twoTeachers();
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(uidAsha);
      expect(dashboard.account!.displayName, 'Asha Rao');

      await dashboard.load(uidBenoy);

      expect(dashboard.account!.displayName, 'Benoy Thomas');
      expect(dashboard.account!.uid, uidBenoy);
      expect(dashboard.classrooms.map((c) => c.classroomId), ['cls_benoy_5c']);
      expect(dashboard.studentTotal, 7);
    });

    test('the previous teacher is gone BEFORE the new read resolves', () async {
      // The window that matters. `load` must drop the old data synchronously,
      // so there is no frame in which teacher B is signed in and teacher A's
      // name is on screen.
      final firestore = twoTeachers();
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(uidAsha);
      expect(dashboard.account!.displayName, 'Asha Rao');

      // A uid change must clear SYNCHRONOUSLY: the assertions below run before
      // the returned future is awaited, which is the same moment the widget tree
      // would build its next frame.
      final pending = dashboard.load(uidBenoy);
      expect(dashboard.account, isNull, reason: 'stale teacher still exposed');
      expect(dashboard.classrooms, isEmpty);
      expect(dashboard.status, DashboardStatus.loading);
      await pending;
      expect(dashboard.account!.displayName, 'Benoy Thomas');
    });

    test('reset() forgets the teacher, as sign-out requires', () async {
      final firestore = twoTeachers();
      final dashboard = DashboardProvider(firestore: firestore);
      final list = ClassroomProvider(firestore: firestore);

      await dashboard.load(uidAsha);
      await list.load(uidAsha);
      list.search('8');
      expect(dashboard.account, isNotNull);
      expect(list.all, isNotEmpty);

      dashboard.reset();
      list.reset();

      // Loading, not loaded-and-empty: "nobody has asked yet" must not render
      // as "this teacher has no classrooms".
      expect(dashboard.status, DashboardStatus.loading);
      expect(dashboard.account, isNull);
      expect(dashboard.classrooms, isEmpty);
      expect(dashboard.isTeacherNotLinked, isFalse);

      expect(list.status, ClassroomListStatus.loading);
      expect(list.all, isEmpty);
      // The search box was the previous teacher's input.
      expect(list.query, '');
    });

    test('after reset, the next teacher loads cleanly', () async {
      final firestore = twoTeachers();
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(uidAsha);
      dashboard.reset();
      await dashboard.load(uidBenoy);

      expect(dashboard.account!.displayName, 'Benoy Thomas');
      expect(dashboard.classrooms.map((c) => c.classroomId), ['cls_benoy_5c']);
    });

    test('a slow read for a signed-out teacher cannot overwrite the new one',
        () async {
      // Teacher A's read is in flight when A signs out and B signs in. When A's
      // read finally lands it must be DISCARDED, not written over B.
      final gate = Completer<void>();
      final slow = FakeFirestoreService(
        teachersByUid: {uidAsha: ashaTeaching()},
        profilesByUid: {uidAsha: ashaProfile()},
        gate: gate,
      );
      final dashboard = DashboardProvider(firestore: slow);

      final ashaLoad = dashboard.load(uidAsha);
      expect(dashboard.status, DashboardStatus.loading);

      // A signs out mid-flight.
      dashboard.reset();

      gate.complete();
      await ashaLoad;

      // A's data never landed.
      expect(dashboard.account, isNull);
      expect(dashboard.status, DashboardStatus.loading);
    });
  });

  group('no account-specific data is baked into the app', () {
    test('an account is built purely from what the reads returned', () {
      // Constructed with nothing: every field is absent rather than defaulted to
      // some developer's account.
      const empty = TeacherAccount(uid: 'uid_anyone_000000000001');

      expect(empty.isLinked, isFalse);
      expect(empty.isEmpty, isTrue);
      expect(empty.displayName, '');
      expect(empty.institutionName, isNull);
      expect(empty.classrooms, isEmpty);
      expect(empty.programmeCount, 0);
    });

    test('a fresh service asks for nothing until it is given a uid', () {
      final firestore = FakeFirestoreService();
      expect(firestore.requestedUids, isEmpty);
      expect(firestore.requestedProfileUids, isEmpty);

      final dashboard = DashboardProvider(firestore: firestore);
      // No uid, no reads, and nothing to show.
      expect(dashboard.account, isNull);
      expect(dashboard.status, DashboardStatus.loading);
    });

    test('retry before any load does nothing rather than guessing a uid',
        () async {
      final firestore = twoTeachers();
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.retry();

      expect(firestore.requestedUids, isEmpty);
      expect(dashboard.account, isNull);
    });
  });
}
