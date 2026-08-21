import '../utils/keyed_entries.dart';
import '../utils/safe_parse.dart';

/// Which workflow a specific classroom runs for a specific learning unit.
///
/// This binding is THE counter-intuitive thing in the data model. The list of
/// learning units a classroom is doing, and the workflow used for each, live on
/// the CLASSROOM document, not on the learning unit. The same learning unit
/// runs a different workflow in a different classroom, so "the workflow for
/// this activity" is not a question you can answer without knowing which
/// classroom is asking.
class WorkflowBinding {
  const WorkflowBinding({
    required this.learningUnitId,
    required this.workflowId,
  });

  final String learningUnitId;
  final String workflowId;
}

/// A programme as it appears on the authoritative classroom document, carrying
/// the workflow bindings that the denormalised copy on the teacher does not.
class ClassroomProgramme {
  const ClassroomProgramme({
    required this.programmeId,
    this.displayName,
    this.workflows = const [],
  });

  final String programmeId;
  final String? displayName;
  final List<WorkflowBinding> workflows;

  String get label {
    final name = displayName?.trim();
    return (name != null && name.isNotEmpty) ? name : programmeId;
  }

  static List<ClassroomProgramme> listFrom(
    dynamic raw, {
    String? collection,
    String? docId,
  }) {
    final out = <ClassroomProgramme>[];
    for (final entry in KeyedEntries.from(
      raw,
      collection: collection,
      docId: docId,
      field: 'programmes',
    )) {
      final id =
          entry.key ??
          SafeParse.asRefString(
            entry.value['programmeId'],
            collection: collection,
            docId: docId,
            field: 'programmes.programmeId',
          );
      if (id == null || id.isEmpty) continue;
      out.add(
        ClassroomProgramme(
          programmeId: id,
          displayName: SafeParse.asDisplayString(entry.value['displayName']),
          workflows: _workflowsFrom(
            entry.value['workflowIds'],
            collection: collection,
            docId: docId,
            programmeId: id,
          ),
        ),
      );
    }
    return out;
  }

  /// `workflowIds` is a LIST on one seeded classroom and a MAP on the other,
  /// on purpose, because the real data is like that.
  static List<WorkflowBinding> _workflowsFrom(
    dynamic raw, {
    String? collection,
    String? docId,
    required String programmeId,
  }) {
    final out = <WorkflowBinding>[];
    for (final entry in KeyedEntries.from(
      raw,
      collection: collection,
      docId: docId,
      field: 'programmes.$programmeId.workflowIds',
    )) {
      // Both halves are strict: a binding missing either id cannot be resolved
      // to anything, and inventing one would silently open the wrong workflow.
      final luId = SafeParse.asRefString(
        entry.value['learningUnitId'],
        collection: collection,
        docId: docId,
        field: 'workflowIds.learningUnitId',
      );
      final workflowId = SafeParse.asRefString(
        entry.value['workflowId'],
        collection: collection,
        docId: docId,
        field: 'workflowIds.workflowId',
      );
      if (luId == null || luId.isEmpty) continue;
      if (workflowId == null || workflowId.isEmpty) continue;
      out.add(WorkflowBinding(learningUnitId: luId, workflowId: workflowId));
    }
    return out;
  }
}

/// The authoritative `Classrooms/{classroomId}` document.
class Classroom {
  const Classroom({
    required this.classroomId,
    this.classroomName,
    this.stemClubName,
    this.type,
    this.grade,
    this.section,
    this.board,
    this.institutionName,
    this.studentCounter,
    this.programmes = const [],
  });

  final String classroomId;
  final String? classroomName;

  /// Used INSTEAD of [classroomName] when [type] is `STEM-CLUB`.
  final String? stemClubName;

  final String? type;

  /// Null means "no grade", not zero. See the note on `ClassroomRef.grade`.
  final int? grade;

  final String? section;
  final String? board;
  final String? institutionName;

  /// Note the field name on the document: `studentCounter`, not studentCount.
  final int? studentCounter;

  final List<ClassroomProgramme> programmes;

  static const String collection = 'Classrooms';

  bool get isStemClub => (type ?? '').toUpperCase() == 'STEM-CLUB';

  String get displayName {
    final primary = (isStemClub ? stemClubName : classroomName)?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    for (final candidate in [stemClubName, classroomName]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return classroomId;
  }

  String? get gradeSectionLabel {
    final parts = <String>[
      if (grade != null) 'Grade $grade',
      if ((section ?? '').trim().isNotEmpty) section!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Every learning unit this classroom is doing, across all its programmes,
  /// with the workflow each one runs here.
  List<WorkflowBinding> get allWorkflows => [
    for (final p in programmes) ...p.workflows,
  ];

  /// The workflow this classroom uses for [learningUnitId], or null when the
  /// classroom is not running that unit at all.
  String? workflowIdFor(String learningUnitId) {
    for (final binding in allWorkflows) {
      if (binding.learningUnitId == learningUnitId) return binding.workflowId;
    }
    return null;
  }

  factory Classroom.fromMap(String classroomId, Map<String, dynamic> data) {
    return Classroom(
      classroomId: classroomId,
      classroomName:
          SafeParse.asDisplayString(data['classroomName']) ??
          // "name" on older documents, per SCHEMA.md.
          SafeParse.asDisplayString(data['name']),
      stemClubName: SafeParse.asDisplayString(data['stemClubName']),
      type: SafeParse.asDisplayString(data['type']),
      grade: SafeParse.asIntOrNull(
        data['grade'],
        collection: collection,
        docId: classroomId,
        field: 'grade',
      ),
      section: SafeParse.asDisplayString(data['section']),
      board: SafeParse.asDisplayString(data['board']),
      institutionName: SafeParse.asDisplayString(data['institutionName']),
      studentCounter: SafeParse.asIntOrNull(
        data['studentCounter'],
        collection: collection,
        docId: classroomId,
        field: 'studentCounter',
      ),
      programmes: ClassroomProgramme.listFrom(
        data['programmes'],
        collection: collection,
        docId: classroomId,
      ),
    );
  }
}
