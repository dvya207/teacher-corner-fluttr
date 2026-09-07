import '../utils/keyed_entries.dart';
import '../utils/safe_parse.dart';
import 'learning_unit.dart';

/// One piece of content inside a workflow step: a guide, a material list, an
/// image, an upload assignment.
class WorkflowContent {
  const WorkflowContent({
    this.contentName,
    this.contentCategory,
    this.contentSubCategory,
    this.contentType,
    this.additionalResourceType,
    this.resourcePath,
    this.assignmentType,
    this.assignmentId,
  });

  final String? contentName;
  final String? contentCategory;

  /// Which resource of [contentCategory] this content is, and the ONLY thing
  /// that identifies the file: the step's own `resourcePath` is empty in live
  /// data. See [LearningUnitResources].
  final String? contentSubCategory;
  final String? contentType;

  /// Which KIND of extra file this slot expects, e.g. "PPT". Only meaningful
  /// when [contentCategory] is the additional-resources one, where there is no
  /// subCategory to identify a specific file.
  final String? additionalResourceType;

  /// A Storage path when populated. Empty string on several seeded contents,
  /// which is not the same as absent, so callers must check for both.
  final String? resourcePath;

  final String? assignmentType;
  final String? assignmentId;

  /// True when this content is the photo-evidence upload rather than something
  /// to read.
  /// True for any of the three assignment kinds. The category alone does not
  /// say which.
  bool get isAssignment =>
      (contentCategory ?? '').toLowerCase() == 'assignment' ||
      _assignmentType.isNotEmpty;

  String get _assignmentType => (assignmentType ?? '').trim().toUpperCase();

  /// EVERY assignment used to be treated as an upload, and that was the bug
  /// behind three steps that all showed the same photo panel.
  ///
  /// The old rule was "type is UPLOAD **or** category is assignment", so a QUIZ
  /// and a FORM both satisfied the second half and rendered the evidence pane.
  /// A teacher opening "Quizzzz" got a camera. The type is what distinguishes
  /// them and it is populated on every live content, so it decides.
  ///
  /// An assignment with NO type still falls here, because that is what the
  /// category alone used to mean and an upload pane at least degrades to
  /// something a teacher can close.
  bool get isUploadAssignment =>
      isAssignment && (_assignmentType == 'UPLOAD' || _assignmentType.isEmpty);

  /// A quiz to sit, opened in the player the Quizzes tab already uses.
  bool get isQuizAssignment => isAssignment && _assignmentType == 'QUIZ';

  /// A feedback form to fill in.
  bool get isFormAssignment => isAssignment && _assignmentType == 'FORM';

  bool get hasResource => (resourcePath ?? '').trim().isNotEmpty;

  /// The category, reduced to letters and lowercased, so 'externalResources'
  /// and 'external resources' compare equal. Three systems have written this
  /// field and none of them agreed on spacing or casing.
  String get _normalisedCategory =>
      (contentCategory ?? '').toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');

  /// True when this content points at the unit's free-form extras rather than
  /// at a fixed resource slot. Matched loosely because the stored value is
  /// "additional resources", with a space, and nothing guarantees the casing.
  bool get isAdditionalResources =>
      _normalisedCategory == 'additionalresources';

  /// True when this content points at one of the unit's External Resources,
  /// which live on the unit document rather than in a maturity resource
  /// document. See [LearningUnit.externalResourcePath].
  bool get isExternalResources =>
      _normalisedCategory == LearningUnit.externalResourcesCategory;

  /// WHAT KIND OF THING THIS CONTENT HOLDS IS NOT ANSWERABLE FROM HERE, and
  /// there used to be an `isImage` and an `isDocument` on this class that
  /// answered it anyway. They read `contentType`, `contentCategory` and this
  /// content's own `resourcePath`, and both inputs let them down:
  ///
  ///   * `resourcePath` is EMPTY on every live content, because the file lives
  ///     in `learningUnitResources` and the step only holds a pointer, so the
  ///     extension check had nothing to look at;
  ///   * the category lies. `graphics.headlineImage` holds Sample.pdf in
  ///     teacher-corner-dev, so anything trusting the name drew a PDF through
  ///     the image widget.
  ///
  /// The kind is decided from the RESOLVED value instead, once the pointer has
  /// been followed. See [ResolvedResource] in
  /// `lib/core/models/resource_kind.dart`.

  factory WorkflowContent.fromMap(
    Map<String, dynamic> data, {
    String? docId,
    String? field,
  }) {
    return WorkflowContent(
      contentName: SafeParse.asDisplayString(data['contentName']),
      contentCategory: SafeParse.asDisplayString(data['contentCategory']),
      contentSubCategory: SafeParse.asDisplayString(
        data['contentSubCategory'],
      ),
      contentType: SafeParse.asDisplayString(data['contentType']),
      additionalResourceType: SafeParse.asDisplayString(
        data['additionalResourceType'],
      ),
      resourcePath: SafeParse.asRefString(
        data['resourcePath'],
        collection: Workflow.collection,
        docId: docId,
        field: '$field.resourcePath',
      ),
      assignmentType: SafeParse.asDisplayString(data['assignmentType']),
      assignmentId: SafeParse.asRefString(
        data['assignmentId'],
        collection: Workflow.collection,
        docId: docId,
        field: '$field.assignmentId',
      ),
    );
  }
}

/// One step a teacher walks through in class.
class WorkflowStep {
  const WorkflowStep({
    required this.workflowStepId,
    this.workflowStepName,
    this.workflowStepType,
    this.sequenceNumber,
    this.durationMinutes,
    this.canSkip = false,
    this.allowArtefactUpload = false,
    this.assignmentId,
    this.contents = const [],
  });

  final String workflowStepId;
  final String? workflowStepName;
  final String? workflowStepType;

  /// The DISPLAY order. Null when the document omits it, which sorts last
  /// rather than first, because an unnumbered step is more likely an appendix
  /// than an introduction.
  final int? sequenceNumber;

  final int? durationMinutes;
  final bool canSkip;

  /// True on the step where photo evidence is captured.
  final bool allowArtefactUpload;

  final String? assignmentId;
  final List<WorkflowContent> contents;

  String get label {
    final name = workflowStepName?.trim();
    return (name != null && name.isNotEmpty) ? name : workflowStepId;
  }

  factory WorkflowStep.fromMap(
    Map<String, dynamic> data, {
    required String fallbackId,
    String? docId,
  }) {
    final id =
        SafeParse.asRefString(
          data['workflowStepId'],
          collection: Workflow.collection,
          docId: docId,
          field: 'steps.workflowStepId',
        ) ??
        fallbackId;

    return WorkflowStep(
      workflowStepId: id,
      workflowStepName: SafeParse.asDisplayString(data['workflowStepName']),
      workflowStepType: SafeParse.asDisplayString(data['workflowStepType']),
      sequenceNumber: SafeParse.asIntOrNull(
        data['sequenceNumber'],
        collection: Workflow.collection,
        docId: docId,
        field: 'steps.sequenceNumber',
      ),
      durationMinutes: SafeParse.asIntOrNull(
        data['workflowStepDuration'],
        collection: Workflow.collection,
        docId: docId,
        field: 'steps.workflowStepDuration',
      ),
      canSkip: SafeParse.asBool(
        data['canSkipWorkflowStep'],
        collection: Workflow.collection,
        docId: docId,
        field: 'steps.canSkipWorkflowStep',
      ),
      allowArtefactUpload: SafeParse.asBool(
        data['allowArtefactUpload'],
        collection: Workflow.collection,
        docId: docId,
        field: 'steps.allowArtefactUpload',
      ),
      assignmentId: SafeParse.asRefString(
        data['assignmentId'],
        collection: Workflow.collection,
        docId: docId,
        field: 'steps.assignmentId',
      ),
      contents: [
        for (final entry in KeyedEntries.from(
          data['contents'],
          collection: Workflow.collection,
          docId: docId,
          field: 'steps.contents',
        ))
          WorkflowContent.fromMap(
            entry.value,
            docId: docId,
            field: 'steps.contents',
          ),
      ],
    );
  }
}

/// `Workflows/{workflowId}`: the ordered steps for one learning unit in one
/// classroom's programme.
class Workflow {
  const Workflow({required this.workflowId, this.steps = const []});

  final String workflowId;

  /// Already sorted by [WorkflowStep.sequenceNumber]. See [fromMap].
  final List<WorkflowStep> steps;

  /// `workflows`, lowercase, to match the web app's naming convention for
  /// every other collection in `teacher-corner-dev`.
  ///
  /// THIS COLLECTION DOES NOT EXIST IN THAT DATABASE. The web app has no
  /// workflow feature: its classroom programme entries carry `workflowIds`
  /// rows with a `workflowId` string, but there is nothing for those strings to
  /// point at. A read therefore returns "does not exist", which
  /// `FirestoreService.fetchWorkflow` already reports as null and which the
  /// learning unit route already renders as [MissingWorkflowScreen].
  ///
  /// That is the intended behaviour for now, not a bug to work around. Naming
  /// the collection in the convention the database uses means the day workflows
  /// land there, this starts working with no code change.
  static const String collection = 'workflows';

  /// The step where photo evidence is captured, or null when this workflow has
  /// no upload step.
  WorkflowStep? get uploadStep {
    for (final step in steps) {
      if (step.allowArtefactUpload) return step;
    }
    return null;
  }

  /// The field the steps actually live under.
  ///
  /// `workflowSteps` IS THE REAL NAME, and reading `steps` was a guess that
  /// cost every activity its steps. Every workflow in `teacher-corner-dev`
  /// carries `workflowSteps` (written by the web app's classroom stepper,
  /// `createdSource: teacher-corner-classroom-stepper`), and the collection's
  /// own `--schema--` document declares `workflowSteps` too. Nothing writes
  /// `steps`. The symptom was not an error: `KeyedEntries.from(null)` yields
  /// nothing, so every activity rendered the honest, and completely wrong,
  /// "No steps yet".
  ///
  /// `steps` is still accepted, because this repo's own fixtures and seed use
  /// it and there is no value in a rename that only churns tests. Live data
  /// wins where a document somehow has both.
  static const List<String> stepsFieldNames = ['workflowSteps', 'steps'];

  factory Workflow.fromMap(String workflowId, Map<String, dynamic> data) {
    final parsed = <WorkflowStep>[];
    final field = stepsFieldNames.firstWhere(
      (name) => data[name] != null,
      orElse: () => stepsFieldNames.first,
    );
    final entries = KeyedEntries.from(
      data[field],
      collection: collection,
      docId: workflowId,
      field: field,
    );
    for (var i = 0; i < entries.length; i++) {
      parsed.add(
        WorkflowStep.fromMap(
          entries[i].value,
          // Only used when the document omits workflowStepId; index at least
          // keeps the keys distinct.
          fallbackId: entries[i].key ?? 'step_$i',
          docId: workflowId,
        ),
      );
    }

    // Sorted HERE, once, at the boundary, rather than in the widget that draws
    // the step indicator. SCHEMA.md is explicit that array order is not display
    // order, and the seed stores the steps out of order on purpose to prove it.
    //
    // Stable: List.sort is not, so ties fall back to the original index, which
    // keeps duplicate or missing sequence numbers from reshuffling between
    // reads. Unnumbered steps sort last.
    final indexed = [
      for (var i = 0; i < parsed.length; i++) (index: i, step: parsed[i]),
    ];
    indexed.sort((a, b) {
      final sa = a.step.sequenceNumber;
      final sb = b.step.sequenceNumber;
      if (sa == null && sb == null) return a.index.compareTo(b.index);
      if (sa == null) return 1;
      if (sb == null) return -1;
      final bySequence = sa.compareTo(sb);
      return bySequence != 0 ? bySequence : a.index.compareTo(b.index);
    });

    return Workflow(
      workflowId: workflowId,
      steps: List.unmodifiable([for (final e in indexed) e.step]),
    );
  }
}
