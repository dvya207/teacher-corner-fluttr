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

  /// The teaching record for the signed-in teacher, by uid and then by phone
  /// number.
  ///
  /// A QUERY, NOT A DOCUMENT GET. `teachers/{docId}` ids are allocated by the
  /// web app when an admin registers a teacher, long before that person has an
  /// Auth account, so `doc(uid).get()` does not merely fail: it succeeds and
  /// reports "does not exist" for a teacher whose record is sitting right there
  /// under another id.
  ///
  /// TWO LOOKUPS, AND THE SECOND ONE IS WHY THIS WORKS AT ALL.
  ///
  /// `teacherMeta.uid` is stamped by the WEB app's `linkSignedInUid`, which runs
  /// on a WEB sign-in. A teacher an admin registers who then signs into THIS app
  /// has never been through that code, so their record carries no uid and the
  /// first query finds nothing — even though the record exists with their
  /// classrooms on it. In live data six of seven records were unstamped; the one
  /// that worked belonged to someone who happened to have used the web app.
  ///
  /// So when the uid finds nothing, the number is tried. That is the SAME key the
  /// web app links on (`teacherMeta.phoneNumber ?? teacherMeta.phone`, compared
  /// as subscriber digits), so this app is not inventing an identity rule, it is
  /// applying the existing one at read time instead of at write time.
  ///
  /// ONLY AN UNLINKED RECORD IS ACCEPTED BY NUMBER, mirroring the web app's
  /// "only fills a blank". A record already stamped with a DIFFERENT uid belongs
  /// to somebody else — phone numbers get recycled — and matching it by number
  /// would hand one teacher another's classrooms. That check is the whole safety
  /// of the fallback.
  ///
  /// NOTHING IS WRITTEN HERE. `tcDivyaVerifyOtp` stamps `teacherMeta.uid`
  /// server-side the moment a correct code is presented, which is the one point
  /// where the number is PROVEN rather than claimed, and where the Admin SDK
  /// belongs rather than the client.
  ///
  /// So the phone fallback is now a SAFETY NET, not the normal path: it covers
  /// records registered before that linking existed, and the case where the
  /// stamping write failed — it is best-effort by design, because a teacher with
  /// a correct code must not lose their session over bookkeeping. Keeping the
  /// fallback means such a teacher still sees their classrooms.
  Future<Teacher?> fetchTeacher(String uid, {String? phoneNumber}) async {
    // 1. By uid. Exact, indexed, and correct for anyone the web app has linked.
    //    limit(1): one person should have one record, and if the data ever
    //    carried two, taking the first beats pretending this app can reconcile
    //    them.
    final byUid = await _db
        .collection(Teacher.collection)
        .where(Teacher.uidFieldPath, isEqualTo: uid)
        .limit(1)
        .get();
    if (byUid.docs.isNotEmpty) {
      final doc = byUid.docs.first;
      return Teacher.fromMap(doc.id, doc.data());
    }

    // 2. By number. Null digits means there is nothing to match on — a Google
    //    sign-in with no phone attached — so stop rather than guess.
    final digits = Teacher.subscriberDigits(phoneNumber);
    if (digits == null) return null;

    // Both field paths, in turn: the web app writes both with the same value,
    // a production import may carry only one, and Firestore cannot OR across
    // two fields in a single query.
    for (final field in [Teacher.phoneNumberFieldPath, Teacher.phoneFieldPath]) {
      final byPhone = await _db
          .collection(Teacher.collection)
          .where(field, isEqualTo: digits)
          // Not limit(1): the first match on this number might be somebody
          // else's already-linked record, which has to be skipped rather than
          // returned. A handful is plenty for one number.
          .limit(5)
          .get();

      for (final doc in byPhone.docs) {
        final teacher = Teacher.fromMap(doc.id, doc.data());
        final stamped = teacher.uid;
        // Unlinked, or already this teacher's. Anything else is another
        // person's record that happens to share a recycled number.
        if (stamped == null || stamped.isEmpty || stamped == uid) {
          return teacher;
        }
      }
    }

    return null;
  }

  /// Both halves of the signed-in teacher, in one call.
  ///
  /// The two reads run CONCURRENTLY because neither depends on the other, and
  /// they FAIL TOGETHER: a caller that got one and not the other would have to
  /// invent a policy for the gap, and every caller would invent a different one.
  /// Either read legitimately returning null is a separate matter, and is what
  /// [TeacherAccount.isLinked] and [TeacherAccount.isEmpty] report.
  Future<TeacherAccount> fetchTeacherAccount(
    String uid, {
    String? phoneNumber,
  }) async {
    final results = await Future.wait([
      fetchTeacherProfile(uid),
      fetchTeacher(uid, phoneNumber: phoneNumber),
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
