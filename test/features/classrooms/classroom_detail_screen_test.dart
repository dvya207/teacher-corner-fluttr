import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_provider.dart';
import 'package:tc_starter/features/classrooms/classroom_detail_screen.dart';
import 'package:tc_starter/features/classrooms/widgets/activity_card.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _lu = 'lu_magnetic_pen_stand';
const _wf = 'wf_mps_v1';
const _prog = 'prog_tip_2026';

Classroom classroom7A() => Classroom.fromMap('cls_oak_7a', {
      'classroomName': '7 A',
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

Classroom stemClub() => Classroom.fromMap('cls_oak_et', {
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

LearningUnit unit() => LearningUnit.fromMap(_lu, {
      'learningUnitDisplayName': 'Magnetic Pen Stand',
      'type': 'TACtivity',
      'shortDescription': 'Build a pen stand that holds itself up with magnets.',
      'stepCount': 6,
      'subjectName': 'Science',
    });

Future<void> pumpDetail(
  WidgetTester tester, {
  required FakeFirestoreService firestore,
  String classroomId = 'cls_oak_7a',
  bool settle = true,
  Duration timeout = const Duration(seconds: 15),
  Size surfaceSize = const Size(360, 800),
}) =>
    pumpScreen(
      tester,
      settle: settle,
      surfaceSize: surfaceSize,
      providers: [
        ChangeNotifierProvider<ClassroomDetailProvider>(
          create: (_) => ClassroomDetailProvider(
            firestore: firestore,
            timeout: timeout,
          ),
        ),
      ],
      child: ClassroomDetailScreen(classroomId: classroomId),
    );

void main() {
  setUp(initLocalizationForTest);

  group('loaded', () {
    testWidgets('shows the programme and the units inside it', (tester) async {
      await pumpDetail(
        tester,
        firestore: FakeFirestoreService(
          classrooms: [classroom7A()],
          learningUnits: [unit()],
        ),
      );

      expect(find.text('7 A'), findsOneWidget);
      // Programme heading is upper-cased by TcSectionLabel.
      expect(find.text('TIP 2026'), findsOneWidget);
      expect(find.byType(ActivityCard), findsOneWidget);
      expect(find.text('Magnetic Pen Stand'), findsOneWidget);
      expect(find.textContaining('6 steps'), findsOneWidget);
    });

    testWidgets('shows the student count from the classroom document',
        (tester) async {
      await pumpDetail(
        tester,
        firestore: FakeFirestoreService(
          classrooms: [classroom7A()],
          learningUnits: [unit()],
        ),
      );

      expect(find.text('32'), findsOneWidget);
      expect(find.text('Students'), findsOneWidget);
    });

    testWidgets('the STEM club renders with no "null" anywhere',
        (tester) async {
      await pumpDetail(
        tester,
        classroomId: 'cls_oak_et',
        firestore: FakeFirestoreService(
          classrooms: [stemClub()],
          learningUnits: [unit()],
        ),
      );

      expect(find.text('Oak ET Club'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
      expect(find.textContaining('Grade'), findsNothing);
      // Its map-form workflowIds still produced the activity.
      expect(find.byType(ActivityCard), findsOneWidget);
    });

    testWidgets('omits the student tile when the count is unknown',
        (tester) async {
      await pumpDetail(
        tester,
        classroomId: 'cls_bare',
        firestore: FakeFirestoreService(
          classrooms: [Classroom.fromMap('cls_bare', {'classroomName': '8 B'})],
        ),
      );

      // An unknown student count is a statement about our read, so the tile is
      // omitted entirely rather than showing "0 Students".
      expect(find.text('Students'), findsNothing);
      // Zero programmes, by contrast, is something we actually know, so that
      // tile does show 0. The two cases are deliberately different.
      expect(find.text('Programmes'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('loading shows a spinner', (tester) async {
      final gate = Completer<void>();
      await pumpDetail(
        tester,
        firestore: FakeFirestoreService(gate: gate),
        settle: false,
        timeout: const Duration(milliseconds: 50),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a deleted classroom says so instead of erroring',
        (tester) async {
      await pumpDetail(
        tester,
        classroomId: 'cls_gone',
        firestore: FakeFirestoreService(),
      );

      expect(find.text('Classroom not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('no programmes shows an empty state, not a blank sheet',
        (tester) async {
      await pumpDetail(
        tester,
        classroomId: 'cls_bare',
        firestore: FakeFirestoreService(
          classrooms: [Classroom.fromMap('cls_bare', {'classroomName': '8 B'})],
        ),
      );

      expect(find.text('No programmes yet'), findsOneWidget);
    });

    testWidgets('a failed load offers a Retry that retries', (tester) async {
      final fake = FakeFirestoreService(throwsOnClassroom: StateError('boom'));
      await pumpDetail(tester, firestore: fake);

      expect(find.text('Could not load this classroom'), findsOneWidget);
      expect(fake.classroomReads, 1);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(fake.classroomReads, 2);
    });

    testWidgets('a unit whose document is missing is called out, not blank',
        (tester) async {
      await pumpDetail(
        tester,
        firestore: FakeFirestoreService(
          classrooms: [classroom7A()],
          learningUnits: const [],
        ),
      );

      expect(find.text('This activity could not be loaded.'), findsOneWidget);
      expect(find.textContaining('null'), findsNothing);
    });
  });

  group('surviving the device', () {
    testWidgets('does not overflow in landscape', (tester) async {
      await pumpDetail(
        tester,
        firestore: FakeFirestoreService(
          classrooms: [classroom7A()],
          learningUnits: [unit()],
        ),
        surfaceSize: const Size(800, 360),
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at the clamped maximum font size',
        (tester) async {
      await pumpScreen(
        tester,
        textScaler: const TextScaler.linear(3.0),
        providers: [
          ChangeNotifierProvider<ClassroomDetailProvider>(
            create: (_) => ClassroomDetailProvider(
              firestore: FakeFirestoreService(
                classrooms: [classroom7A()],
                learningUnits: [unit()],
              ),
            ),
          ),
        ],
        child: const ClassroomDetailScreen(classroomId: 'cls_oak_7a'),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
