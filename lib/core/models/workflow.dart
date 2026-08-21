import '../utils/keyed_entries.dart';
import '../utils/safe_parse.dart';

/// One piece of content inside a workflow step: a guide, a material list, an
/// image, an upload assignment.
class WorkflowContent {
  const WorkflowContent({
    this.contentName,
    this.contentCategory,
    this.contentType,
    this.resourcePath,
    this.assignmentType,
    this.assignmentId,
  });

  final String? contentName;
  final String? contentCategory;
  final String? contentType;

  /// A Storage path when populated. Empty string on several seeded contents,
  /// which is not the same as absent, so callers must check for both.
  final String? resourcePath;

  final String? assignmentType;
  final String? assignmentId;

  /// True when this content is the photo-evidence upload rather than something
  /// to read.
  bool get isUploadAssignment =>
      (assignmentType ?? '').toUpperCase() == 'UPLOAD' ||
      (contentCategory ?? '').toLowerCase() == 'assignment';

  bool get hasResource => (resourcePath ?? '').trim().isNotEmpty;

  static const Set<String> _imageExtensions = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
  };

  static const Set<String> _documentExtensions = {
    '.pdf',
    '.doc',
    '.docx',
    '.ppt',
    '.pptx',
  };

  /// True when this content is a picture to show rather than something to read.
  ///
  /// Checks the declared type and category first, then falls back to the
  /// resource extension, because the seeded documents label an image only by
  /// its file name.
  bool get isImage {
    final declared = '${contentType ?? ''} ${contentCategory ?? ''}'
        .toLowerCase();
    if (declared.contains('image') || declared.contains('photo')) {
      // An upload assignment mentions photos but is not a picture to display.
      return !isUploadAssignment;
    }
    return _hasExtensionIn(_imageExtensions);
  }

  /// A file we cannot render inline (a PDF guide, a slide deck). Worth naming
  /// on screen rather than pretending it is not there.
  bool get isDocument => !isImage && _hasExtensionIn(_documentExtensions);

  bool _hasExtensionIn(Set<String> extensions) {
    final path = (resourcePath ?? '').trim().toLowerCase();
    if (path.isEmpty) return false;
    return extensions.any(path.endsWith);
  }

  factory WorkflowContent.fromMap(
    Map<String, dynamic> data, {
    String? docId,
    String? field,
  }) {
    return WorkflowContent(
      contentName: SafeParse.asDisplayString(data['contentName']),
      contentCategory: SafeParse.asDisplayString(data['contentCategory']),
      contentType: SafeParse.asDisplayString(data['contentType']),
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

  static const String collection = 'Workflows';

  /// The step where photo evidence is captured, or null when this workflow has
  /// no upload step.
  WorkflowStep? get uploadStep {
    for (final step in steps) {
      if (step.allowArtefactUpload) return step;
    }
    return null;
  }

  factory Workflow.fromMap(String workflowId, Map<String, dynamic> data) {
    final parsed = <WorkflowStep>[];
    final entries = KeyedEntries.from(
      data['steps'],
      collection: collection,
      docId: workflowId,
      field: 'steps',
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
