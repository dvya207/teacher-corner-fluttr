import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';

import '../../support/fakes.dart';

/// Finding a teaching record the WEB APP HAS NEVER LINKED.
///
/// `teacherMeta.uid` is stamped by the web app's `linkSignedInUid`, which runs on
/// a WEB sign-in. An admin registers a teacher, that teacher signs into THIS app,
/// and their record therefore carries no uid — so a uid-only lookup finds nothing
/// even though the record exists with their classrooms on it. In live data six of
/// seven records were unstamped.
///
/// The fallback matches on the subscriber digits, which is the SAME key the web
/// app links on, and accepts ONLY an unlinked record. That last part is the
/// safety: phone numbers are recycled, and matching a record already stamped with
/// somebody else's uid would hand one teacher another's classrooms.

const String kNewUid = 'uid_new_teacher_00000001';
const String kNewPhoneE164 = '+919481635184';
const String kNewDigits = '9481635184';

const String kOtherUid = 'uid_someone_else_0000001';

/// A record an admin registered: classrooms attached, NO uid stamped.
Teacher unlinkedRecord({String digits = kNewDigits}) =>
    Teacher.fromMap('tch_unlinked_doc', {
      'teacherMeta': {
        // No 'uid' key at all, which is what the web app leaves behind.
        'firstName': 'Rohith',
        'lastName': 'Gowda',
        'phoneNumber': digits,
        'phone': digits,
        'countryCode': '+91',
      },
      'classrooms': {
        'cls_new': {
          'classroomId': 'cls_new',
          'classroomName': '5 A',
          'type': 'CLASSROOM',
          'grade': '5',
          'section': 'A',
          'institutionName': 'KUVEMPU UNIVERSITY',
          'programmes': [
            {'programmeId': 'prg_new', 'displayName': 'Some Programme'},
          ],
        },
      },
    });

/// The same number, but already stamped with a DIFFERENT teacher's uid.
Teacher recordLinkedToSomeoneElse() => Teacher.fromMap('tch_other_doc', {
  'teacherMeta': {
    'uid': kOtherUid,
    'firstName': 'Someone',
    'lastName': 'Else',
    'phoneNumber': kNewDigits,
    'phone': kNewDigits,
  },
  'classrooms': {
    'cls_theirs': {
      'classroomId': 'cls_theirs',
      'classroomName': 'Not Yours',
      'institutionName': 'Other School',
      'programmes': [
        {'programmeId': 'prg_theirs', 'displayName': 'Theirs'},
      ],
    },
  },
});

void main() {
  group('subscriberDigits', () {
    test('takes the last ten digits of an E.164 number', () {
      expect(Teacher.subscriberDigits('+919481635184'), '9481635184');
    });

    test('accepts a bare ten-digit number unchanged', () {
      expect(Teacher.subscriberDigits('9481635184'), '9481635184');
    });

    test('ignores spaces, dashes and brackets', () {
      expect(Teacher.subscriberDigits('+91 94816-35184'), '9481635184');
    });

    test('is null for anything too short to be a number', () {
      // Null rather than a guess: a wrong guess matches the wrong teacher.
      for (final input in [null, '', '  ', '12345', '+91', 'not a number']) {
        expect(
          Teacher.subscriberDigits(input),
          isNull,
          reason: 'expected null for ${input == null ? 'null' : '"$input"'}',
        );
      }
    });
  });

  group('the record is found by number when no uid is stamped', () {
    test('THE REGRESSION: a web-registered teacher gets their classrooms',
        () async {
      // Exactly the reported case: created in the web app, signed into this one,
      // dashboard showed 0/0/0 with a "not linked" banner.
      final firestore = FakeFirestoreService(
        teachersByUid: const {}, // nothing linked by uid
        teachersByPhone: {kNewDigits: unlinkedRecord()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: kNewPhoneE164);

      expect(dashboard.isTeacherNotLinked, isFalse,
          reason: 'still reporting not-linked with a record on the number');
      expect(dashboard.account!.classroomCount, 1);
      expect(dashboard.account!.displayName, 'Rohith Gowda');
      expect(dashboard.account!.institutionName, 'KUVEMPU UNIVERSITY');
    });

    test('the uid is still tried first, and wins when it matches', () async {
      final linked = Teacher.fromMap('tch_linked', {
        'teacherMeta': {'uid': kNewUid, 'firstName': 'By', 'lastName': 'Uid'},
        'classrooms': {
          'a': {'classroomId': 'a', 'institutionName': 'S', 'programmes': []},
          'b': {'classroomId': 'b', 'institutionName': 'S', 'programmes': []},
        },
      });
      final firestore = FakeFirestoreService(
        teachersByUid: {kNewUid: linked},
        teachersByPhone: {kNewDigits: unlinkedRecord()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: kNewPhoneE164);

      // Two classrooms is the uid record; the phone record has one.
      expect(dashboard.account!.classroomCount, 2);
      expect(dashboard.account!.displayName, 'By Uid');
    });

    test('the phone reaches the service on every load', () async {
      final firestore = FakeFirestoreService(
        teachersByUid: const {},
        teachersByPhone: {kNewDigits: unlinkedRecord()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: kNewPhoneE164);

      expect(firestore.requestedPhoneNumbers, [kNewPhoneE164]);
    });

    test('retry redoes the lookup WITH the number, not just the uid', () async {
      // The phone is half of how the record is found, so a retry that dropped it
      // would fail for every unlinked teacher.
      final firestore = FakeFirestoreService(
        teachersByUid: const {},
        teachersByPhone: {kNewDigits: unlinkedRecord()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: kNewPhoneE164);
      await dashboard.retry();

      expect(firestore.requestedPhoneNumbers, [kNewPhoneE164, kNewPhoneE164]);
      expect(dashboard.account!.classroomCount, 1);
    });
  });

  group('the fallback refuses somebody else\'s record', () {
    test('a record stamped with another uid is NOT matched by number',
        () async {
      // Recycled numbers are real. Returning this record would show one teacher
      // another teacher's classrooms.
      final firestore = FakeFirestoreService(
        teachersByUid: const {},
        teachersByPhone: {kNewDigits: recordLinkedToSomeoneElse()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: kNewPhoneE164);

      expect(dashboard.isTeacherNotLinked, isTrue);
      expect(dashboard.classrooms, isEmpty);
      expect(dashboard.account!.classroomCount, 0);
    });

    test('a record stamped with THIS uid is matched by number', () async {
      // Harmless and correct: same person, already linked.
      final mine = Teacher.fromMap('tch_mine', {
        'teacherMeta': {
          'uid': kNewUid,
          'firstName': 'Rohith',
          'lastName': 'Gowda',
          'phoneNumber': kNewDigits,
        },
        'classrooms': {
          'c': {'classroomId': 'c', 'institutionName': 'S', 'programmes': []},
        },
      });
      final firestore = FakeFirestoreService(
        teachersByUid: const {},
        teachersByPhone: {kNewDigits: mine},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: kNewPhoneE164);

      expect(dashboard.account!.classroomCount, 1);
    });
  });

  group('nothing to match on', () {
    test('no phone on the account falls back to not-linked', () async {
      // A Google sign-in with no number attached. Stop rather than guess.
      final firestore = FakeFirestoreService(
        teachersByUid: const {},
        teachersByPhone: {kNewDigits: unlinkedRecord()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid);

      expect(dashboard.isTeacherNotLinked, isTrue);
    });

    test('a different number matches nothing', () async {
      final firestore = FakeFirestoreService(
        teachersByUid: const {},
        teachersByPhone: {kNewDigits: unlinkedRecord()},
      );
      final dashboard = DashboardProvider(firestore: firestore);

      await dashboard.load(kNewUid, phoneNumber: '+919000000000');

      expect(dashboard.isTeacherNotLinked, isTrue);
    });
  });
}
