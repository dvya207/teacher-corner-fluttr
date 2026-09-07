import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/core/models/workflow_progress.dart';

List<WorkflowStep> stepsNamed(List<String> ids) => [
  for (var i = 0; i < ids.length; i++)
    WorkflowStep(workflowStepId: ids[i], sequenceNumber: i + 1),
];

void main() {
  group('the document id', () {
    test('carries the classroom as well as the activity', () {
      // The same activity is taught separately in each classroom, so progress
      // in 7 A must not show up against 8 D.
      expect(
        WorkflowProgress.documentId(classroomId: 'c1', learningUnitId: 'lu1'),
        'c1-lu1',
      );
      expect(
        WorkflowProgress.documentId(classroomId: 'c2', learningUnitId: 'lu1'),
        isNot(
          WorkflowProgress.documentId(classroomId: 'c1', learningUnitId: 'lu1'),
        ),
      );
    });
  });

  group('reading a stored document', () {
    test('an absent document means nothing done', () {
      expect(WorkflowProgress.fromMap(null).completedStepIds, isEmpty);
    });

    test('a document holding the wrong type means nothing done', () {
      // Not an error state worth surfacing. Whatever wrote that, this teacher
      // has completed nothing we can prove.
      expect(
        WorkflowProgress.fromMap({'completedStepIds': 'step_1'}).completedStepIds,
        isEmpty,
      );
    });

    test('blank and non-string entries are dropped, and ids are trimmed', () {
      final p = WorkflowProgress.fromMap({
        'completedStepIds': ['s1', '  s2  ', '', '   ', 7, null],
      });
      expect(p.completedStepIds, {'s1', 's2'});
    });
  });

  group('counting against the steps that exist now', () {
    test('counts only steps still in the workflow', () {
      // A workflow can lose a step after a teacher completed it. Counting the
      // stored ids would render "3 of 2 completed", which reads as a bug in the
      // app rather than as an edit to the workflow.
      const p = WorkflowProgress(completedStepIds: {'s1', 's2', 'gone'});
      expect(p.completedCount(stepsNamed(['s1', 's2'])), 2);
    });

    test('a completed step that was removed cannot make an activity done', () {
      const p = WorkflowProgress(completedStepIds: {'s1', 'gone'});
      expect(
        p.statusFor(stepsNamed(['s1', 's2'])),
        ActivityProgressStatus.inProgress,
      );
    });
  });

  group('status from the workflow', () {
    test('nothing done is not started', () {
      expect(
        const WorkflowProgress().statusFor(stepsNamed(['s1', 's2'])),
        ActivityProgressStatus.notStarted,
      );
    });

    test('some done is in progress', () {
      expect(
        const WorkflowProgress(
          completedStepIds: {'s1'},
        ).statusFor(stepsNamed(['s1', 's2'])),
        ActivityProgressStatus.inProgress,
      );
    });

    test('all done is completed', () {
      expect(
        const WorkflowProgress(
          completedStepIds: {'s1', 's2'},
        ).statusFor(stepsNamed(['s1', 's2'])),
        ActivityProgressStatus.completed,
      );
    });

    test('a workflow with no steps is NOT completed', () {
      // An activity whose workflow has not been built yet has nothing to
      // finish. Calling that done would tick a row nobody has opened.
      expect(
        const WorkflowProgress().statusFor(const []),
        ActivityProgressStatus.notStarted,
      );
    });
  });

  group('status from a step count, for the classroom screen', () {
    test('nothing done is not started', () {
      expect(
        const WorkflowProgress().statusForCount(6),
        ActivityProgressStatus.notStarted,
      );
    });

    test('some done is in progress', () {
      expect(
        const WorkflowProgress(completedStepIds: {'s1'}).statusForCount(6),
        ActivityProgressStatus.inProgress,
      );
    });

    test('as many done as there are steps is completed', () {
      expect(
        const WorkflowProgress(
          completedStepIds: {'s1', 's2'},
        ).statusForCount(2),
        ActivityProgressStatus.completed,
      );
    });

    test('an unknown total never reads as completed', () {
      // The safe direction to be wrong in: it never tells a teacher they are
      // finished with work they are not.
      expect(
        const WorkflowProgress(
          completedStepIds: {'s1', 's2'},
        ).statusForCount(null),
        ActivityProgressStatus.inProgress,
      );
      expect(
        const WorkflowProgress(completedStepIds: {'s1'}).statusForCount(0),
        ActivityProgressStatus.inProgress,
      );
    });
  });

  group('where Resume lands', () {
    test('on the first step of an untouched activity', () {
      expect(
        const WorkflowProgress().resumeIndex(stepsNamed(['s1', 's2', 's3'])),
        0,
      );
    });

    test('on the first GAP, not the furthest step reached', () {
      // A teacher who skipped step 2 and completed 3 is resuming at 2, because
      // the gap is what is left to do.
      expect(
        const WorkflowProgress(
          completedStepIds: {'s1', 's3'},
        ).resumeIndex(stepsNamed(['s1', 's2', 's3'])),
        1,
      );
    });

    test('back at the top once everything is done', () {
      // Rather than an index past the end. Reopening a finished activity is
      // rereading it, and it should start where reading starts.
      expect(
        const WorkflowProgress(
          completedStepIds: {'s1', 's2'},
        ).resumeIndex(stepsNamed(['s1', 's2'])),
        0,
      );
    });
  });

  group('toggling a step', () {
    test('adds and removes without touching the original', () {
      const before = WorkflowProgress(completedStepIds: {'s1'});
      final added = before.withStep('s2', done: true);
      final removed = added.withStep('s1', done: false);

      expect(added.completedStepIds, {'s1', 's2'});
      expect(removed.completedStepIds, {'s2'});
      // The value it was derived from is unchanged, which is what lets the
      // provider roll back to it when the write fails.
      expect(before.completedStepIds, {'s1'});
    });

    test('marking the same step twice records it once', () {
      final p = const WorkflowProgress()
          .withStep('s1', done: true)
          .withStep('s1', done: true);
      expect(p.completedStepIds, {'s1'});
    });
  });
}
