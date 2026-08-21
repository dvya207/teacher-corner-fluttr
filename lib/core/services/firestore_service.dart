import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firestore_ref.dart';
import '../models/assignment_evidence.dart';
import '../models/classroom.dart';
import '../models/learning_unit.dart';
import '../models/teacher.dart';
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

  /// The signed-in teacher's profile, or null when no document exists.
  ///
  /// A missing document is a legitimate state, not an error: a Firebase Auth
  /// user can exist before anyone has provisioned a teacher record against that
  /// uid, which is exactly what happens on a freshly seeded database. Callers
  /// degrade the profile rather than treating it as a failure.
  Future<Teacher?> fetchTeacher(String uid) async {
    final snap = await _db.collection(Teacher.collection).doc(uid).get();
    if (!snap.exists) return null;
    return Teacher.fromMap(snap.id, snap.data() ?? const <String, dynamic>{});
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

  DocumentReference<Map<String, dynamic>> _submissionDoc({
    required String uid,
    required String classroomId,
    required String programmeId,
  }) =>
      _db
          .collection(Teacher.collection)
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
