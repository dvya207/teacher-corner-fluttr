import 'dart:async';

import 'package:tc_starter/core/models/assignment_evidence.dart';
import 'package:tc_starter/core/models/classroom.dart';
import 'package:tc_starter/core/models/learning_unit.dart';
import 'package:tc_starter/core/models/teacher.dart';
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
    this.classrooms = const [],
    this.learningUnits = const [],
    this.workflows = const [],
    this.throws,
    this.throwsOnClassroom,
    this.throwsOnLearningUnit,
    this.evidence,
    this.throwsOnWriteEvidence,
    this.throwsOnFetchEvidence,
    this.log,
    this.gate,
  });

  final Teacher? teacher;
  final List<Classroom> classrooms;
  final List<LearningUnit> learningUnits;
  final List<Workflow> workflows;

  /// Thrown by [fetchTeacher] when set, to exercise the error state.
  final Object? throws;

  /// Thrown by [fetchClassroom] when set.
  final Object? throwsOnClassroom;

  /// Thrown by [fetchLearningUnit] when set.
  final Object? throwsOnLearningUnit;

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
  int classroomReads = 0;
  int learningUnitReads = 0;
  int workflowReads = 0;
  final List<String> requestedUids = [];

  @override
  Future<Teacher?> fetchTeacher(String uid) async {
    teacherReads++;
    requestedUids.add(uid);
    if (gate != null) await gate!.future;
    if (throws != null) throw throws!;
    return teacher;
  }

  @override
  Future<Classroom?> fetchClassroom(String classroomId) async {
    classroomReads++;
    if (gate != null) await gate!.future;
    if (throwsOnClassroom != null) throw throwsOnClassroom!;
    for (final classroom in classrooms) {
      if (classroom.classroomId == classroomId) return classroom;
    }
    return null;
  }

  @override
  Future<List<Classroom>> fetchClassrooms(Iterable<String> ids) async {
    classroomReads++;
    if (throwsOnClassroom != null) throw throwsOnClassroom!;
    final wanted = ids.toSet();
    return classrooms.where((c) => wanted.contains(c.classroomId)).toList();
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
    this.stubTeacher,
    LoginStage stubStage = LoginStage.phoneEntry,
    this.stubBusy = false,
    this.stubErrorKey,
    this.stubPendingPhone = '',
  }) : _stubStage = stubStage;

  final String? stubUid;
  final Teacher? stubTeacher;
  final LoginStage _stubStage;
  final bool stubBusy;
  final String? stubErrorKey;
  final String stubPendingPhone;

  @override
  String? get uid => stubUid;

  @override
  bool get isAuthenticated => stubUid != null;

  @override
  bool get authLoaded => true;

  @override
  Teacher? get teacher => stubTeacher;

  @override
  LoginStage get stage => _stubStage;

  @override
  bool get isBusy => stubBusy;

  @override
  String? get errorKey => stubErrorKey;

  @override
  String get pendingPhoneNumber => stubPendingPhone;
}