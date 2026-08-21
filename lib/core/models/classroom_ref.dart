import '../utils/keyed_entries.dart';
import '../utils/safe_parse.dart';
import 'programme_ref.dart';

/// The denormalised classroom summary nested on `Teachers/{uid}.classrooms`.
///
/// Enough to list and route to a classroom. The full picture, including the
/// learning units and their workflows, lives on `Classrooms/{id}`, which is a
/// separate model on purpose so the two never get confused for one another.
class ClassroomRef {
  const ClassroomRef({
    required this.classroomId,
    this.classroomName,
    this.stemClubName,
    this.type,
    this.grade,
    this.section,
    this.institutionName,
    this.programmes = const [],
  });

  final String classroomId;
  final String? classroomName;

  /// Used INSTEAD of [classroomName] when [type] is `STEM-CLUB`.
  final String? stemClubName;

  final String? type;

  /// Nullable, and null genuinely means "no grade" rather than zero.
  ///
  /// SCHEMA.md warns the production data has at least one classroom whose
  /// `grade` is the String "ET". `SafeParse.asIntOrNull` turns that into null
  /// and logs it, which is why the UI must treat null as "omit the grade" and
  /// never render it as a number.
  final int? grade;

  final String? section;
  final String? institutionName;
  final List<ProgrammeRef> programmes;

  bool get isStemClub => (type ?? '').toUpperCase() == 'STEM-CLUB';

  /// Never empty and never the string "null".
  String get displayName {
    final primary = (isStemClub ? stemClubName : classroomName)?.trim();
    if (primary != null && primary.isNotEmpty) return primary;
    // Either the type disagrees with which name field was populated, or neither
    // was. Take whichever name exists before falling back to the id.
    for (final candidate in [stemClubName, classroomName]) {
      final trimmed = candidate?.trim();
      if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    }
    return classroomId;
  }

  /// "Grade 7 · A", or just "A", or null when there is nothing to say. Returns
  /// null rather than a placeholder so callers can omit the line entirely.
  String? get gradeSectionLabel {
    final parts = <String>[
      if (grade != null) 'Grade $grade',
      if ((section ?? '').trim().isNotEmpty) section!.trim(),
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  factory ClassroomRef.fromMap(
    String classroomId,
    Map<String, dynamic> data, {
    String? collection,
  }) {
    return ClassroomRef(
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
      institutionName: SafeParse.asDisplayString(data['institutionName']),
      programmes: ProgrammeRef.listFrom(
        data['programmes'],
        collection: collection,
        docId: classroomId,
      ),
    );
  }

  /// Parses the `classrooms` field on a teacher document: a map keyed by
  /// classroom id, occasionally a list. The key is preferred over the nested
  /// `classroomId`, which is a duplicate and sometimes absent.
  static List<ClassroomRef> listFrom(
    dynamic raw, {
    String? collection,
    String? docId,
  }) {
    final out = <ClassroomRef>[];
    for (final entry in KeyedEntries.from(
      raw,
      collection: collection,
      docId: docId,
      field: 'classrooms',
    )) {
      final id =
          entry.key ??
          SafeParse.asRefString(
            entry.value['classroomId'],
            collection: collection,
            docId: docId,
            field: 'classrooms.classroomId',
          );
      if (id == null || id.isEmpty) continue;
      out.add(ClassroomRef.fromMap(id, entry.value, collection: collection));
    }
    return out;
  }
}
