import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/features/learning_unit/learning_unit_provider.dart';

import '../../support/fakes.dart';

const _lu = 'lu_magnetic_pen_stand';
const _wf = 'wf_mps_v1';

LearningUnit theUnit() => LearningUnit.fromMap(_lu, {
      'learningUnitDisplayName': 'Magnetic Pen Stand',
      'shortDescription': 'Build a pen stand that holds itself up with magnets.',
      'stepCount': 6,
      'subjectName': 'Science',
    });

/// Steps stored out of array order, exactly as the seed does it.
Workflow theWorkflow() => Workflow.fromMap(_wf, {
      'steps': [
        {'workflowStepId': 's2', 'workflowStepName': 'Gather materials',
          'sequenceNumber': 2, 'workflowStepDuration': 5,
          'canSkipWorkflowStep': true, 'contents': <dynamic>[]},
        {'workflowStepId': 's1', 'workflowStepName': 'Introduce the problem',
          'sequenceNumber': 1, 'workflowStepDuration': 10,
          'contents': <dynamic>[]},
        {'workflowStepId': 's3', 'workflowStepName': 'Build it',
          'sequenceNumber': 3, 'contents': <dynamic>[]},
        {'workflowStepId': 's4', 'workflowStepName': 'Observe',
          'sequenceNumber': 4, 'contents': <dynamic>[]},
        {'workflowStepId': 's5', 'workflowStepName': 'Discuss',
          'sequenceNumber': 5, 'contents': <dynamic>[]},
        {'workflowStepId': 's6', 'workflowStepName': 'Capture evidence',
          'sequenceNumber': 6, 'allowArtefactUpload': true,
          'assignmentId': 'asg_mps_evidence', 'contents': <dynamic>[]},
      ],
    });

LearningUnitProvider providerWith({
  LearningUnit? unit,
  Workflow? workflow,
  Object? throwsOnUnit,
  Completer<void>? gate,
  Duration timeout = const Duration(seconds: 15),
}) =>
    LearningUnitProvider(
      firestore: FakeFirestoreService(
        learningUnits: unit == null ? const [] : [unit],
        workflows: workflow == null ? const [] : [workflow],
        throwsOnLearningUnit: throwsOnUnit,
        gate: gate,
      ),
      timeout: timeout,
    );

void main() {
  group('loading', () {
    test('exposes steps in sequenceNumber order, not array order', () async {
      final provider = providerWith(unit: theUnit(), workflow: theWorkflow());

      await provider.load(learningUnitId: _lu, workflowId: _wf);

      expect(provider.status, LearningUnitStatus.loaded);
      expect(
        provider.steps.map((s) => s.workflowStepId),
        ['s1', 's2', 's3', 's4', 's5', 's6'],
      );
      // Starts on the first step by sequence, not the first in the array.
      expect(provider.selectedStep!.workflowStepId, 's1');
    });

    test('a missing workflow is notFound, not an error', () async {
      final provider = providerWith(unit: theUnit());

      await provider.load(learningUnitId: _lu, workflowId: 'wf_gone');

      // The classroom binds this unit to a workflow that no longer exists.
      expect(provider.status, LearningUnitStatus.notFound);
    });

    test('a missing learning unit is notFound too', () async {
      final provider = providerWith(workflow: theWorkflow());

      await provider.load(learningUnitId: 'lu_gone', workflowId: _wf);

      expect(provider.status, LearningUnitStatus.notFound);
    });

    test('a thrown read is the error state with a retry', () async {
      final provider = providerWith(throwsOnUnit: StateError('boom'));

      await provider.load(learningUnitId: _lu, workflowId: _wf);

      expect(provider.status, LearningUnitStatus.error);
      expect(provider.errorKey, 'lu.error_generic');
    });

    test('a read that never answers times out', () async {
      final gate = Completer<void>();
      final provider = providerWith(
        unit: theUnit(),
        workflow: theWorkflow(),
        gate: gate,
        timeout: const Duration(milliseconds: 20),
      );

      await provider.load(learningUnitId: _lu, workflowId: _wf);

      expect(provider.status, LearningUnitStatus.error);
      expect(provider.errorKey, 'lu.error_offline');
      gate.complete();
    });

    test('a workflow with no steps loads empty rather than erroring', () async {
      final provider = providerWith(
        unit: theUnit(),
        workflow: Workflow.fromMap(_wf, const {}),
      );

      await provider.load(learningUnitId: _lu, workflowId: _wf);

      expect(provider.status, LearningUnitStatus.loaded);
      expect(provider.hasNoSteps, isTrue);
      expect(provider.selectedStep, isNull);
    });

    test('reloading the same pair does not refetch', () async {
      final fake = FakeFirestoreService(
        learningUnits: [theUnit()],
        workflows: [theWorkflow()],
      );
      final provider = LearningUnitProvider(firestore: fake);

      await provider.load(learningUnitId: _lu, workflowId: _wf);
      await provider.load(learningUnitId: _lu, workflowId: _wf);

      expect(fake.learningUnitReads, 1);
      expect(fake.workflowReads, 1);
    });

    test('a different workflow for the same unit does refetch', () async {
      // The same activity in another classroom. Different workflow, so the
      // steps genuinely differ and the cached one must not be reused.
      final fake = FakeFirestoreService(
        learningUnits: [theUnit()],
        workflows: [theWorkflow(), Workflow.fromMap('wf_other', const {})],
      );
      final provider = LearningUnitProvider(firestore: fake);

      await provider.load(learningUnitId: _lu, workflowId: _wf);
      await provider.load(learningUnitId: _lu, workflowId: 'wf_other');

      expect(fake.workflowReads, 2);
    });
  });

  group('step selection', () {
    Future<LearningUnitProvider> loaded() async {
      final provider = providerWith(unit: theUnit(), workflow: theWorkflow());
      await provider.load(learningUnitId: _lu, workflowId: _wf);
      return provider;
    }

    test('selects by position in the sorted list', () async {
      final provider = await loaded();

      provider.selectStep(4);

      expect(provider.selectedStepIndex, 4);
      expect(provider.selectedStep!.workflowStepId, 's5');
    });

    test('ignores an out-of-range index rather than throwing', () async {
      final provider = await loaded();

      provider.selectStep(99);
      provider.selectStep(-1);

      expect(provider.selectedStepIndex, 0);
    });

    test('selecting the current step does not notify', () async {
      final provider = await loaded();
      var notifications = 0;
      provider.addListener(() => notifications++);

      provider.selectStep(0);

      expect(notifications, 0);
    });
  });
}
