import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firestore_ref.dart';
import '../models/assignment.dart';
import '../models/quiz_scoring.dart';
import '../models/assignment_evidence.dart';
import '../models/classroom.dart';
import '../models/learning_unit.dart';
import '../models/board_grade_resource.dart';
import '../models/learning_unit_resources.dart';
import '../models/learning_unit_taxonomy.dart';
import '../models/programme.dart';
import '../models/teacher.dart';
import '../models/teacher_account.dart';
import '../models/teacher_profile.dart';
import '../models/workflow.dart';
import '../models/workflow_progress.dart';
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
    final snap = await _db.collection(TeacherProfile.collection).doc(uid).get();
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
    for (final field in [
      Teacher.phoneNumberFieldPath,
      Teacher.phoneFieldPath,
    ]) {
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

  /// The 44 taxonomy rows from `Configuration/learningUnitDomains`.
  ///
  /// Returns an EMPTY list rather than throwing when the document is missing,
  /// malformed or unreachable, because the caller's correct response to all
  /// three is identical: keep the static rows. The app must categorise units
  /// with this collection unreadable, which is the whole reason the rows are
  /// compiled in as well as seeded.
  Future<List<TaxonomyRow>> fetchLearningUnitTaxonomy() async {
    final snap = await _db
        .collection(LearningUnitTaxonomy.configurationCollection)
        .doc(LearningUnitTaxonomy.configurationDocId)
        .get();
    if (!snap.exists) return const [];

    final raw =
        (snap.data() ??
        const <String, dynamic>{})[LearningUnitTaxonomy.domainsField];
    if (raw is! List) return const [];

    final rows = <TaxonomyRow>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final row = TaxonomyRow.fromMap(
        entry.map((key, value) => MapEntry(key.toString(), value)),
      );
      // A row without its letter pair cannot be looked up, so it is not a row.
      if (row.domainCode.isEmpty || row.subDomainCode.isEmpty) continue;
      rows.add(row);
    }
    return rows;
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

  /// The teacher record linked to this account, or null when there is none.
  ///
  /// `teacherMeta.uid`, NOT `ownerId`. Those are different people by design:
  /// ownerId is whoever registered the teacher, normally a coordinator acting for
  /// somebody else, and matching on it would attribute a teacher's work to their
  /// administrator. A single where(), so it needs no composite index.
  Future<String?> fetchTeacherDocIdFor(String uid) async {
    if (uid.trim().isEmpty) return null;

    final snap = await _db
        .collection(Teacher.collection)
        .where('teacherMeta.uid', isEqualTo: uid)
        .limit(1)
        .get();

    return snap.docs.isEmpty ? null : snap.docs.first.id;
  }

  /// Assignments by id, dropping any that do not exist.
  ///
  /// PER-DOCUMENT READS rather than a whereIn, for the same reason
  /// [fetchClassrooms] uses them: a missing row degrades on its own, and whereIn
  /// caps at 30 ids. Reserved ids are skipped before the read — `--schema--` and
  /// `--default_assignments--` are reference documents that exist in this
  /// collection and are not assignments.
  Future<List<Assignment>> fetchAssignments(
    Iterable<String> assignmentIds, {
    Map<String, DateTime?> dueDates = const {},
  }) async {
    final ids = assignmentIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty && !Assignment.reservedIds.contains(id))
        .toSet()
        .toList();

    if (ids.isEmpty) return const [];

    final results = await Future.wait(
      ids.map((id) async {
        final snap = await _db.collection(Assignment.collection).doc(id).get();

        if (!snap.exists) return null;

        return Assignment.fromMap(
          snap.id,
          snap.data() ?? const <String, dynamic>{},
          dueDate: dueDates[id],
        );
      }),
    );

    return results.whereType<Assignment>().toList();
  }

  /// Thrown when the classroom and programme have used every allowed attempt.
  ///
  /// A SENTINEL RATHER THAN A BOOLEAN RETURN, because the caller has to tell it
  /// apart from a refused write to say anything useful, and the check happens
  /// inside a transaction where returning normally would still commit.
  static const String maxAttemptsReached = 'MAX_ATTEMPTS_REACHED';

  /// Writes one quiz attempt, in the web app's exact shape.
  ///
  ///     teachers/{teacherDocId}/submissions/{classroomId}-{programmeId}
  ///        + attempts/attempt{N}
  ///        + submissionMeta/{autoId}
  ///
  /// THE SUMMARY IS PER CLASSROOM AND PROGRAMME, NOT PER QUIZ. That is
  /// production's own choice and the web app copies it, so `attemptsCount` and
  /// the cap span every quiz set in that classroom and programme. Surprising, and
  /// changing it here would make the two apps disagree about how many attempts
  /// are left.
  ///
  /// THE CAP IS CHECKED INSIDE THE TRANSACTION, not just before it, or two
  /// devices could each pass a pre-check and both write.
  ///
  /// `latestAttempt` CARRIES EVERYTHING BUT THE QUESTIONS. The summary is read
  /// every time the list is shown, and dragging a whole question set through that
  /// read for a figure the list does not display would be paid for on every load.
  Future<QuizAttemptResult> saveQuizAttempt({
    required String teacherDocId,
    required String uid,
    required String classroomId,
    required String programmeId,
    required String workflowId,
    required Assignment assignment,
    required List<QuizAnswer> answers,
    required String userAgent,
  }) async {
    final summary = _db
        .collection(Teacher.collection)
        .doc(teacherDocId)
        .collection(AssignmentEvidence.submissionsSubcollection)
        .doc('$classroomId-$programmeId');

    final marks = attemptMarks(assignment.questions, answers);
    final stamped = stampAnswers(assignment.questions, answers);
    final percentage = attemptPercentage(marks);

    return _db.runTransaction<QuizAttemptResult>((transaction) async {
      final snapshot = await transaction.get(summary);
      final used = snapshot.exists
          ? (snapshot.data()?['attemptsCount'] as num?)?.toInt() ?? 0
          : 0;

      if (used >= assignment.allowedSubmissions) {
        throw Exception(maxAttemptsReached);
      }

      final attemptNumber = used + 1;
      final attemptId = 'attempt$attemptNumber';

      // Everything the attempt stores EXCEPT the questions, which is exactly
      // what production embeds in the summary.
      final withoutQuestions = <String, dynamic>{
        'studentScore': marks.studentScore,
        'maxScore': marks.maxScore,
        'displayName': assignment.displayName,
        'totalQuestions': assignment.questions.length,
        'id': assignment.docId,
        'totalDurationInHours': 0,
        'totalDurationInMinutes': assignment.totalMinutes,
        'totalDurationInSeconds': 0,
        'userAgent': userAgent,
      };

      transaction.set(summary, {
        'teacherId': uid,
        'classroomId': classroomId,
        'programmeId': programmeId,
        'workflowId': workflowId.isEmpty ? null : workflowId,
        'assignmentId': assignment.docId,
        'displayName': assignment.displayName,
        'totalQuestions': assignment.questions.length,
        'maxScore': marks.maxScore,
        'attemptsCount': attemptNumber,
        'latestAttemptId': attemptId,
        'latestAttempt': {
          'attemptId': attemptId,
          'attemptNumber': attemptNumber,
          'lastAttemptTime': FieldValue.serverTimestamp(),
          'percentage': percentage,
          ...withoutQuestions,
        },
        'lastAttemptTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      transaction.set(summary.collection('attempts').doc(attemptId), {
        'attemptId': attemptId,
        'attemptNumber': attemptNumber,
        'lastAttemptTime': FieldValue.serverTimestamp(),
        'questions': stamped,
        ...withoutQuestions,
      }, SetOptions(merge: true));

      // THE META ROW. Production writes a client IP from its own device-info
      // service; there is none here, so the field is written empty rather than
      // guessed or omitted — its readers expect the key.
      transaction.set(summary.collection('submissionMeta').doc(), {
        'attemptId': attemptId,
        'clientIp': '',
        'submissionTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      return QuizAttemptResult(
        attemptId: attemptId,
        attemptNumber: attemptNumber,
        studentScore: marks.studentScore,
        maxScore: marks.maxScore,
      );
    });
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
  }) => _db
      .collection(TeacherProfile.collection)
      .doc(uid)
      .collection(AssignmentEvidence.submissionsSubcollection)
      .doc(
        AssignmentEvidence.documentId(
          classroomId: classroomId,
          programmeId: programmeId,
        ),
      );

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
  }) => _submissionDoc(
    uid: uid,
    classroomId: classroomId,
    programmeId: programmeId,
  ).set({evidence.assignmentId: evidence.toMap()}, SetOptions(merge: true));

  // -- Form responses ---------------------------------------------------------

  /// `users/{uid}/formResponses/{classroomId}-{assignmentId}`.
  ///
  /// The same subtree, and the same reasoning, as the quiz submissions and the
  /// workflow progress: it is the one place the web app's deployed rules
  /// already grant to this uid, so it needs no rules change and no deploy from
  /// this repo. A teacher's feedback on running an activity is their own record
  /// of their teaching, not a fact about the classroom.
  ///
  /// KEYED BY CLASSROOM as well as assignment, because the same feedback form
  /// is attached to the activity in every classroom that runs it and the
  /// answers are about one class.
  DocumentReference<Map<String, dynamic>> _formResponseDoc({
    required String uid,
    required String classroomId,
    required String assignmentId,
  }) => _db
      .collection(TeacherProfile.collection)
      .doc(uid)
      .collection('formResponses')
      .doc('$classroomId-$assignmentId');

  Future<Map<String, dynamic>?> fetchFormResponse({
    required String uid,
    required String classroomId,
    required String assignmentId,
  }) async {
    final snap = await _formResponseDoc(
      uid: uid,
      classroomId: classroomId,
      assignmentId: assignmentId,
    ).get();
    return snap.data();
  }

  /// Every form response this teacher has recorded in one classroom, keyed by
  /// assignment id.
  ///
  /// ONE QUERY FOR THE CLASSROOM, not one read per assignment. The Submissions
  /// report walks every activity of a programme and each one may carry two or
  /// three forms, so fetching them individually is a round trip per tab on a
  /// screen whose whole job is to list them.
  ///
  /// FILTERED ON THE FIELD, not on the document id. The id happens to be
  /// `{classroomId}-{assignmentId}`, so a prefix scan would work and would
  /// break the day the id scheme changes; the documents carry `classroomId` as
  /// a field precisely so it can be queried.
  Future<Map<String, Map<String, dynamic>>> fetchFormResponsesForClassroom({
    required String uid,
    required String classroomId,
  }) async {
    final snap = await _db
        .collection(TeacherProfile.collection)
        .doc(uid)
        .collection('formResponses')
        .where('classroomId', isEqualTo: classroomId)
        .get();

    final byAssignment = <String, Map<String, dynamic>>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      final assignmentId = SafeParse.asDisplayString(data['assignmentId']);
      if (assignmentId != null && assignmentId.isNotEmpty) {
        byAssignment[assignmentId] = data;
      }
    }
    return byAssignment;
  }

  /// The whole submissions document for one classroom and programme.
  ///
  /// THE WHOLE THING, unlike [fetchEvidence], which digs one assignment out of
  /// it. This document is not a list of one kind of record: it holds the photo
  /// evidence keyed by assignment id AND, at its own top level, the fields a
  /// quiz attempt is written as (`assignmentId`, `maxScore`, `latestAttempt`,
  /// `attemptsCount`). A report that has to show both needs it whole, and
  /// asking twice for the same document to get two halves of it is worse.
  ///
  /// Null when nothing has ever been submitted for that pairing, which is the
  /// normal starting state and not a failure.
  Future<Map<String, dynamic>?> fetchSubmissionRecord({
    required String uid,
    required String classroomId,
    required String programmeId,
  }) async {
    final snap = await _submissionDoc(
      uid: uid,
      classroomId: classroomId,
      programmeId: programmeId,
    ).get();
    return snap.exists ? snap.data() : null;
  }

  /// Saves one teacher's answers.
  ///
  /// A WHOLE-DOCUMENT SET, unlike the progress write's merge. A form is
  /// submitted complete rather than a field at a time, and merging would leave
  /// answers from a previous submission sitting beside the new ones where a
  /// question has since been removed.
  Future<void> writeFormResponse({
    required String uid,
    required String classroomId,
    required String assignmentId,
    required String programmeId,
    required Map<String, Object?> answers,
  }) => _formResponseDoc(
    uid: uid,
    classroomId: classroomId,
    assignmentId: assignmentId,
  ).set({
    'teacherId': uid,
    'classroomId': classroomId,
    'programmeId': programmeId,
    'assignmentId': assignmentId,
    'answers': answers,
    'submittedAt': FieldValue.serverTimestamp(),
  });

  // -- Learning unit resources ------------------------------------------------

  /// The uploads behind one learning unit's step contents.
  ///
  /// QUERIED BY FIELD, not fetched by id. The document has an id of its own
  /// (`rfasd9I0Pi1UXKjNHMOi` for Swimming) and points back at its unit through
  /// `learningUnitDocId`, so there is no path from the unit to the document
  /// except this query.
  ///
  /// Returns empty rather than null when nothing is uploaded, so the caller
  /// treats "no resources document" and "an empty one" the same way: every
  /// content pane says it has nothing yet.
  Future<LearningUnitResources> fetchLearningUnitResources(
    String learningUnitDocId,
  ) async {
    final snap = await _db
        .collection(LearningUnitResources.collection)
        .where(LearningUnitResources.unitField, isEqualTo: learningUnitDocId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return const LearningUnitResources();
    final doc = snap.docs.first;
    return LearningUnitResources.fromMap(doc.id, doc.data());
  }

  /// This unit's board-and-grade resource documents, keyed by document id.
  ///
  /// KEYED BY ID because that is what a grade-dependent slot stores against a
  /// board: the slot holds `{ CBSE: 's9qKMMiIrTMVaay3Kn14' }` and the paths
  /// live on that document under `grade_01` and friends.
  ///
  /// ONE QUERY FOR THE WHOLE UNIT, not one read per slot. A step can carry
  /// several grade-dependent contents and a workflow several steps; fetching
  /// each by id would be a round trip per tab on school wifi.
  ///
  /// A FAILURE PROPAGATES, as it does from every other read in this class. The
  /// caller degrades it: `LearningUnitProvider._loadGradeDependent` catches,
  /// logs, and leaves the map empty, so a grade-dependent slot falls back to
  /// its universal copy. Swallowing it here would put the one silent catch in
  /// a file that otherwise reports everything.
  ///
  /// An empty result is the NORMAL case, not an error: most units have no
  /// board copies at all.
  Future<Map<String, BoardGradeResource>> fetchBoardGradeResources(
    String learningUnitDocId,
  ) async {
    final snap = await _db
        .collection(BoardGradeResource.collection)
        .where(BoardGradeResource.unitField, isEqualTo: learningUnitDocId)
        .get();
    return {
      for (final doc in snap.docs)
        doc.id: BoardGradeResource.fromMap(doc.id, doc.data()),
    };
  }

  // -- Workflow progress ------------------------------------------------------

  /// `users/{uid}/workflowProgress/{classroomId}-{learningUnitId}`.
  ///
  /// Under `users`, for exactly the reasons given on [_submissionDoc]: it is
  /// the one subtree the web app's deployed rules already grant to its own uid,
  /// so this needs no rules change and no deploy from this repo. See
  /// [WorkflowProgress] for why a teacher's progress is private data rather
  /// than a fact about the classroom.
  DocumentReference<Map<String, dynamic>> _progressDoc({
    required String uid,
    required String classroomId,
    required String learningUnitId,
  }) => _db
      .collection(TeacherProfile.collection)
      .doc(uid)
      .collection(WorkflowProgress.collection)
      .doc(
        WorkflowProgress.documentId(
          classroomId: classroomId,
          learningUnitId: learningUnitId,
        ),
      );

  /// One activity's progress.
  Future<WorkflowProgress> fetchWorkflowProgress({
    required String uid,
    required String classroomId,
    required String learningUnitId,
  }) async {
    final snap = await _progressDoc(
      uid: uid,
      classroomId: classroomId,
      learningUnitId: learningUnitId,
    ).get();
    return WorkflowProgress.fromMap(snap.data());
  }

  /// Every activity's progress for ONE classroom, keyed by learning unit id.
  ///
  /// ONE QUERY, NOT ONE READ PER CARD. The classroom screen shows a status on
  /// every activity it lists, and a read per row would put a classroom running
  /// twelve activities at twelve round trips before it could draw a single
  /// pill.
  ///
  /// Filtered on a `classroomId` FIELD rather than by id prefix, because
  /// Firestore cannot match a substring of a document id. The field is written
  /// on every save for that reason alone, and is redundant with the id by
  /// design.
  Future<Map<String, WorkflowProgress>> fetchClassroomProgress({
    required String uid,
    required String classroomId,
  }) async {
    final snap = await _db
        .collection(TeacherProfile.collection)
        .doc(uid)
        .collection(WorkflowProgress.collection)
        .where('classroomId', isEqualTo: classroomId)
        .get();
    final byUnit = <String, WorkflowProgress>{};
    for (final doc in snap.docs) {
      final data = doc.data();
      // Skipped rather than keyed by the document id. The id is a composite of
      // two ids either of which may contain a hyphen, so it cannot be split
      // back apart; a row without the field is one this build cannot place.
      final id = SafeParse.asDisplayString(data['learningUnitId']);
      if (id == null) continue;
      byUnit[id] = WorkflowProgress.fromMap(data);
    }
    return byUnit;
  }

  /// Marks one step done, or not done.
  ///
  /// MERGED, and only the fields this call owns. A teacher can have the same
  /// activity open on two devices, and a whole-document write from one would
  /// silently drop what the other recorded. `classroomId` and `learningUnitId`
  /// are rewritten every time so a document created by an older build, before
  /// the query above existed, gains them on its first update rather than
  /// staying invisible to the classroom screen forever.
  Future<void> setWorkflowStepDone({
    required String uid,
    required String classroomId,
    required String learningUnitId,
    required Set<String> completedStepIds,
  }) => _progressDoc(
    uid: uid,
    classroomId: classroomId,
    learningUnitId: learningUnitId,
  ).set({
    'teacherId': uid,
    'classroomId': classroomId,
    'learningUnitId': learningUnitId,
    'completedStepIds': completedStepIds.toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
}

/// What a saved attempt reports back to the screen.
class QuizAttemptResult {
  const QuizAttemptResult({
    required this.attemptId,
    required this.attemptNumber,
    required this.studentScore,
    required this.maxScore,
  });

  final String attemptId;
  final int attemptNumber;
  final double studentScore;
  final int maxScore;
}
