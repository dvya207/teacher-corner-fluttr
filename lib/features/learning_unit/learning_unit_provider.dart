import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/assignment.dart';
import '../../core/models/learning_unit.dart';
import '../../core/models/learning_unit_additional_resource.dart';
import '../../core/models/board_grade_resource.dart';
import '../../core/models/classroom.dart';
import '../../core/models/learning_unit_resources.dart';
import '../../core/models/workflow.dart';
import '../../core/models/workflow_progress.dart';
import '../../core/services/firestore_service.dart';

enum LearningUnitStatus { loading, loaded, notFound, error }

const Duration kLearningUnitTimeout = Duration(seconds: 15);

/// Holds one activity as a specific classroom runs it.
///
/// It is loaded with a [workflowId] that the CLASSROOM supplied. There is
/// deliberately no path from a learning unit to its workflow here, because that
/// relationship does not exist in the data: the same unit runs a different
/// workflow in a different classroom.
class LearningUnitProvider extends ChangeNotifier {
  LearningUnitProvider({
    required FirestoreService firestore,
    Duration timeout = kLearningUnitTimeout,
  })  : _firestore = firestore,
        _timeout = timeout;

  final FirestoreService _firestore;
  final Duration _timeout;

  LearningUnitStatus _status = LearningUnitStatus.loading;
  LearningUnit? _unit;
  Workflow? _workflow;
  LearningUnitResources _resources = const LearningUnitResources();

  /// This unit's board-and-grade documents, by id. See [BoardGradeResource].
  Map<String, BoardGradeResource> _boardGrades = const {};

  /// The classroom this activity was opened from, read for its BOARD and
  /// GRADE and nothing else. A grade-dependent slot cannot be resolved without
  /// both: the board picks the document, the grade picks the file inside it.
  Classroom? _classroom;
  String? _errorKey;
  int _selectedStep = 0;
  String? _learningUnitId;
  String? _workflowId;

  /// Needed to address the progress document. Null signed out, or when the
  /// screen was opened without a classroom, in which case progress is read-only
  /// and empty: the same activity is taught separately in each classroom, so
  /// there is nowhere to record it without knowing which.
  String? _uid;
  String? _classroomId;
  WorkflowProgress _progress = const WorkflowProgress();

  /// Assignments named by this workflow's steps, by id. Fetched in one batch
  /// with the rest of the load rather than when a tab is opened, so a teacher
  /// mid-class never waits on a read to see what a step contains.
  Map<String, Assignment> _assignments = const {};

  /// True when the assignment read failed rather than finding nothing.
  ///
  /// THE TWO ARE DIFFERENT AND LOOK IDENTICAL. A step naming an assignment that
  /// was deleted and a step whose read failed both leave the map empty, and
  /// only one of them is worth offering a teacher a Retry for. Without this, a
  /// dropped signal mid-class left a dead card and no way back except leaving
  /// the activity and coming in again.
  bool _assignmentsFailed = false;
  bool _reloadingAssignments = false;
  bool _savingStep = false;
  bool _inFlight = false;
  bool _disposed = false;

  LearningUnitStatus get status => _status;
  LearningUnit? get unit => _unit;
  Workflow? get workflow => _workflow;
  String? get errorKey => _errorKey;

  /// Already ordered by `sequenceNumber`, sorted once at the parse boundary.
  List<WorkflowStep> get steps => _workflow?.steps ?? const [];

  int get selectedStepIndex => _selectedStep;

  WorkflowStep? get selectedStep =>
      (_selectedStep >= 0 && _selectedStep < steps.length)
          ? steps[_selectedStep]
          : null;

  bool get hasNoSteps => _status == LearningUnitStatus.loaded && steps.isEmpty;

  WorkflowProgress get progress => _progress;

  /// True when the assignments could not be read and it is worth trying again.
  bool get assignmentsFailed => _assignmentsFailed;

  bool get isReloadingAssignments => _reloadingAssignments;

  /// Retries just the assignments, leaving the rest of the activity alone.
  ///
  /// NOT [retry], which reloads everything and would throw away the steps and
  /// the progress a teacher is part way through to recover one card.
  Future<void> reloadAssignments() async {
    final workflow = _workflow;
    if (workflow == null || _reloadingAssignments) return;
    _reloadingAssignments = true;
    _notify();
    _assignments = await _loadAssignments(workflow);
    _reloadingAssignments = false;
    _notify();
  }

  /// The assignment behind one content, or null when it was not readable.
  Assignment? assignmentFor(WorkflowContent content) {
    final id = content.assignmentId?.trim();
    if (id == null || id.isEmpty) return null;
    return _assignments[id];
  }

  /// The uploads behind this activity's step contents.
  LearningUnitResources get resources => _resources;

  /// The unit's free-form extras that one content should list.
  ///
  /// EVERY PUBLISHED ONE, with the slot's declared kind first, rather than only
  /// the ones matching it. The slot says what was expected ("PPT"); the array
  /// holds what the author actually attached, and in live data those disagree:
  /// Swimming's step asks for a PPT and its only extra is a video. Filtering
  /// strictly would hide a teacher's own upload behind a slot they cannot see
  /// or edit, so the pane shows all of them and labels each with its real kind.
  /// Nothing is misrepresented, and nothing uploaded goes missing.
  List<LearningUnitAdditionalResource> additionalResourcesFor(
    WorkflowContent content,
  ) {
    if (!content.isAdditionalResources) return const [];
    final all = _unit?.publishedAdditionalResources ?? const [];
    if (all.isEmpty) return const [];
    final wanted = content.additionalResourceType;
    return [
      for (final r in all)
        if (r.matchesType(wanted)) r,
      for (final r in all)
        if (!r.matchesType(wanted)) r,
    ];
  }

  /// Where one content's file actually is, or null when nothing is uploaded.
  ///
  /// THREE PLACES, TRIED IN ORDER, and the middle one is the whole reason this
  /// method is longer than a lookup:
  ///
  ///   1. the step's own `resourcePath`. Empty in all live data today, but a
  ///      document that does carry one is being more specific than any lookup
  ///      by category can be, and this app owns none of these collections;
  ///   2. the unit's own External Resources, when the category says so. These
  ///      live on `learningUnits/{id}.resources` with no maturity, and they
  ///      are where the web app's Material List, Observation Sheet and unit
  ///      Guide uploads actually go;
  ///   3. the maturity resource document, which is everything else.
  ///
  /// STEP 2 USED TO BE MISSING, and that single gap emptied six tabs of the
  /// Sterling Point workflow: Material List, Observation Sheet, Evidence
  /// Uploads, the step-3 Activity Guide, Classroom Activity Evidence and the
  /// step-4 Observation sheet. Every one of them was uploaded and every one of
  /// them read "no content attached yet", because a lookup in the maturity
  /// document for `externalResources.materialPath` finds nothing and finding
  /// nothing is indistinguishable from nothing having been uploaded.
  String? resolvedPathFor(WorkflowContent content) {
    final direct = content.resourcePath?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    if (content.isExternalResources) {
      return _unit?.externalResourcePath(content.contentSubCategory);
    }

    // A GRADE-DEPENDENT SLOT IS TRIED BEFORE THE UNIVERSAL ONE, which is the
    // order production uses: this class's own board and year is the right copy
    // and the universal file is the fallback, not the other way round.
    final board = _classroom?.board;
    final boardDocId = _resources.boardDocIdFor(
      category: content.contentCategory,
      subCategory: content.contentSubCategory,
      board: board,
    );
    if (boardDocId != null) {
      final path = _boardGrades[boardDocId]?.pathForGrade(
        BoardGradeResource.gradeKey(_classroom?.grade),
      );
      if (path != null) return path;
    }

    // Plain slots, and the universal copy of a grade-dependent one.
    return _resources.pathFor(
      category: content.contentCategory,
      subCategory: content.contentSubCategory,
    );
  }

  /// True while a "mark as done" is in flight, so the control can be disabled
  /// rather than letting a second tap race the first.
  bool get isSavingStep => _savingStep;

  /// Whether progress can be recorded at all. False signed out, or when the
  /// activity was opened outside a classroom.
  bool get canRecordProgress => _uid != null && _classroomId != null;

  int get completedCount => _progress.completedCount(steps);

  /// Which steps are recorded done, for the stepper to mark.
  Set<String> get completedStepIds => _progress.completedStepIds;

  /// NOT `status`, which this provider already uses for the LOAD state. Two
  /// unrelated things on one screen are both "the status", and the load one was
  /// here first.
  ActivityProgressStatus get progressStatus => _progress.statusFor(steps);

  bool isStepDone(int index) =>
      index >= 0 &&
      index < steps.length &&
      _progress.isDone(steps[index].workflowStepId);

  /// Where "Resume Activity" lands. See [WorkflowProgress.resumeIndex].
  int get resumeIndex => _progress.resumeIndex(steps);

  String? get learningUnitId => _learningUnitId;
  String? get workflowId => _workflowId;

  Future<void> load({
    required String learningUnitId,
    required String workflowId,
    String? uid,
    String? classroomId,
  }) async {
    if (_learningUnitId == learningUnitId &&
        _workflowId == workflowId &&
        _status != LearningUnitStatus.error) {
      return;
    }
    _learningUnitId = learningUnitId;
    _workflowId = workflowId;
    _uid = uid;
    _classroomId = classroomId;
    await _fetch();
  }

  /// Records, or un-records, one step.
  ///
  /// OPTIMISTIC, AND ROLLED BACK ON FAILURE. A teacher marks a step done in
  /// front of a class and moves on; waiting on a round trip before the tick
  /// appears makes the app feel broken on a bad connection. If the write fails
  /// the tick goes away again, which is the honest outcome and visible
  /// immediately below the finger that caused it.
  ///
  /// A TOGGLE, because the mistake this fixes is a teacher marking the wrong
  /// step done, and a record with no way back is one a teacher stops trusting.
  Future<bool> setStepDone(int index, {required bool done}) async {
    if (index < 0 || index >= steps.length) return false;
    final uid = _uid;
    final classroomId = _classroomId;
    if (uid == null || classroomId == null || _savingStep) return false;

    final previous = _progress;
    final stepId = steps[index].workflowStepId;
    _progress = previous.withStep(stepId, done: done);
    _savingStep = true;
    _notify();

    try {
      await _firestore
          .setWorkflowStepDone(
            uid: uid,
            classroomId: classroomId,
            learningUnitId: _learningUnitId!,
            completedStepIds: _progress.completedStepIds,
          )
          .timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('LearningUnitProvider: could not save step: $e');
      _progress = previous;
      return false;
    } finally {
      _savingStep = false;
      _notify();
    }
  }

  Future<void> retry() async {
    if (_learningUnitId == null || _workflowId == null) return;
    await _fetch();
  }

  void selectStep(int index) {
    if (index < 0 || index >= steps.length) return;
    if (index == _selectedStep) return;
    _selectedStep = index;
    _notify();
  }

  Future<void> _fetch() async {
    if (_inFlight) return;
    _inFlight = true;
    _status = LearningUnitStatus.loading;
    _errorKey = null;
    _notify();

    try {
      // In parallel: neither read depends on the other, and a teacher mid-class
      // should not pay for them in series.
      final unitFuture = _firestore.fetchLearningUnit(_learningUnitId!);
      final workflowFuture = _firestore.fetchWorkflow(_workflowId!);
      final unit = await unitFuture.timeout(_timeout);
      final workflow = await workflowFuture.timeout(_timeout);

      _unit = unit;
      _workflow = workflow;
      if (unit == null || workflow == null) {
        // Either the activity, or the workflow this classroom binds to it, is
        // gone. Retrying will not bring it back.
        _status = LearningUnitStatus.notFound;
      } else {
        _selectedStep = 0;
        _resources = await _loadResources();
        await _loadGradeDependent();
        _assignments = await _loadAssignments(workflow);
        _progress = await _loadProgress();
        _status = LearningUnitStatus.loaded;
      }
    } on TimeoutException {
      _status = LearningUnitStatus.error;
      _errorKey = 'lu.error_offline';
    } catch (e) {
      debugPrint('LearningUnitProvider: load failed: $e');
      _status = LearningUnitStatus.error;
      _errorKey = 'lu.error_generic';
    } finally {
      _inFlight = false;
      _notify();
    }
  }

  /// The assignments this workflow's steps name. Allowed to fail on its own:
  /// losing them costs the quiz and form panes, not the steps.
  /// The classroom and the board copies, but ONLY IF A SLOT NEEDS THEM.
  ///
  /// TWO EXTRA READS, DEFERRED. Most units have no grade-dependent slot filled,
  /// and a teacher opening an activity mid-class should not pay a classroom
  /// read and a collection query to find that out. So the resource document is
  /// asked first whether any slot is a map, and this is skipped entirely when
  /// none is.
  ///
  /// FAILURE IS NOT FATAL. Without these, a grade-dependent slot falls back to
  /// its universal copy and the tab says nothing is attached, which is exactly
  /// what it said before any of this existed.
  Future<void> _loadGradeDependent() async {
    if (!_resources.hasGradeDependentSlot) return;

    final unitDocId = _unit?.learningUnitId;
    if (unitDocId == null || unitDocId.isEmpty) return;

    final classroomId = _classroomId;
    try {
      final boardsFuture = _firestore.fetchBoardGradeResources(unitDocId);
      final classroomFuture = classroomId == null || classroomId.isEmpty
          ? Future<Classroom?>.value()
          : _firestore.fetchClassroom(classroomId);

      _boardGrades = await boardsFuture.timeout(_timeout);
      _classroom = await classroomFuture.timeout(_timeout);
    } catch (e) {
      debugPrint('LearningUnitProvider: grade-dependent load failed: $e');
    }
  }

  Future<Map<String, Assignment>> _loadAssignments(Workflow workflow) async {
    final ids = <String>{
      for (final step in workflow.steps)
        for (final content in step.contents)
          if ((content.assignmentId ?? '').trim().isNotEmpty)
            content.assignmentId!.trim(),
    };
    if (ids.isEmpty) {
      _assignmentsFailed = false;
      return const {};
    }
    try {
      final loaded = await _firestore.fetchAssignments(ids).timeout(_timeout);
      _assignmentsFailed = false;
      return {for (final a in loaded) a.docId: a};
    } catch (e) {
      debugPrint('LearningUnitProvider: assignments unavailable: $e');
      _assignmentsFailed = true;
      return const {};
    }
  }

  /// Allowed to fail on its own. Losing the uploads costs the content panes;
  /// it must not cost the steps, which are the part a teacher can still teach
  /// from.
  Future<LearningUnitResources> _loadResources() async {
    try {
      return await _firestore
          .fetchLearningUnitResources(_learningUnitId!)
          .timeout(_timeout);
    } catch (e) {
      debugPrint('LearningUnitProvider: resources unavailable: $e');
      return const LearningUnitResources();
    }
  }

  /// Allowed to fail on its own, like the dashboard's second round of reads.
  /// Losing progress costs the ticks; it must not cost the activity.
  Future<WorkflowProgress> _loadProgress() async {
    final uid = _uid;
    final classroomId = _classroomId;
    if (uid == null || classroomId == null) return const WorkflowProgress();
    try {
      return await _firestore
          .fetchWorkflowProgress(
            uid: uid,
            classroomId: classroomId,
            learningUnitId: _learningUnitId!,
          )
          .timeout(_timeout);
    } catch (e) {
      debugPrint('LearningUnitProvider: progress unavailable: $e');
      return const WorkflowProgress();
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
