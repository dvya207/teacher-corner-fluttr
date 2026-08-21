import '../utils/safe_parse.dart';

/// One teacher's profile document: `Teachers/{uid}`.
///
/// Deliberately partial. The denormalised `classrooms` map also lives on this
/// document, but SCHEMA.md is explicit that it is a summary; Phase 3 reads the
/// authoritative `Classrooms/{id}` documents instead, so parsing it here would
/// create a second source of truth for the same thing.
class Teacher {
  const Teacher({required this.uid, this.name, this.meta});

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
