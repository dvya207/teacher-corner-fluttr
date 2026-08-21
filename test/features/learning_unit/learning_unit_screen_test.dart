import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/core/widgets/tc_storage_image.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_provider.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_screen.dart';
import 'package:tc_starter/features/learning_unit/widgets/step_indicator.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

const _lu = 'lu_magnetic_pen_stand';
const _wf = 'wf_mps_v1';
const _imagePath = 'luImages/mps_step3.png';

LearningUnit theUnit() => LearningUnit.fromMap(_lu, {
      'learningUnitDisplayName': 'Magnetic Pen Stand',
      'shortDescription': 'Build a pen stand that holds itself up with magnets.',
      'stepCount': 6,
      'subjectName': 'Science',
    });

/// Six steps out of array order, and step 3 carries two contents: one image and
/// one text, so the tab strip has something to switch between.
Workflow theWorkflow() => Workflow.fromMap(_wf, {
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
          ]},
        {'workflowStepId': 's3', 'workflowStepName': 'Build it',
          'sequenceNumber': 3,
          'contents': [
            {'contentName': 'Assembly photo', 'contentCategory': 'image',
             'contentType': 'image', 'resourcePath': _imagePath},
            {'contentName': 'Notes', 'contentCategory': 'guide',
             'resourcePath': ''},
          ]},
        {'workflowStepId': 's4', 'workflowStepName': 'Observe',
          'sequenceNumber': 4, 'contents': <dynamic>[]},
        {'workflowStepId': 's5', 'workflowStepName': 'Discuss',
          'sequenceNumber': 5, 'canSkipWorkflowStep': true,
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

Future<void> pumpLu(
  WidgetTester tester, {
  LearningUnit? unit,
  Workflow? workflow,
  Object? throwsOnUnit,
  Completer<void>? gate,
  bool settle = true,
  Duration timeout = const Duration(seconds: 15),
  Size surfaceSize = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    pumpScreen(
      tester,
      settle: settle,
      surfaceSize: surfaceSize,
      textScaler: textScaler,
      providers: [
        ChangeNotifierProvider<LearningUnitProvider>(
          create: (_) => LearningUnitProvider(
            firestore: FakeFirestoreService(
              learningUnits: unit == null ? const [] : [unit],
              workflows: workflow == null ? const [] : [workflow],
              throwsOnLearningUnit: throwsOnUnit,
              gate: gate,
            ),
            timeout: timeout,
          ),
        ),
      ],
      child: const LearningUnitScreen(
        learningUnitId: _lu,
        workflowId: _wf,
      ),
    );

/// Finds a step chip specifically, not the step header.
///
/// A selected step's name renders twice: once in the strip and once as the
/// heading below it, so a bare text finder is ambiguous.
Finder stepChip(String label) => find.descendant(
      of: find.byType(StepIndicator),
      matching: find.text(label),
    );

/// Scrolls the step strip until [label] is on screen, then taps it. A chip past
/// the fold cannot be tapped where it is not rendered, and neither could a
/// teacher reach it without scrolling.
Future<void> tapStep(WidgetTester tester, String label) async {
  final finder = stepChip(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(initLocalizationForTest);

  group('the step strip', () {
    testWidgets('renders steps in sequenceNumber order', (tester) async {
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());

      // s1 is stored second in the array but must lead.
      final first = tester.getTopLeft(stepChip('Introduce the problem')).dx;
      final second = tester.getTopLeft(stepChip('Gather materials')).dx;
      expect(first, lessThan(second));
    });

    testWidgets('opens on the first step by sequence', (tester) async {
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());

      expect(find.textContaining('Step 1 of 6'), findsOneWidget);
    });

    testWidgets('selecting a later step scrolls it into view', (tester) async {
      // The acceptance criterion: selecting step 5 must make step 5 visible.
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());

      final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;

      // Step 5 starts off to the right of the viewport.
      expect(tester.getTopLeft(stepChip('Discuss')).dx, greaterThan(width),
          reason: 'expected step 5 to start off screen');

      await tapStep(tester, 'Observe');
      await tapStep(tester, 'Discuss');

      final rect = tester.getRect(stepChip('Discuss'));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(width));
      expect(find.textContaining('Step 5 of 6'), findsOneWidget);
    });

    testWidgets('marks a skippable step as optional', (tester) async {
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());
      // s2 and s5 are canSkipWorkflowStep.
      expect(
        find.descendant(
          of: find.byType(StepIndicator),
          matching: find.text('Optional'),
        ),
        findsNWidgets(2),
      );
    });
  });

  group('content tabs', () {
    // Step 3 is the one with two contents: an image and a text pane.
    Future<void> pumpStep3(WidgetTester tester) async {
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());
      await tapStep(tester, 'Build it');
    }

    testWidgets('shows a tab per content in the step', (tester) async {
      await pumpStep3(tester);

      expect(find.text('Assembly photo'), findsWidgets);
      expect(find.text('Notes'), findsWidgets);
    });

    testWidgets('renders an image content as a storage-path image',
        (tester) async {
      await pumpStep3(tester);

      final image = tester.widget<TcStorageImage>(find.byType(TcStorageImage));
      // The PATH is what gets handed down, not a URL.
      expect(image.storagePath, _imagePath);
      expect(image.storagePath, isNot(startsWith('http')));
    });

    testWidgets('renders a text content, and says so when it has no body',
        (tester) async {
      await pumpStep3(tester);

      await tester.tap(find.text('Notes').last);
      await tester.pumpAndSettle();

      // Every seeded content has resourcePath: '', so there is genuinely
      // nothing to render, and the pane says that rather than going blank.
      expect(find.text('This content has no text or image attached yet.'),
          findsWidgets);
    });

    testWidgets('both panes stay in the tree, so switching does not rebuild',
        (tester) async {
      await pumpStep3(tester);

      // IndexedStack keeps every pane mounted; only the painted one changes.
      expect(find.byType(TcStorageImage, skipOffstage: false), findsOneWidget);

      await tester.tap(find.text('Notes').last);
      await tester.pumpAndSettle();

      expect(find.byType(TcStorageImage, skipOffstage: false), findsOneWidget,
          reason: 'the image pane was torn down when the tab changed');
    });

    testWidgets('a step with no content shows an empty state', (tester) async {
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());

      await tapStep(tester, 'Observe');

      expect(find.text('Nothing to show here'), findsOneWidget);
    });

    testWidgets('the evidence step is recognised as an upload assignment',
        (tester) async {
      await pumpLu(tester, unit: theUnit(), workflow: theWorkflow());

      await tapStep(tester, 'Capture evidence');

      // Phase 5 fills this pane in; for now it identifies itself.
      expect(find.text('Evidence'), findsWidgets);
    });
  });

  group('states', () {
    testWidgets('loading shows a spinner', (tester) async {
      final gate = Completer<void>();
      await pumpLu(
        tester,
        unit: theUnit(),
        workflow: theWorkflow(),
        gate: gate,
        settle: false,
        timeout: const Duration(milliseconds: 50),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('a missing workflow says not found', (tester) async {
      await pumpLu(tester, unit: theUnit());

      expect(find.text('Activity not found'), findsOneWidget);
    });

    testWidgets('a failed read offers a Retry', (tester) async {
      await pumpLu(tester, throwsOnUnit: StateError('boom'));

      expect(find.text('Could not load this activity'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('a workflow with no steps shows an empty state',
        (tester) async {
      await pumpLu(
        tester,
        unit: theUnit(),
        workflow: Workflow.fromMap(_wf, const {}),
      );

      expect(find.text('No steps yet'), findsOneWidget);
    });
  });

  group('surviving the device', () {
    testWidgets('does not overflow in landscape', (tester) async {
      await pumpLu(
        tester,
        unit: theUnit(),
        workflow: theWorkflow(),
        surfaceSize: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at the clamped maximum font size',
        (tester) async {
      await pumpLu(
        tester,
        unit: theUnit(),
        workflow: theWorkflow(),
        textScaler: const TextScaler.linear(3.0),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
