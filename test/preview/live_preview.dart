// NOT A TEST. Named `live_preview.dart` rather than `*_test.dart` so
// `flutter test` does not pick it up with the suite.
//
// Renders the app's screens against the REAL data currently in
// `teacher-corner-dev`, so the implementation can be reviewed visually without a
// device and without completing a phone OTP sign-in.
//
// The values below were read out of the live database read-only and pasted here.
// They are a SNAPSHOT FOR RENDERING ONLY — nothing in `lib/` contains any of
// them, and the app resolves every one of them at runtime from the signed-in
// uid. If the live data changes, these images go stale; re-read and update them.
//
// Regenerate with:
//   flutter test --update-goldens test/preview/live_preview.dart
//
// Images land in test/preview/shots/.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/programme.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/core/models/teacher_profile.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_list_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_screen.dart';
import 'package:tc_starter/features/profile/help_guide_screen.dart';
import 'package:tc_starter/features/profile/profile_screen.dart';
import 'package:tc_starter/features/programmes/programme_detail_provider.dart';
import 'package:tc_starter/features/programmes/programme_detail_screen.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

/// The signed-in teacher's uid, as Firebase Auth reports it for the registered
/// phone number.
const String kUid = '7vbKdBSqG3YRI6X1GzFNeQD24Rm1';

/// `users/{uid}` — the authoritative profile, after the approved name
/// correction.
TeacherProfile liveProfile() => TeacherProfile.fromMap(kUid, {
  'firstName': 'Divya',
  'lastName': 'Jain',
  'phone': '6362398700',
  'countryCode': '+91',
  'institutionId': 'Fe2yDslU74Cp9SfOclda',
  'institutionName': 'KUVEMPU UNIVERSITY',
  'grade': '9',
  'section': 'B',
  'programmeId': 'wCDSB6IbnQAlAjJ4iXLE',
  'programmeName': 'dummy',
  'board': 'CBSE',
  'ApprovedStatus': true,
});

/// `teachers/hY66fSjdzmYM06ciOIdH` — the linked teaching record. Note the
/// document id is NOT the uid, and `programmes` is an array.
Teacher liveTeaching() => Teacher.fromMap('hY66fSjdzmYM06ciOIdH', {
  'ownerId': kUid,
  'teacherMeta': {
    'uid': kUid,
    'firstName': 'Divya',
    'lastName': 'Jain',
    'email': 'divya.jain@intern.thinktac.com',
    'phone': '6362398700',
    'phoneNumber': '6362398700',
    'countryCode': '+91',
  },
  'classrooms': {
    'pOy1JGWhNzLFY9uVBzHP': {
      'classroomId': 'pOy1JGWhNzLFY9uVBzHP',
      'classroomName': 'Pre-primary 2',
      'type': 'CLASSROOM',
      'grade': 'Pre-primary 2',
      'section': 'L',
      'institutionId': 'Fe2yDslU74Cp9SfOclda',
      'institutionName': 'KUVEMPU UNIVERSITY',
      'userRole': 'ThinkTac Coach',
      'programmes': [
        {'programmeId': '96HxMlMZzyGhyh0vpQhl', 'displayName': 'abcd'},
      ],
    },
    'vk2gxR1p6FcOAfZb1Qc6': {
      'classroomId': 'vk2gxR1p6FcOAfZb1Qc6',
      'classroomName': 'Pre-primary 1',
      'type': 'CLASSROOM',
      'grade': 'Pre-primary 1',
      'section': 'Z',
      'institutionId': 'Fe2yDslU74Cp9SfOclda',
      'institutionName': 'KUVEMPU UNIVERSITY',
      'userRole': 'ThinkTac Coach',
      'programmes': [
        {'programmeId': '4E5Zk9uWtI0sLOEWQxS4', 'displayName': 'xyz'},
      ],
    },
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
  },
});

/// The authoritative `classrooms/{id}` documents. `studentCounter` is genuinely
/// 0 on all three, and `workflowIds` is absent on every programme entry, which
/// is why no classroom lists any activity.
List<Classroom> liveClassrooms() => [
  Classroom.fromMap('0BjL4c151I9W3xZ34ZEP', {
    'classroomName': '9 B',
    'type': 'CLASSROOM',
    'grade': '9',
    'section': 'B',
    'board': 'CBSE',
    'classroomCode': '001',
    'institutionName': 'KUVEMPU UNIVERSITY',
    'studentCounter': 0,
    'programmes': {
      'JYn7IPw5JSdvRSNKUuC9': {
        'displayName': 'Future Innovators',
        'programmeCode': 'P10010',
      },
      'zowFv4U4Xr6rttXxoajq': {
        'displayName': 'Space Science Explorer',
        'programmeCode': 'P10005',
      },
    },
  }),
  Classroom.fromMap('pOy1JGWhNzLFY9uVBzHP', {
    'classroomName': 'Pre-primary 2',
    'type': 'CLASSROOM',
    'grade': 'Pre-primary 2',
    'section': 'L',
    'board': 'CBSE',
    'classroomCode': '006',
    'institutionName': 'KUVEMPU UNIVERSITY',
    'studentCounter': 0,
    'programmes': {
      '96HxMlMZzyGhyh0vpQhl': {
        'displayName': 'abcd',
        'programmeCode': 'P10015',
      },
    },
  }),
  Classroom.fromMap('vk2gxR1p6FcOAfZb1Qc6', {
    'classroomName': 'Pre-primary 1',
    'type': 'CLASSROOM',
    'grade': 'Pre-primary 1',
    'section': 'Z',
    'board': 'CBSE',
    'classroomCode': '008',
    'institutionName': 'KUVEMPU UNIVERSITY',
    'studentCounter': 0,
    'programmes': {
      '4E5Zk9uWtI0sLOEWQxS4': {
        'displayName': 'xyz',
        'programmeCode': 'P10017',
      },
    },
  }),
];

/// The real `programmes/{id}` catalogue documents, VERBATIM, read field by
/// field out of the live database. Nothing here is written for the preview.
///
/// Three of them happen to exercise rules the model has, which is why they are
/// worth keeping as the fixture:
///
///   * Future Innovators displays as "Future Innovators" but is NAMED
///     "Future Innovators Academy", so the screen's "show the catalogue name
///     only when it differs from the title" rule fires.
///   * `abcd` has an EMPTY description, so the About section is omitted rather
///     than rendered blank.
///   * Space Science Explorer belongs to a different institution from the
///     classroom that runs it, which the data genuinely allows.
List<Programme> liveProgrammes() => [
  Programme.fromMap('JYn7IPw5JSdvRSNKUuC9', {
    'displayName': 'Future Innovators',
    'programmeName': 'Future Innovators Academy',
    'programmeCode': 'P10010',
    'programmeDescription': 'Future Innovators',
    'institutionId': 'Fe2yDslU74Cp9SfOclda',
    'institutionName': 'KUVEMPU UNIVERSITY',
    'grades': ['9', '10'],
    'age': <String>[],
    'learningUnitsIds': <String>[],
    'assignmentIds': <String>[],
    'programmeStatus': 'LIVE',
    'type': 'STEM-CLUB',
    'programmeImagePath': '',
  }),
  Programme.fromMap('zowFv4U4Xr6rttXxoajq', {
    'displayName': 'Space Science Explorer',
    'programmeName': 'Space Science Explorer',
    'programmeCode': 'P10005',
    'programmeDescription': 'Space Science Explorer',
    'institutionId': 'x1zSdPbbjnxjkT27qqg5',
    'institutionName': 'DAYANANDA SAGAR UNIVERSITY',
    'grades': ['6'],
    'age': <String>[],
    'learningUnitsIds': <String>[],
    'assignmentIds': <String>[],
    'programmeStatus': 'LIVE',
    'type': 'REGULAR',
    'programmeImagePath': '',
  }),
  Programme.fromMap('96HxMlMZzyGhyh0vpQhl', {
    'displayName': 'abcd',
    'programmeName': 'abcd',
    'programmeCode': 'P10015',
    // Genuinely empty in the database.
    'programmeDescription': '',
    'institutionId': 'Fe2yDslU74Cp9SfOclda',
    'institutionName': 'KUVEMPU UNIVERSITY',
    'grades': ['5'],
    'age': <String>[],
    'learningUnitsIds': <String>[],
    'assignmentIds': <String>[],
    'programmeStatus': 'LIVE',
    'type': 'REGULAR',
    'programmeImagePath': '',
  }),
];

TeacherAccount liveAccount() =>
    TeacherAccount(uid: kUid, profile: liveProfile(), teaching: liveTeaching());

FakeFirestoreService liveFirestore() => FakeFirestoreService(
  teachersByUid: {kUid: liveTeaching()},
  profilesByUid: {kUid: liveProfile()},
  classroomsByUid: {kUid: liveClassrooms()},
  programmes: liveProgrammes(),
);

/// A second teacher who is authenticated but whose uid is on no `teachers`
/// document, so the "not linked" state can be reviewed too.
const String kUnlinkedUid = 'uid_no_teacher_record_0001';

void main() {
  setUpAll(loadAppFonts);
  setUp(initLocalizationForTest);

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('shots/$name.png'),
    );
  }

  testWidgets('dashboard, live data', (tester) async {
    final firestore = liveFirestore();
    final dashboard = DashboardProvider(firestore: firestore);
    await dashboard.load(kUid);

    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(stubUid: kUid, stubAccount: liveAccount()),
        ),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
      ],
      child: const DashboardScreen(),
    );
    await shoot(tester, '01_dashboard');
  });

  testWidgets('classrooms list, live data', (tester) async {
    final firestore = liveFirestore();
    final classrooms = ClassroomProvider(firestore: firestore);
    await classrooms.load(kUid);

    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(stubUid: kUid, stubAccount: liveAccount()),
        ),
        ChangeNotifierProvider<ClassroomProvider>.value(value: classrooms),
      ],
      child: const ClassroomListScreen(),
    );
    await shoot(tester, '02_classrooms');
  });

  testWidgets('profile, live data', (tester) async {
    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(stubUid: kUid, stubAccount: liveAccount()),
        ),
      ],
      child: const ProfileScreen(),
    );
    await shoot(tester, '03_profile');
  });

  testWidgets('dashboard, a teacher with no linked record', (tester) async {
    final firestore = liveFirestore(); // knows only kUid
    final dashboard = DashboardProvider(firestore: firestore);
    await dashboard.load(kUnlinkedUid);

    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(
            stubUid: kUnlinkedUid,
            stubAccount: const TeacherAccount(uid: kUnlinkedUid),
          ),
        ),
        ChangeNotifierProvider<DashboardProvider>.value(value: dashboard),
      ],
      child: const DashboardScreen(),
    );
    await shoot(tester, '04_dashboard_not_linked');
  });

  testWidgets('classroom detail, live data', (tester) async {
    final firestore = liveFirestore();
    final detail = ClassroomDetailProvider(firestore: firestore);
    await detail.load('0BjL4c151I9W3xZ34ZEP');

    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<ClassroomDetailProvider>.value(value: detail),
      ],
      child: const ClassroomDetailScreen(
        classroomId: '0BjL4c151I9W3xZ34ZEP',
      ),
    );
    await shoot(tester, '06_classroom_detail');
  });

  testWidgets('programme detail, live data', (tester) async {
    final firestore = liveFirestore();
    final detail = ProgrammeDetailProvider(firestore: firestore);
    await detail.load('JYn7IPw5JSdvRSNKUuC9');

    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<ProgrammeDetailProvider>.value(value: detail),
      ],
      child: const ProgrammeDetailScreen(
        programmeId: 'JYn7IPw5JSdvRSNKUuC9',
        classroomName: '9 B',
      ),
    );
    await shoot(tester, '07_programme_detail');
  });

  testWidgets('help and guide, top', (tester) async {
    // A tall surface, so the whole guide renders in one image rather than one
    // screenful of it.
    await pumpScreen(
      tester,
      child: const HelpGuideScreen(),
      surfaceSize: const Size(360, 2600),
    );
    await shoot(tester, '08_help_guide_top');
  });

  testWidgets('profile, a teacher with no linked record', (tester) async {
    await pumpScreen(
      tester,
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(
            stubUid: kUnlinkedUid,
            stubAccount: const TeacherAccount(uid: kUnlinkedUid),
          ),
        ),
      ],
      child: const ProfileScreen(),
    );
    await shoot(tester, '05_profile_not_linked');
  });
}
