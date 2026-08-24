import '../utils/safe_parse.dart';
import 'classroom_ref.dart';

/// One teacher's TEACHING RECORD: `teachers/{teacherId}` in `teacher-corner-dev`.
///
/// TWO THINGS ARE CALLED "the teacher" IN THIS DATABASE and conflating them is
/// the mistake this class exists to avoid:
///
///   * `users/{uid}`        WHO IS SIGNED IN. Keyed by the Firebase Auth uid,
///                         written by the web app on every sign-in. Modelled by
///                         [TeacherProfile].
///   * `teachers/{docId}`   WHAT THEY TEACH. A record an admin registered, with
///                         a CLIENT-ALLOCATED document id. Modelled here.
///
/// THE DOCUMENT ID IS NOT THE UID, and that is the single most important thing
/// on this class. The web app allocates the id when an admin registers the
/// teacher, before any Auth account for that person exists; the uid arrives
/// later, the first time they sign in with the registered number, and is stamped
/// into `teacherMeta.uid`. So this document is found by QUERYING [uidFieldPath],
/// never by `doc(uid).get()` — which would silently return "does not exist"
/// rather than an error.
///
/// The `classrooms` map here is a denormalised SUMMARY. It is what the dashboard
/// and the classroom list read, because it answers "which classrooms are mine"
/// in one document read. The moment a screen needs the full picture, including
/// which workflow a classroom runs for a learning unit, it reads the
/// authoritative `classrooms/{id}` document instead.
class Teacher {
  const Teacher({
    required this.docId,
    this.uid,
    this.name,
    this.meta,
    this.classrooms = const [],
  });

  /// The Firestore document id: `teachers/{docId}`. Client-allocated by the web
  /// app, and NOT the Auth uid.
  final String docId;

  /// The Firebase Auth uid from `teacherMeta.uid`, or null when this record has
  /// never been linked to a sign-in.
  ///
  /// Absent is a real and common state: registering a teacher creates no Auth
  /// user, so a record sits unlinked until that person signs in.
  final String? uid;

  /// Top-level `name`. The fallback for documents written before `teacherMeta`
  /// existed, which is why [displayName] prefers the meta pair over it.
  ///
  /// The web app does not write this field. Kept because a document imported
  /// from ThinkTac production does carry it.
  final String? name;

  /// Absent on older documents, so nullable rather than an empty object:
  /// "no meta at all" and "meta present but blank" are different states and
  /// only the first one should fall back to [name].
  final TeacherMeta? meta;

  /// The teacher's classrooms, from the denormalised map keyed by classroom id.
  final List<ClassroomRef> classrooms;

  /// `teachers`, LOWERCASE. The web app's collection name in
  /// `teacher-corner-dev`. ThinkTac production's capitalised `Teachers` does not
  /// exist in this database.
  static const String collection = 'teachers';

  /// The field path the uid lives at, and the ONLY way to find a teacher from a
  /// signed-in session. A dotted path, so it queries the nested map rather than
  /// a top-level field.
  static const String uidFieldPath = 'teacherMeta.uid';

  /// Parses a `teachers/{docId}` document.
  ///
  /// [docId] is the DOCUMENT id, not the uid. The uid is read from the document
  /// body, because that is where it lives.
  factory Teacher.fromMap(String docId, Map<String, dynamic> data) {
    final rawMeta = data['teacherMeta'];
    TeacherMeta? meta;
    if (rawMeta != null) {
      // asStringKeyedMap logs and yields {} when the field is not a Map at all,
      // so a garbage teacherMeta degrades to "no meta" instead of throwing.
      final metaMap = SafeParse.asStringKeyedMap(
        rawMeta,
        collection: collection,
        docId: docId,
        field: 'teacherMeta',
      );
      if (metaMap.isNotEmpty) meta = TeacherMeta.fromMap(metaMap);
    }
    return Teacher(
      docId: docId,
      uid: meta?.uid,
      name: SafeParse.asDisplayString(data['name']),
      meta: meta,
      classrooms: ClassroomRef.listFrom(
        data['classrooms'],
        collection: collection,
        docId: docId,
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

  /// The school, from `teacherMeta` when present and otherwise from the
  /// classrooms.
  ///
  /// TWO SOURCES BECAUSE THE TWO DATABASES DISAGREE. ThinkTac production puts
  /// `institutionName` on `teacherMeta`; the web app's `TeacherMeta` has no such
  /// field and denormalises the school onto each classroom entry instead. So the
  /// fallback is not defensive padding, it is the only path that resolves
  /// against real `teacher-corner-dev` data.
  ///
  /// Takes the first classroom that names one rather than trying to reconcile
  /// several: a teacher at two schools has no single institution, and picking
  /// the first is at least a true statement about one of their classrooms.
  String? get institutionName {
    final fromMeta = meta?.institutionName?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
    for (final classroom in classrooms) {
      final name = classroom.institutionName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

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
    this.uid,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.email,
    this.institutionName,
    this.designation,
  });

  /// The Firebase Auth uid, ABSENT until this teacher has signed in.
  final String? uid;

  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? email;

  /// Present on ThinkTac production documents, ABSENT on every
  /// `teacher-corner-dev` one. Read rather than dropped so an imported
  /// production document still resolves its school; see
  /// [Teacher.institutionName] for what happens when it is missing.
  final String? institutionName;

  /// Production's field. Not written by the web app, so expect null.
  final String? designation;

  factory TeacherMeta.fromMap(Map<String, dynamic> map) => TeacherMeta(
    uid: SafeParse.asDisplayString(map['uid']),
    firstName: SafeParse.asDisplayString(map['firstName']),
    lastName: SafeParse.asDisplayString(map['lastName']),
    // `phoneNumber` then `phone`: the web app writes BOTH with the same
    // subscriber digits and production writes one or the other, so reading a
    // single name would come back null against half the data.
    phoneNumber: SafeParse.asDisplayString(map['phoneNumber']) ??
        SafeParse.asDisplayString(map['phone']),
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
