import 'dart:async';

import 'package:tc_starter/core/models/assignment_evidence.dart';
import 'package:tc_starter/core/models/assignment.dart';
import 'package:tc_starter/core/models/quiz_scoring.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/programme.dart';
import 'package:tc_starter/core/models/teacher.dart';
import 'package:tc_starter/core/models/teacher_account.dart';
import 'package:tc_starter/core/models/teacher_profile.dart';
import 'package:tc_starter/core/models/workflow.dart';
import 'package:tc_starter/core/services/firestore_service.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';

/// Stands in for every read the app makes.
///
/// Extends the real [FirestoreService] rather than implementing an interface,
/// which works because the real one resolves its Firestore handle lazily: none
/// of these overrides ever touch it, so constructing this never needs Firebase.
class FakeFirestoreService extends FirestoreService {
  FakeFirestoreService({
    this.teacher,
    this.profile,
    this.teachersByUid,
    this.teachersByPhone,
    this.profilesByUid,
    this.classroomsByUid,
    this.classrooms = const [],
    this.learningUnits = const [],
    this.programmes = const [],
    this.assignments = const [],
    this.attemptsAlreadyUsed = 0,
    this.throwsOnSaveAttempt,
    this.workflows = const [],
    this.throws,
    this.throwsOnClassroom,
    this.throwsOnLearningUnit,
    this.throwsOnProgramme,
    this.evidence,
    this.throwsOnWriteEvidence,
    this.throwsOnFetchEvidence,
    this.log,
    this.gate,
  });

  /// The linked `teachers/{docId}` record, or null for the UNLINKED state.
  final Teacher? teacher;

  /// The `users/{uid}` document, or null when the teacher has never signed into
  /// the web app. Independent of [teacher] on purpose: the four combinations of
  /// present/absent are all real states and the tests exercise them.
  final TeacherProfile? profile;

  /// `Assignments/{docId}` rows this fake can serve, matched by doc id.
  final List<Assignment> assignments;

  /// How many attempts the summary already records, so the cap can be exercised
  /// without a real transaction.
  final int attemptsAlreadyUsed;

  /// Raised instead of writing, for the transient-failure path.
  final Object? throwsOnSaveAttempt;

  /// Every attempt this fake was asked to save.
  final List<Map<String, Object?>> savedAttempts = [];

  /// Per-uid teaching records. When set, this WINS over [teacher] and an
  /// unlisted uid resolves to null rather than to somebody else's record.
  ///
  /// The point of the whole map: a test can hand two different uids two
  /// different teachers and assert that each gets only their own. A single
  /// [teacher] field cannot express "this uid gets nothing", which is the case
  /// most likely to regress into showing the previous teacher's data.
  final Map<String, Teacher>? teachersByUid;

  /// Teaching records keyed by SUBSCRIBER DIGITS, for the phone fallback: a
  /// record an admin registered that no web sign-in has stamped a uid onto.
  final Map<String, Teacher>? teachersByPhone;

  /// Per-uid `users/{uid}` documents. Same precedence rule as [teachersByUid].
  final Map<String, TeacherProfile>? profilesByUid;

  /// Per-uid classroom documents, so two teachers' classroom reads cannot be
  /// satisfied from one shared list.
  final Map<String, List<Classroom>>? classroomsByUid;

  final List<Classroom> classrooms;
  final List<LearningUnit> learningUnits;

  /// The `programmes/{id}` catalogue documents this fake knows about. An id that
  /// is not in here resolves to null, which is the "referenced but absent" state
  /// the detail screen renders as not-found.
  final List<Programme> programmes;
  final List<Workflow> workflows;

  /// Thrown by [fetchTeacher] when set, to exercise the error state.
  final Object? throws;

  /// Thrown by [fetchClassroom] when set.
  final Object? throwsOnClassroom;

  /// Thrown by [fetchLearningUnit] when set.
  final Object? throwsOnLearningUnit;

  /// Thrown by [fetchProgramme] when set, to exercise the error state.
  final Object? throwsOnProgramme;

  /// The evidence already recorded, if any.
  AssignmentEvidence? evidence;

  final Object? throwsOnWriteEvidence;
  final Object? throwsOnFetchEvidence;

  /// Shared ordered log, so a test can assert that the Firestore write happened
  /// BEFORE the Storage delete.
  final List<String>? log;

  final List<AssignmentEvidence> writes = [];

  /// When set, [fetchTeacher] does not complete until the test completes this.
  /// Used for the timeout path and the re-entry guard.
  final Completer<void>? gate;

  int teacherReads = 0;
  int profileReads = 0;
  int classroomReads = 0;
  int learningUnitReads = 0;
  int programmeReads = 0;
  final List<String> requestedProgrammeIds = [];
  int workflowReads = 0;
  final List<String> requestedUids = [];
  final List<String?> requestedPhoneNumbers = [];
  final List<String> requestedProfileUids = [];

  @override
  Future<Teacher?> fetchTeacher(String uid, {String? phoneNumber}) async {
    teacherReads++;
    requestedUids.add(uid);
    requestedPhoneNumbers.add(phoneNumber);
    if (gate != null) await gate!.future;
    if (throws != null) throw throws!;
    // An unlisted uid gets NULL, never a fallback to `teacher`. A fake that fell
    // back would hide exactly the bug these tests exist to catch.
    if (teachersByUid != null) {
      final byUid = teachersByUid![uid];
      if (byUid != null) return byUid;
      // Mirrors the real fallback: match unlinked records on the subscriber
      // digits, and never one already stamped with somebody else's uid.
      final digits = Teacher.subscriberDigits(phoneNumber);
      if (digits == null) return null;
      for (final candidate in (teachersByPhone ?? const {}).entries) {
        if (candidate.key != digits) continue;
        final stamped = candidate.value.uid;
        if (stamped == null || stamped.isEmpty || stamped == uid) {
          return candidate.value;
        }
      }
      return null;
    }
    return teacher;
  }

  @override
  Future<TeacherProfile?> fetchTeacherProfile(String uid) async {
    profileReads++;
    requestedProfileUids.add(uid);
    if (gate != null) await gate!.future;
    if (throws != null) throw throws!;
    if (profilesByUid != null) return profilesByUid![uid];
    return profile;
  }

  /// NOT overridden: the real implementation composes the two reads above, so
  /// letting it run is what keeps the fake honest about the join. Overriding it
  /// would let a test pass while `fetchTeacherAccount` was wired up wrongly.

  @override
  Future<Classroom?> fetchClassroom(String classroomId) async {
    classroomReads++;
    if (gate != null) await gate!.future;
    if (throwsOnClassroom != null) throw throwsOnClassroom!;
    // Keyed by classroom id, as the real one is. When [classroomsByUid] is set,
    // every uid's documents are searched — because the REAL Firestore rules let
    // any signed-in teacher read any classroom document, so a fake that hid them
    // per uid would be testing an isolation the database does not provide. What
    // must be isolated is WHICH IDS a teacher is told about, and that comes from
    // their own teaching record.
    for (final classroom in [
      ...classrooms,
      ...?classroomsByUid?.values.expand((list) => list),
    ]) {
      if (classroom.classroomId == classroomId) return classroom;
    }
    return null;
  }

  @override
  Future<List<Classroom>> fetchClassrooms(Iterable<String> ids) async {
    classroomReads++;
    if (throwsOnClassroom != null) throw throwsOnClassroom!;
    final wanted = ids.toSet();
    // Searches [classroomsByUid] as well as [classrooms]. Overriding this at all
    // is what made it possible to forget that: the real implementation just maps
    // over fetchClassroom, so a fake that overrides only the singular one stays
    // consistent for free while this one silently returned nothing.
    return [
      ...classrooms,
      ...?classroomsByUid?.values.expand((list) => list),
    ].where((c) => wanted.contains(c.classroomId)).toList();
  }

  @override
  Future<Programme?> fetchProgramme(String programmeId) async {
    programmeReads++;
    requestedProgrammeIds.add(programmeId);
    if (gate != null) await gate!.future;
    if (throwsOnProgramme != null) throw throwsOnProgramme!;
    for (final programme in programmes) {
      if (programme.programmeId == programmeId) return programme;
    }
    return null;
  }

  @override
  Future<List<Assignment>> fetchAssignments(
    Iterable<String> assignmentIds, {
    Map<String, DateTime?> dueDates = const {},
  }) async {
    final wanted = assignmentIds.toSet();

    return assignments
        .where((a) => wanted.contains(a.docId))
        .map(
          (a) => Assignment.fromMap(a.docId, {
            'displayName': a.displayName,
            'type': a.type,
            'status': a.status,
            'numberOfAllowedSubmissions': a.allowedSubmissions,
          }, dueDate: dueDates[a.docId]),
        )
        .toList();
  }

  @override
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
    if (throwsOnSaveAttempt != null) throw throwsOnSaveAttempt!;

    // The cap check the real transaction performs, so a test can reach the
    // sentinel without standing in for Firestore.
    if (attemptsAlreadyUsed >= assignment.allowedSubmissions) {
      throw Exception(FirestoreService.maxAttemptsReached);
    }

    final marks = attemptMarks(assignment.questions, answers);

    savedAttempts.add({
      'teacherDocId': teacherDocId,
      'uid': uid,
      'classroomId': classroomId,
      'programmeId': programmeId,
      'assignmentId': assignment.docId,
      'studentScore': marks.studentScore,
      'maxScore': marks.maxScore,
    });

    return QuizAttemptResult(
      attemptId: 'attempt${attemptsAlreadyUsed + 1}',
      attemptNumber: attemptsAlreadyUsed + 1,
      studentScore: marks.studentScore,
      maxScore: marks.maxScore,
    );
  }

  @override
  Future<LearningUnit?> fetchLearningUnit(String learningUnitId) async {
    learningUnitReads++;
    if (gate != null) await gate!.future;
    if (throwsOnLearningUnit != null) throw throwsOnLearningUnit!;
    for (final unit in learningUnits) {
      if (unit.learningUnitId == learningUnitId) return unit;
    }
    return null;
  }

  @override
  Future<Workflow?> fetchWorkflow(String workflowId) async {
    workflowReads++;
    for (final workflow in workflows) {
      if (workflow.workflowId == workflowId) return workflow;
    }
    return null;
  }

  @override
  Future<AssignmentEvidence?> fetchEvidence({
    required String uid,
    required String classroomId,
    required String programmeId,
    required String assignmentId,
  }) async {
    log?.add('fetchEvidence');
    if (gate != null) await gate!.future;
    if (throwsOnFetchEvidence != null) throw throwsOnFetchEvidence!;
    return evidence;
  }

  @override
  Future<void> writeEvidence({
    required String uid,
    required String classroomId,
    required String programmeId,
    required AssignmentEvidence evidence,
  }) async {
    log?.add('writeEvidence');
    if (throwsOnWriteEvidence != null) throw throwsOnWriteEvidence!;
    writes.add(evidence);
    this.evidence = evidence;
  }
}

/// Reports a session without a Firebase one behind it.
///
/// Every field the screens read is overridable, so a test can pose the login
/// form mid-flow (awaiting a code, showing an error, busy) without driving it
/// through a real verification it cannot perform.
class StubAuthProvider extends AuthProvider {
  StubAuthProvider({
    this.stubUid = 'uid_1',
    this.stubPhoneNumber,
    this.stubAccount,
    LoginStage stubStage = LoginStage.phoneEntry,
    this.stubBusy = false,
    this.stubErrorKey,
    this.stubPendingPhone = '',
  }) : _stubStage = stubStage;

  final String? stubUid;
  final String? stubPhoneNumber;
  final TeacherAccount? stubAccount;
  final LoginStage _stubStage;
  final bool stubBusy;
  final String? stubErrorKey;
  final String stubPendingPhone;

  @override
  String? get uid => stubUid;

  @override
  String? get phoneNumber => stubPhoneNumber;

  @override
  bool get isAuthenticated => stubUid != null;

  @override
  bool get authLoaded => true;

  @override
  TeacherAccount? get account => stubAccount;

  @override
  bool get isTeacherLinked => stubAccount?.isLinked ?? false;

  @override
  LoginStage get stage => _stubStage;

  @override
  bool get isBusy => stubBusy;

  @override
  String? get errorKey => stubErrorKey;

  @override
  String get pendingPhoneNumber => stubPendingPhone;
}
