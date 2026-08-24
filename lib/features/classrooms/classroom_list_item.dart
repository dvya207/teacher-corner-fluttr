import '../../core/models/classroom.dart';
import '../../core/models/classroom_ref.dart';

/// One row of the classroom list, assembled from BOTH places a classroom is
/// described.
///
/// The card has to show name, grade/section, institution and student count, and
/// those four fields do not live together. `studentCounter` and `board` are only
/// on the authoritative `Classrooms/{id}` document, while the teacher's own
/// document carries the denormalised summary that tells us which classrooms are
/// ours at all. So the list is one read of the teacher plus one read per
/// classroom, merged here.
class ClassroomListItem {
  const ClassroomListItem({
    required this.classroomId,
    required this.displayName,
    this.gradeSectionLabel,
    this.institutionName,
    this.studentCounter,
    this.programmeLabels = const [],
    this.programmeIds = const [],
    this.isStemClub = false,
    this.hasAuthoritativeDoc = false,
  });

  final String classroomId;
  final String displayName;
  final String? gradeSectionLabel;
  final String? institutionName;

  /// Null when unknown, which is different from zero. A classroom with no
  /// students yet and a classroom whose document we could not read should not
  /// look the same.
  final int? studentCounter;

  final List<String> programmeLabels;

  /// The ids behind [programmeLabels], in the same order and from the SAME
  /// source, so the two can never describe different programmes.
  ///
  /// Carried alongside the labels because counting distinct programmes has to
  /// be done by id: two programmes can share a display name, and a name is not
  /// an identity. The dashboard's "N Programmes" is computed from these.
  final List<String> programmeIds;

  final bool isStemClub;

  /// False when the teacher's document references a classroom whose real
  /// document is missing. The row still renders, from the summary alone, rather
  /// than vanishing without explanation.
  final bool hasAuthoritativeDoc;

  /// Prefers the authoritative document field by field, falling back to the
  /// denormalised summary. Not "one or the other": the summary can carry an
  /// institution the authoritative document has left blank, and vice versa.
  factory ClassroomListItem.merge({
    required ClassroomRef ref,
    Classroom? full,
  }) {
    String? firstNonEmpty(String? a, String? b) {
      for (final candidate in [a, b]) {
        final trimmed = candidate?.trim();
        if (trimmed != null && trimmed.isNotEmpty) return trimmed;
      }
      return null;
    }

    // ONE source chosen, then both the labels and the ids read off it. Reading
    // labels from the authoritative document and ids from the summary would let
    // a chip say one thing while the count meant another — which is exactly the
    // divergence this list is in the middle of.
    //
    // The authoritative document wins when it has programmes, because it is
    // what the classroom itself says it runs. The teacher's denormalised copy
    // can be stale: it currently names one programme for a classroom whose own
    // document names two different ones.
    final useAuthoritative = full != null && full.programmes.isNotEmpty;
    final programmeLabels = useAuthoritative
        ? full.programmes.map((p) => p.label).toList()
        : ref.programmes.map((p) => p.label).toList();
    final programmeIds = useAuthoritative
        ? full.programmes.map((p) => p.programmeId).toList()
        : ref.programmes.map((p) => p.programmeId).toList();

    return ClassroomListItem(
      classroomId: ref.classroomId,
      // displayName on either model already falls back to the id, so it is
      // never blank; pick the authoritative one when we have it.
      displayName: full?.displayName ?? ref.displayName,
      gradeSectionLabel: firstNonEmpty(
        full?.gradeSectionLabel,
        ref.gradeSectionLabel,
      ),
      institutionName: firstNonEmpty(
        full?.institutionName,
        ref.institutionName,
      ),
      studentCounter: full?.studentCounter,
      programmeLabels: programmeLabels,
      programmeIds: programmeIds,
      isStemClub: full?.isStemClub ?? ref.isStemClub,
      hasAuthoritativeDoc: full != null,
    );
  }

  /// Merges a teacher's classroom summaries with whichever authoritative
  /// documents were readable, preserving the order of [refs].
  ///
  /// Shared by the classroom list and the dashboard so there is one definition
  /// of what a classroom row is. Passing an empty [full] is legitimate: it
  /// yields rows built from the summary alone, which is what the dashboard
  /// falls back to when the second round of reads fails.
  static List<ClassroomListItem> mergeAll({
    required List<ClassroomRef> refs,
    required List<Classroom> full,
  }) {
    final byId = {for (final classroom in full) classroom.classroomId: classroom};
    return [
      for (final ref in refs)
        ClassroomListItem.merge(ref: ref, full: byId[ref.classroomId]),
    ];
  }
}
