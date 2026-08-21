import '../utils/safe_parse.dart';
import 'classroom_ref.dart';

/// One teacher's profile document: `Teachers/{uid}`.
///
/// The `classrooms` map on this document is a denormalised SUMMARY. It is what
/// the dashboard and the classroom list read, because it answers "which
/// classrooms are mine" in a single document read. The moment a screen needs
/// the full picture, including which workflow a classroom runs for a learning
/// unit, it reads the authoritative `Classrooms/{id}` document instead.
class Teacher {
  const Teacher({
    required this.uid,
    this.name,
    this.meta,
    this.classrooms = const [],
  });

  /// The Firebase Auth uid, which is also the document id.
  final String uid;

  /// Top-level `name`. SCHEMA.md calls this the fallback for documents written
  /// before `teacherMeta` existed, which is why [displayName] prefers the meta
  /// pair over it rather than the other way round.
  final String? name;

  /// Absent on older documents, so nullable rather than an empty object:
  /// "no meta at all" and "meta present but blank" are different states and
  /// only the first one should fall back to [name].
  final TeacherMeta? meta;

  /// The teacher's classrooms, from the denormalised map keyed by classroom id.
  final List<ClassroomRef> classrooms;

  static const String collection = 'Teachers';

  factory Teacher.fromMap(String uid, Map<String, dynamic> data) {
    final rawMeta = data['teacherMeta'];
    TeacherMeta? meta;
    if (rawMeta != null) {
      // asStringKeyedMap logs and yields {} when the field is not a Map at all,
      // so a garbage teacherMeta degrades to "no meta" instead of throwing.
      final metaMap = SafeParse.asStringKeyedMap(
        rawMeta,
        collection: collection,
        docId: uid,
        field: 'teacherMeta',
      );
      if (metaMap.isNotEmpty) meta = TeacherMeta.fromMap(metaMap);
    }
    return Teacher(
      uid: uid,
      name: SafeParse.asDisplayString(data['name']),
      meta: meta,
      classrooms: ClassroomRef.listFrom(
        data['classrooms'],
        collection: collection,
        docId: uid,
      ),
    );
  }

  /// Best available human name, or the empty string when the document carries
  /// none. Never the literal "null", which is what a bare `'${data['name']}'`
  /// would render into the dashboard header.
  String get displayName {
    final full = meta?.fullName;
    if (full != null && full.isNotEmpty) return full;
    final trimmed = name?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    return '';
  }

  String? get institutionName => meta?.institutionName;

  int get classroomCount => classrooms.length;

  /// Distinct programmes across every classroom.
  ///
  /// Counted by id, not summed per classroom: one programme normally runs in
  /// several of a teacher's classrooms, and "3 programmes" meaning the same
  /// programme counted three times would be a lie on the dashboard.
  int get programmeCount => {
    for (final classroom in classrooms)
      for (final programme in classroom.programmes) programme.programmeId,
  }.length;
}

/// The nested `teacherMeta` map. A map, not a subcollection.
class TeacherMeta {
  const TeacherMeta({
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.email,
    this.institutionName,
    this.designation,
  });

  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? email;
  final String? institutionName;
  final String? designation;

  factory TeacherMeta.fromMap(Map<String, dynamic> map) => TeacherMeta(
    firstName: SafeParse.asDisplayString(map['firstName']),
    lastName: SafeParse.asDisplayString(map['lastName']),
    phoneNumber: SafeParse.asDisplayString(map['phoneNumber']),
    email: SafeParse.asDisplayString(map['email']),
    institutionName: SafeParse.asDisplayString(map['institutionName']),
    designation: SafeParse.asDisplayString(map['designation']),
  );

  /// Null rather than a stray space when one half of the pair is missing.
  String? get fullName {
    final parts = [firstName, lastName]
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' ');
  }
}
