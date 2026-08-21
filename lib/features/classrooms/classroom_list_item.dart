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

    final programmes = full != null && full.programmes.isNotEmpty
        ? full.programmes.map((p) => p.label).toList()
        : ref.programmes.map((p) => p.label).toList();

    return ClassroomListItem(
      classroomId: ref.classroomId,
      // displayName on either model already falls back to the id, so it is
      // never blank; pick the authoritative one when we have it.
      displayName: full?.displayName ?? ref.displayName,
      gradeSectionLabel:
          firstNonEmpty(full?.gradeSectionLabel, ref.gradeSectionLabel),
      institutionName: firstNonEmpty(full?.institutionName, ref.institutionName),
      studentCounter: full?.studentCounter,
      programmeLabels: programmes,
      isStemClub: full?.isStemClub ?? ref.isStemClub,
      hasAuthoritativeDoc: full != null,
    );
  }
}
