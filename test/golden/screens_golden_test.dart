import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/auth/login_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_list_screen.dart';
import 'package:tc_starter/features/classrooms/classroom_provider.dart';
import 'package:tc_starter/features/dashboard/dashboard_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_screen.dart';
import 'package:tc_starter/features/dashboard/dashboard_screen.dart';
import 'package:tc_starter/features/evidence/evidence_panel.dart';
import 'package:tc_starter/features/evidence/evidence_provider.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_provider.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_screen.dart';
import 'package:tc_starter/features/shell/not_built_screen.dart';
import 'package:tc_starter/features/startup/startup_failure_screen.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/core/services/evidence_storage.dart';
import 'package:tc_starter/core/services/photo_picker.dart';
import 'dart:io';
import 'package:tc_starter/core/models/assignment_evidence.dart';
import 'package:tc_starter/features/profile/profile_screen.dart';
import 'package:tc_starter/features/splash/splash_screen.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

/// Renders every screen and state to a PNG under `test/golden/goldens/`.
///
/// Regenerate with:
///   flutter test --update-goldens test/golden/screens_golden_test.dart
///
/// These are for LOOKING at. They are rendered against fake data on a 360x800
/// surface, so they show layout, type and colour, and they prove nothing about
/// whether the real reads work.
Teacher aTeacher() => Teacher.fromMap('uid_1', {
      'name': 'Intern Teacher',
      'teacherMeta': {
        'firstName': 'Divya',
        'lastName': 'Jain',
        'institutionName': 'Test School Oak',
        'designation': 'Teacher',
      },
      'classrooms': {
        'cls_oak_7a': {
          'classroomName': '7 A',
          'type': 'CLASSROOM',
          'grade': 7,
          'section': 'A',
          'institutionName': 'Test School Oak',
          'programmes': {
            'prog_tip_2026': {'displayName': 'TIP 2026'},
          },
        },
        'cls_oak_et': {
          'stemClubName': 'Oak ET Club',
          'type': 'STEM-CLUB',
          'grade': 'ET',
          'institutionName': 'Test School Oak',
          'programmes': {
            'prog_tip_2026': {'displayName': 'TIP 2026'},
          },
        },
      },
    });

List<Classroom> theClassrooms() => [
      Classroom.fromMap('cls_oak_7a', {
        'classroomName': '7 A',
        'grade': 7,
        'section': 'A',
        'board': 'CBSE',
        'institutionName': 'Test School Oak',
        'studentCounter': 32,
      }),
      Classroom.fromMap('cls_oak_et', {
        'stemClubName': 'Oak ET Club',
        'type': 'STEM-CLUB',
        'grade': 'ET',
        'institutionName': 'Test School Oak',
        'studentCounter': 12,
      }),
    ];

/// The classroom as the DETAIL screen sees it: with a programme, and the
/// workflow binding that programme carries.
Classroom detailClassroom() => Classroom.fromMap('cls_oak_7a', {
      'classroomName': '7 A',
      'grade': 7,
      'section': 'A',
      'board': 'CBSE',
      'institutionName': 'Test School Oak',
      'studentCounter': 32,
      'programmes': {
        'prog_tip_2026': {
          'displayName': 'TIP 2026',
          'workflowIds': [
            {
              'learningUnitId': 'lu_magnetic_pen_stand',
              'workflowId': 'wf_mps_v1',
            },
          ],
        },
      },
    });

LearningUnit theUnit() => LearningUnit.fromMap('lu_magnetic_pen_stand', {
      'learningUnitDisplayName': 'Magnetic Pen Stand',
      'type': 'TACtivity',
      'shortDescription':
          'Build a pen stand that holds itself up with magnets, then explain '
          'why it does not fall over.',
      'stepCount': 6,
      'subjectName': 'Science',
    });

Workflow theWorkflow() => Workflow.fromMap('wf_mps_v1', {
      'steps': [
        {'workflowStepId': 's2', 'workflowStepName': 'Gather materials',
          'sequenceNumber': 2, 'workflowStepDuration': 5,
          'canSkipWorkflowStep': true,
          'contents': [
            {'contentName': 'Material List', 'contentCategory': 'material',
             'resourcePath': ''},
          ]},
        {'workflowStepId': 's1', 'workflowStepName': 'Introduce the problem',
          'sequenceNumber': 1, 'workflowStepDuration': 10,
          'contents': [
            {'contentName': 'Guide', 'contentCategory': 'guide',
             'resourcePath': ''},
            {'contentName': 'Diagram', 'contentCategory': 'image',
             'contentType': 'image', 'resourcePath': 'luImages/mps_intro.png'},
          ]},
        {'workflowStepId': 's3', 'workflowStepName': 'Build it',
          'sequenceNumber': 3, 'workflowStepDuration': 25,
          'contents': <dynamic>[]},
        {'workflowStepId': 's6', 'workflowStepName': 'Capture evidence',
          'sequenceNumber': 6, 'allowArtefactUpload': true,
          'assignmentId': 'asg_mps_evidence',
          'contents': [
            {'contentName': 'Photo evidence', 'contentCategory': 'assignment',
             'assignmentType': 'UPLOAD', 'assignmentId': 'asg_mps_evidence',
             'resourcePath': ''},
          ]},
      ],
    });

class _NoopStorage implements EvidenceStorage {
  @override
  Future<String> upload({
    required String storagePath,
    required File file,
    String contentType = 'image/jpeg',
  }) async =>
      'https://example/x';
  @override
  Future<void> delete(String storagePath) async {}
}

class _NoPicker implements PhotoPicker {
  @override
  Future<PickedPhoto?> pick(PhotoSource source) async => null;
}

void main() {
  setUpAll(loadAppFonts);
  setUp(initLocalizationForTest);

  Future<void> shoot(WidgetTester tester, String name) async {
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('auth', () {
    testWidgets('splash', (tester) async {
      await pumpScreen(tester, child: const SplashScreen(), settle: false);
      // Let the spinner sweep, so the image shows an arc rather than the dot it
      // is on its very first frame.
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, '01_splash');
    });

    testWidgets('login, entering a number', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(create: (_) => StubAuthProvider()),
        ],
        child: const LoginScreen(),
      );
      await shoot(tester, '02_login_phone');
    });

    testWidgets('login, entering the code', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(
              stubStage: LoginStage.codeEntry,
              stubPendingPhone: '+919999900000',
            ),
          ),
        ],
        child: const LoginScreen(),
      );
      await shoot(tester, '03_login_code');
    });

    testWidgets('login, showing a wrong-code error', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(
              stubStage: LoginStage.codeEntry,
              stubPendingPhone: '+919999900000',
              stubErrorKey: 'auth.error_invalid_code',
            ),
          ),
        ],
        child: const LoginScreen(),
      );
      await shoot(tester, '04_login_error');
    });
  });

  group('dashboard', () {
    Future<void> pumpDash(
      WidgetTester tester, {
      required FakeFirestoreService firestore,
      bool settle = true,
      Duration timeout = const Duration(seconds: 15),
    }) =>
        pumpScreen(
          tester,
          settle: settle,
          providers: [
            ChangeNotifierProvider<AuthProvider>(
                create: (_) => StubAuthProvider()),
            ChangeNotifierProvider<DashboardProvider>(
              create: (_) =>
                  DashboardProvider(firestore: firestore, timeout: timeout),
            ),
          ],
          child: const DashboardScreen(),
        );

    testWidgets('loading', (tester) async {
      final gate = Completer<void>();
      await pumpDash(
        tester,
        firestore: FakeFirestoreService(gate: gate),
        settle: false,
        timeout: const Duration(seconds: 5),
      );
      await tester.pump(const Duration(milliseconds: 300));
      await shoot(tester, '05_dashboard_loading');
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('loaded', (tester) async {
      await pumpDash(tester, firestore: FakeFirestoreService(teacher: aTeacher()));
      await shoot(tester, '06_dashboard_loaded');
    });

    testWidgets('error', (tester) async {
      await pumpDash(
        tester,
        firestore: FakeFirestoreService(throws: StateError('boom')),
      );
      await shoot(tester, '07_dashboard_error');
    });

    testWidgets('signed in, no profile provisioned', (tester) async {
      await pumpDash(tester, firestore: FakeFirestoreService());
      await shoot(tester, '08_dashboard_no_profile');
    });
  });

  group('classrooms', () {
    Future<void> pumpList(
      WidgetTester tester, {
      required FakeFirestoreService firestore,
      Size surfaceSize = const Size(360, 800),
    }) =>
        pumpScreen(
          tester,
          surfaceSize: surfaceSize,
          providers: [
            ChangeNotifierProvider<AuthProvider>(
                create: (_) => StubAuthProvider()),
            ChangeNotifierProvider<ClassroomProvider>(
              create: (_) => ClassroomProvider(firestore: firestore),
            ),
          ],
          child: const ClassroomListScreen(),
        );

    FakeFirestoreService populated() => FakeFirestoreService(
          teacher: aTeacher(),
          classrooms: theClassrooms(),
        );

    testWidgets('the list', (tester) async {
      await pumpList(tester, firestore: populated());
      await shoot(tester, '09_classrooms_list');
    });

    testWidgets('searching by school', (tester) async {
      await pumpList(tester, firestore: populated());
      await tester.enterText(find.byType(TextField), 'oak 7');
      await tester.pumpAndSettle();
      await shoot(tester, '10_classrooms_search');
    });

    testWidgets('search matching nothing', (tester) async {
      await pumpList(tester, firestore: populated());
      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();
      await shoot(tester, '11_classrooms_no_matches');
    });

    testWidgets('a teacher with no classrooms', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
      );
      await shoot(tester, '12_classrooms_empty');
    });

    testWidgets('failed to load', (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(throws: StateError('boom')),
      );
      await shoot(tester, '13_classrooms_error');
    });

    testWidgets('the empty state in landscape, after the overflow fix',
        (tester) async {
      await pumpList(
        tester,
        firestore: FakeFirestoreService(teacher: Teacher.fromMap('uid_1', {})),
        surfaceSize: const Size(800, 360),
      );
      await shoot(tester, '14_classrooms_empty_landscape');
    });
  });

  group('profile', () {
    testWidgets('with a loaded teacher', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(stubTeacher: aTeacher()),
          ),
        ],
        child: const ProfileScreen(),
      );
      await shoot(tester, '15_profile');
    });
  });

  group('classroom', () {
    testWidgets('detail', (tester) async {
      await pumpScreen(
        tester,
        providers: [
          ChangeNotifierProvider<ClassroomDetailProvider>(
            create: (_) => ClassroomDetailProvider(
              firestore: FakeFirestoreService(
                classrooms: [detailClassroom()],
                learningUnits: [theUnit()],
              ),
            ),
          ),
        ],
        child: const ClassroomDetailScreen(classroomId: 'cls_oak_7a'),
      );
      await shoot(tester, '16_classroom_detail');
    });
  });

  group('learning unit', () {
    Future<void> pumpLu(WidgetTester tester) => pumpScreen(
          tester,
          providers: [
            ChangeNotifierProvider<AuthProvider>(
                create: (_) => StubAuthProvider()),
            ChangeNotifierProvider<LearningUnitProvider>(
              create: (_) => LearningUnitProvider(
                firestore: FakeFirestoreService(
                  learningUnits: [theUnit()],
                  workflows: [theWorkflow()],
                ),
              ),
            ),
          ],
          child: const LearningUnitScreen(
            learningUnitId: 'lu_magnetic_pen_stand',
            workflowId: 'wf_mps_v1',
            classroomId: 'cls_oak_7a',
            programmeId: 'prog_tip_2026',
          ),
        );

    testWidgets('steps and content tabs', (tester) async {
      await pumpLu(tester);
      await shoot(tester, '17_learning_unit');
    });
  });

  group('evidence', () {
    Future<void> pumpEvidence(
      WidgetTester tester,
      AssignmentEvidence? existing,
    ) =>
        pumpScreen(
          tester,
          providers: [
            ChangeNotifierProvider<EvidenceProvider>(
              create: (_) => EvidenceProvider(
                firestore: FakeFirestoreService(evidence: existing),
                storage: _NoopStorage(),
                picker: _NoPicker(),
                uid: 'uid_teacher',
                classroomId: 'cls_oak_7a',
                programmeId: 'prog_tip_2026',
                learningUnitId: 'lu_magnetic_pen_stand',
                assignmentId: 'asg_mps_evidence',
                displayName: 'Photo evidence',
                clock: () => 1787132584464,
              ),
            ),
          ],
          child: const Scaffold(body: EvidencePanel()),
        );

    testWidgets('nothing added yet', (tester) async {
      await pumpEvidence(tester, null);
      await shoot(tester, '18_evidence_empty');
    });

    testWidgets('with photos already submitted', (tester) async {
      await pumpEvidence(
        tester,
        const AssignmentEvidence(
          assignmentId: 'asg_mps_evidence',
          displayName: 'Photo evidence',
          photoUrls: ['https://example/a', 'https://example/b'],
          storagePaths: [
            'activityEvidence/cls_oak_7a/lu_magnetic_pen_stand/u_1_0.jpg',
            'activityEvidence/cls_oak_7a/lu_magnetic_pen_stand/u_1_1.jpg',
          ],
        ),
      );
      await shoot(tester, '19_evidence_submitted');
    });
  });

  group('startup', () {
    testWidgets('a failed start offers a retry instead of hanging',
        (tester) async {
      await pumpScreen(
        tester,
        child: StartupFailureScreen(onRetry: () async {}),
      );
      await shoot(tester, '20_startup_failure');
    });
  });

  group('shell', () {
    testWidgets('the dashboard inside the bottom nav', (tester) async {
      // The only golden pumped through a real router, because MainShell derives
      // its selected tab from the route rather than from state.
      await pumpShell(
        tester,
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => StubAuthProvider(),
          ),
          ChangeNotifierProvider<DashboardProvider>(
            create: (_) => DashboardProvider(
              firestore: FakeFirestoreService(
                teacher: aTeacher(),
                classrooms: theClassrooms(),
              ),
            ),
          ),
        ],
        routes: {'/dashboard': (context) => const DashboardScreen()},
      );
      await shoot(tester, '21_shell_dashboard');
    });

    testWidgets('a tab outside this slice', (tester) async {
      await pumpShell(
        tester,
        initialLocation: '/reports',
        routes: {
          '/reports': (context) => const NotBuiltScreen(
            titleKey: 'nav.reports',
            icon: Icons.bar_chart_outlined,
          ),
        },
      );
      await shoot(tester, '22_shell_reports');
    });
  });
}
