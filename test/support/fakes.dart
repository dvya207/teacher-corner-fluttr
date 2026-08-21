import 'dart:async';

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
    this.gate,
  });

  final Teacher? teacher;
  final List<Classroom> classrooms;
  final List<LearningUnit> learningUnits;
  final List<Workflow> workflows;

  /// Thrown by [fetchTeacher] when set, to exercise the error state.
  final Object? throws;

  /// When set, [fetchTeacher] does not complete until the test completes this.
  /// Used for the timeout path and the re-entry guard.
  final Completer<void>? gate;

  int teacherReads = 0;
  int classroomReads = 0;
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
    for (final classroom in classrooms) {
      if (classroom.classroomId == classroomId) return classroom;
    }
    return null;
  }

  @override
  Future<List<Classroom>> fetchClassrooms(Iterable<String> ids) async {
    classroomReads++;
    final wanted = ids.toSet();
    return classrooms.where((c) => wanted.contains(c.classroomId)).toList();
  }

  @override
  Future<LearningUnit?> fetchLearningUnit(String learningUnitId) async {
    for (final unit in learningUnits) {
      if (unit.learningUnitId == learningUnitId) return unit;
    }
    return null;
  }

  @override
  Future<Workflow?> fetchWorkflow(String workflowId) async {
    for (final workflow in workflows) {
      if (workflow.workflowId == workflowId) return workflow;
    }
    return null;
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
