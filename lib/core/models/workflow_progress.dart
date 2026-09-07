import 'workflow.dart';

/// How far a teacher has got through one activity, in one classroom.
enum ActivityProgressStatus { notStarted, inProgress, completed }

/// Which steps of a workflow this teacher has marked done, for one classroom.
///
/// PER CLASSROOM, NOT PER ACTIVITY. The same learning unit runs in several of a
/// teacher's classrooms and is taught separately in each, so "Magnetic Pen
/// Stand" being finished with 7 A says nothing about 8 D. The document id
/// carries both, which is also what lets one query fetch a whole classroom's
/// worth of progress instead of one read per card.
///
/// PRIVATE TO THE TEACHER. It lives under `users/{uid}`, the same place the
/// quiz submissions and the evidence go, for the reasons set out on
/// `FirestoreService._submissionDoc`: the web app's deployed rules already
/// grant that subtree to its own uid, so this needs no rules change and no
/// deploy from this repo. It is a teacher's own record of their teaching, not
/// a fact about the classroom, so it does not belong in the shared data even
/// if writing there were permitted.
class WorkflowProgress {
  const WorkflowProgress({this.completedStepIds = const {}});

  /// Subcollection under `users/{uid}`.
  static const String collection = 'workflowProgress';

  /// One document per classroom-and-activity pair.
  static String documentId({
    required String classroomId,
    required String learningUnitId,
  }) => '$classroomId-$learningUnitId';

  /// The ids of the steps marked done. A SET, because the only questions ever
  /// asked of it are membership and size, and because a list would let the same
  /// step be recorded twice and count as two.
  final Set<String> completedStepIds;

  bool isDone(String stepId) => completedStepIds.contains(stepId);

  /// How many of [steps] are done.
  ///
  /// COUNTED AGAINST THE STEPS THAT EXIST NOW, not against what was stored. A
  /// workflow can lose a step after a teacher has completed it, and counting
  /// the stored ids would then render "7 of 6 completed", which reads as a bug
  /// in the app rather than as an edit to the workflow.
  int completedCount(List<WorkflowStep> steps) =>
      steps.where((s) => completedStepIds.contains(s.workflowStepId)).length;

  /// Status without the workflow in hand.
  ///
  /// THE CLASSROOM SCREEN'S VERSION. It shows a status on every activity it
  /// lists but never loads their workflows, because that would be one read per
  /// card. `LearningUnit.stepCount` is on the unit document it already has, so
  /// the total comes from there and the count of done ones from the stored ids.
  ///
  /// A null [stepCount] means the total is unknown, not zero: an activity with
  /// something done is in progress, and there is no honest way to call it
  /// finished. That is the safe direction to be wrong in, since it never tells
  /// a teacher they are done with work they are not.
  ActivityProgressStatus statusForCount(int? stepCount) {
    final done = completedStepIds.length;
    if (done == 0) return ActivityProgressStatus.notStarted;
    if (stepCount == null || stepCount <= 0) {
      return ActivityProgressStatus.inProgress;
    }
    return done >= stepCount
        ? ActivityProgressStatus.completed
        : ActivityProgressStatus.inProgress;
  }

  ActivityProgressStatus statusFor(List<WorkflowStep> steps) {
    // No steps is NOT "completed". An activity whose workflow has not been
    // built yet has nothing to finish, and calling that done would tick a row
    // the teacher has never opened.
    if (steps.isEmpty) return ActivityProgressStatus.notStarted;
    final done = completedCount(steps);
    if (done == 0) return ActivityProgressStatus.notStarted;
    if (done >= steps.length) return ActivityProgressStatus.completed;
    return ActivityProgressStatus.inProgress;
  }

  /// Where "Resume Activity" should land: the first step not yet done.
  ///
  /// THE FIRST GAP, not the furthest reached. A teacher who skipped step 3 and
  /// completed 4 is resuming at 3, because the gap is the thing left to do.
  /// Returns 0 for a finished activity, so reopening it starts at the top
  /// rather than at a step that does not exist.
  int resumeIndex(List<WorkflowStep> steps) {
    for (var i = 0; i < steps.length; i++) {
      if (!completedStepIds.contains(steps[i].workflowStepId)) return i;
    }
    return 0;
  }

  WorkflowProgress withStep(String stepId, {required bool done}) {
    final next = Set<String>.from(completedStepIds);
    if (done) {
      next.add(stepId);
    } else {
      next.remove(stepId);
    }
    return WorkflowProgress(completedStepIds: next);
  }

  /// Tolerant of a document that is absent, empty, or holding something other
  /// than a list, all of which mean the same thing: nothing done yet.
  factory WorkflowProgress.fromMap(Map<String, dynamic>? data) {
    final raw = data?['completedStepIds'];
    if (raw is! List) return const WorkflowProgress();
    return WorkflowProgress(
      completedStepIds: {
        for (final id in raw)
          if (id is String && id.trim().isNotEmpty) id.trim(),
      },
    );
  }
}
