import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firestore_ref.dart';
import '../models/assignment_evidence.dart';
import '../models/classroom.dart';
import '../models/learning_unit.dart';
import '../models/programme.dart';
import '../models/teacher.dart';
import '../models/teacher_account.dart';
import '../models/teacher_profile.dart';
import '../models/workflow.dart';
import '../utils/safe_parse.dart';

/// Every Firestore read in the app goes through this class. No screen and no
/// provider touches `cloud_firestore` directly.
///
/// It is a class rather than a pile of static helpers for two reasons: the
/// [FirebaseFirestore] handle is injected, so a widget test can hand it a fake
/// without a live project, and the collection-name string literals live in
/// exactly one file.
///
/// The default handle is [db] from `firestore_ref.dart`, never
/// `FirebaseFirestore.instance` — that constant always resolves to `(default)`,
/// which is not this app's database and fails silently rather than loudly.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _injected = firestore;

  final FirebaseFirestore? _injected;

  /// Resolved lazily, on first use. Eagerly defaulting to [db] in the
  /// constructor would call `Firebase.app()` the moment anyone built a
  /// FirestoreService, which throws in a unit test where Firebase was never
  /// initialised. A test double that overrides every read must be able to exist
  /// without touching Firebase at all.
  late final FirebaseFirestore _db = _injected ?? db;

  /// The signed-in teacher's own profile: `users/{uid}`.
  ///
  /// A doc-by-id read, because here the uid genuinely IS the document id. Null
  /// when no document exists, which happens for a teacher who has only ever
  /// signed into this app: `users/{uid}` is written by the WEB app on sign-in
  /// and this app never writes it.
  Future<TeacherProfile?> fetchTeacherProfile(String uid) async {
    final snap =
        await _db.collection(TeacherProfile.collection).doc(uid).get();
    if (!snap.exists) return null;
    return TeacherProfile.fromMap(
      snap.id,
      snap.data() ?? const <String, dynamic>{},
    );
  }

  /// The teaching record linked to [uid], or null when none is.
  ///
  /// A QUERY, NOT A DOCUMENT GET, and that is the single most important line in
  /// this file. `teachers/{docId}` ids are allocated by the web app when an
  /// admin registers a teacher, long before that person has an Auth account; the
  /// uid is stamped into `teacherMeta.uid` the first time they sign in. So
  /// `doc(uid).get()` does not merely fail, it succeeds and reports "does not
  /// exist" for a teacher whose record is sitting right there under another id.
  ///
  /// `limit(1)`: one person should have one record. If the data ever carried two
  /// linked to one uid, taking the first is a defensible reading and cheaper
  /// than pretending the app can reconcile them.
  Future<Teacher?> fetchTeacher(String uid) async {
    final result = await _db
        .collection(Teacher.collection)
        .where(Teacher.uidFieldPath, isEqualTo: uid)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    final doc = result.docs.first;
    return Teacher.fromMap(doc.id, doc.data());
  }

  /// Both halves of the signed-in teacher, in one call.
  ///
  /// The two reads run CONCURRENTLY because neither depends on the other, and
  /// they FAIL TOGETHER: a caller that got one and not the other would have to
  /// invent a policy for the gap, and every caller would invent a different one.
  /// Either read legitimately returning null is a separate matter, and is what
  /// [TeacherAccount.isLinked] and [TeacherAccount.isEmpty] report.
  Future<TeacherAccount> fetchTeacherAccount(String uid) async {
    final results = await Future.wait([
      fetchTeacherProfile(uid),
      fetchTeacher(uid),
    ]);
    return TeacherAccount(
      uid: uid,
      profile: results[0] as TeacherProfile?,
      teaching: results[1] as Teacher?,
    );
  }

  /// The authoritative classroom document, or null when it does not exist.
  ///
  /// A teacher's denormalised `classrooms` map can name a classroom whose real
  /// document has since been deleted, so "referenced but absent" is a state the
  /// caller has to handle rather than an impossibility.
  Future<Classroom?> fetchClassroom(String classroomId) async {
    final snap = await _db
        .collection(Classroom.collection)
        .doc(classroomId)
        .get();
    if (!snap.exists) return null;
    return Classroom.fromMap(snap.id, snap.data() ?? const <String, dynamic>{});
  }

  /// Fetches several classrooms concurrently, dropping the ones that do not
  /// exist.
  ///
  /// Deliberately N parallel document gets rather than a `whereIn` query: the
  /// ids come from the teacher's own document, document reads hit Firestore's
  /// cache individually and degrade one row at a time, and `whereIn` is capped
  /// at 30 values, which a teacher with many classrooms would silently exceed.
  Future<List<Classroom>> fetchClassrooms(Iterable<String> classroomIds) async {
    final ids = classroomIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final results = await Future.wait(ids.map(fetchClassroom));
    return results.whereType<Classroom>().toList();
  }

  /// One programme from the catalogue, or null when the document does not
  /// exist.
  ///
  /// A classroom's `programmes` map can name a programme whose catalogue entry
  /// has since been removed, so "referenced but absent" is a state the caller
  /// handles rather than an impossibility. The classroom screens do not need
  /// this read at all — they carry a denormalised name — so it is paid for only
  /// when a teacher opens the programme itself.
  Future<Programme?> fetchProgramme(String programmeId) async {
    final snap = await _db
        .collection(Programme.collection)
        .doc(programmeId)
        .get();
    if (!snap.exists) return null;
    return Programme.fromMap(snap.id, snap.data() ?? const <String, dynamic>{});
  }

  /// A learning unit, shared across classrooms.
  Future<LearningUnit?> fetchLearningUnit(String learningUnitId) async {
    final snap = await _db
        .collection(LearningUnit.collection)
        .doc(learningUnitId)
        .get();
    if (!snap.exists) return null;
    return LearningUnit.fromMap(
      snap.id,
      snap.data() ?? const <String, dynamic>{},
    );
  }

  /// The workflow a specific classroom runs for a specific learning unit.
  ///
  /// The caller has to have resolved the workflow id from the CLASSROOM first,
  /// via `Classroom.workflowIdFor`. There is no read that goes from a learning
  /// unit to its workflow, because that relationship does not exist: the same
  /// unit runs different workflows in different classrooms.
  Future<Workflow?> fetchWorkflow(String workflowId) async {
    final snap = await _db
        .collection(Workflow.collection)
        .doc(workflowId)
        .get();
    if (!snap.exists) return null;
    return Workflow.fromMap(snap.id, snap.data() ?? const <String, dynamic>{});
  }

  /// Fetches several learning units concurrently, dropping any that do not
  /// exist.
  ///
  /// Same shape and same reasoning as [fetchClassrooms]: per-document reads
  /// degrade one row at a time, and `whereIn` caps out at 30 ids.
  Future<List<LearningUnit>> fetchLearningUnits(
    Iterable<String> learningUnitIds,
  ) async {
    final ids = learningUnitIds.toSet().toList();
    if (ids.isEmpty) return const [];
    final results = await Future.wait(ids.map(fetchLearningUnit));
    return results.whereType<LearningUnit>().toList();
  }

  // ── Evidence ───────────────────────────────────────────────────────────────

  /// `users/{uid}/submissions/{classroomId}-{programmeId}`.
  ///
  /// UNDER `users`, NOT `teachers`, for two independent reasons.
  ///
  /// CORRECTNESS. `teachers/{docId}` is not keyed by uid, so there is no
  /// `teachers/{uid}` to nest under; writing one would create a junk top-level
  /// document in a collection a live app reads.
  ///
  /// AUTHORISATION. The web app's deployed rules already grant
  /// `users/{uid}/{document=**}` to that uid and nobody else, so this path needs
  /// NO rules change and NO deploy from this repo. The web app itself documents
  /// this shape as the intended home for anything private to one teacher
  /// (`userSubcollection` in its `firestore-paths.ts`). Nothing the web app uses
  /// is touched: it has no submissions, no evidence and no Storage wiring at
  /// all, which was verified before choosing this location.
  DocumentReference<Map<String, dynamic>> _submissionDoc({
    required String uid,
    required String classroomId,
    required String programmeId,
  }) =>
      _db
          .collection(TeacherProfile.collection)
          .doc(uid)
          .collection(AssignmentEvidence.submissionsSubcollection)
          .doc(AssignmentEvidence.documentId(
            classroomId: classroomId,
            programmeId: programmeId,
          ));

  /// The evidence recorded for one assignment, or null when nothing has been
  /// submitted yet. A missing document is the normal starting state.
  Future<AssignmentEvidence?> fetchEvidence({
    required String uid,
    required String classroomId,
    required String programmeId,
    required String assignmentId,
  }) async {
    final snap = await _submissionDoc(
      uid: uid,
      classroomId: classroomId,
      programmeId: programmeId,
    ).get();
    if (!snap.exists) return null;

    final data = snap.data() ?? const <String, dynamic>{};
    final raw = data[assignmentId];
    if (raw == null) return null;

    return AssignmentEvidence.fromMap(
      assignmentId,
      SafeParse.asStringKeyedMap(
        raw,
        collection: AssignmentEvidence.submissionsSubcollection,
        docId: snap.id,
        field: assignmentId,
      ),
      docId: snap.id,
    );
  }

  /// Writes one assignment's evidence.
  ///
  /// Merged at the assignment key so sibling assignments in the same
  /// classroom+programme document are untouched. Array fields are replaced
  /// wholesale by a merge, which is what a removal needs.
  Future<void> writeEvidence({
    required String uid,
    required String classroomId,
    required String programmeId,
    required AssignmentEvidence evidence,
  }) =>
      _submissionDoc(
        uid: uid,
        classroomId: classroomId,
        programmeId: programmeId,
      ).set(
        {evidence.assignmentId: evidence.toMap()},
        SetOptions(merge: true),
      );
}
