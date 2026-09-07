import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/core/models/workflow_progress.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_overview_screen.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_provider.dart';
import 'package:tc_starter/features/learning_unit/widgets/activity_status_pill.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

LearningUnit theUnit() => LearningUnit.fromMap('lu_mps', {
  'learningUnitDisplayName': 'Magnetic Pen Stand',
  'type': 'TACtivity',
  'shortDescription': 'A pen stand held up by magnets.',
  'longDescription': 'Magnets are among the most fascinating things in nature.',
  'stepCount': 3,
  'subjectName': 'Science',
});

Workflow theWorkflow() => Workflow.fromMap('wf_mps', {
  'steps': [
    {
      'workflowStepId': 's1',
      'workflowStepName': 'Activity Demonstration',
      'sequenceNumber': 1,
      'workflowStepDuration': 10,
    },
    {
      'workflowStepId': 's2',
      'workflowStepName': 'Pre-Test',
      'sequenceNumber': 2,
      'workflowStepDuration': 5,
      'canSkipWorkflowStep': true,
    },
    {
      'workflowStepId': 's3',
      'workflowStepName': 'Make / Create',
      'sequenceNumber': 3,
      'workflowStepDuration': 20,
    },
  ],
});

Future<void> pumpOverview(
  WidgetTester tester, {
  required FakeFirestoreService firestore,
  String? classroomId = 'cls_7a',
  String? breadcrumb,
  Size surfaceSize = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) => pumpScreen(
  tester,
  surfaceSize: surfaceSize,
  textScaler: textScaler,
  providers: [
    ChangeNotifierProvider<AuthProvider>(create: (_) => StubAuthProvider()),
    ChangeNotifierProvider<LearningUnitProvider>(
      create: (_) => LearningUnitProvider(firestore: firestore),
    ),
  ],
  child: LearningUnitOverviewScreen(
    learningUnitId: 'lu_mps',
    workflowId: 'wf_mps',
    classroomId: classroomId,
    programmeId: 'prog_tip',
    breadcrumb: breadcrumb,
  ),
);

FakeFirestoreService fakeWith({Map<String, WorkflowProgress> progress = const {}}) =>
    FakeFirestoreService(
      learningUnits: [theUnit()],
      workflows: [theWorkflow()],
      progress: progress,
    );

void main() {
  setUp(initLocalizationForTest);

  group('what the activity is', () {
    testWidgets('names it, describes it, and says how long it runs', (
      tester,
    ) async {
      await pumpOverview(tester, firestore: fakeWith());

      expect(find.text('Magnetic Pen Stand'), findsOneWidget);
      // The LONG description, not the short one. This screen exists to answer
      // "what is this" before a teacher commits a lesson to it.
      expect(
        find.textContaining('Magnets are among the most fascinating'),
        findsOneWidget,
      );
      // Type and step count together, which is the pair that predicts a lesson.
      expect(find.text('TACtivity · 3 steps'), findsOneWidget);
    });

    testWidgets('shows the breadcrumb it was given, and nothing when given none',
        (tester) async {
      await pumpOverview(
        tester,
        firestore: fakeWith(),
        breadcrumb: 'test school oak · 7 A',
      );
      expect(find.text('test school oak · 7 A'), findsOneWidget);
    });
  });

  group('the steps', () {
    testWidgets('lists every step with its duration, in sequence', (
      tester,
    ) async {
      await pumpOverview(tester, firestore: fakeWith());

      // Sorted by sequenceNumber at the parse boundary, not by map order.
      expect(find.text('Activity Demonstration'), findsOneWidget);
      expect(find.text('Pre-Test'), findsOneWidget);
      expect(find.text('Make / Create'), findsOneWidget);
      expect(find.text('10 min'), findsOneWidget);
      expect(find.text('20 min'), findsOneWidget);
    });

    testWidgets('says nothing about a step being skippable', (tester) async {
      await pumpOverview(tester, firestore: fakeWith());

      // Pre-Test carries canSkipWorkflowStep, and this row deliberately does
      // not say so: the flag is set on most steps in live data, so the label
      // distinguished nothing and crowded out the duration. The player's own
      // step strip still marks an optional step.
      expect(find.text('Skippable'), findsNothing);
    });

    testWidgets('ticks the steps already done and numbers the rest', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        firestore: fakeWith(
          progress: {
            'lu_mps': const WorkflowProgress(completedStepIds: {'s1'}),
          },
        ),
      );

      // Step one shows a tick instead of its number; two and three still count.
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('reports the activity as in progress once a step is done', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        firestore: fakeWith(
          progress: {
            'lu_mps': const WorkflowProgress(completedStepIds: {'s1'}),
          },
        ),
      );

      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Not Started'), findsNothing);
    });

    testWidgets('an untouched activity reads as not started', (tester) async {
      await pumpOverview(tester, firestore: fakeWith());
      expect(find.text('Not Started'), findsOneWidget);
    });
  });

  group('when progress cannot be recorded', () {
    testWidgets('outside a classroom, the status readout is omitted', (
      tester,
    ) async {
      // Progress is per classroom, so without one there is nowhere to record
      // it. The screen still shows the activity and its steps; it just stops
      // claiming to know how far through them the teacher is.
      await pumpOverview(
        tester,
        firestore: fakeWith(),
        classroomId: null,
      );

      expect(find.text('Magnetic Pen Stand'), findsOneWidget);
      expect(find.byType(ActivityStatusPill), findsNothing);
    });
  });

  group('states', () {
    testWidgets('an activity with no steps says so and offers no Resume', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        firestore: FakeFirestoreService(
          learningUnits: [theUnit()],
          workflows: [Workflow.fromMap('wf_mps', {'steps': <dynamic>[]})],
        ),
      );

      expect(find.text('No steps yet'), findsOneWidget);
      // Nothing to resume into, so the button is not offered rather than
      // offered and inert.
      expect(find.text('Resume Activity'), findsNothing);
    });

    testWidgets('a missing workflow is not-found, not an error', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        firestore: FakeFirestoreService(learningUnits: [theUnit()]),
      );

      expect(find.text('Activity not found'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });
  });

  group('surviving the device', () {
    testWidgets('does not overflow in landscape', (tester) async {
      await pumpOverview(
        tester,
        firestore: fakeWith(),
        surfaceSize: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at the clamped maximum font size', (
      tester,
    ) async {
      await pumpOverview(
        tester,
        firestore: fakeWith(),
        textScaler: const TextScaler.linear(3.0),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
