import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/classroom.dart';
import '../../core/models/learning_unit.dart';
import '../../core/models/workflow_progress.dart';
import '../../core/services/firestore_service.dart';

enum ClassroomDetailStatus { loading, loaded, notFound, error }

const Duration kClassroomDetailTimeout = Duration(seconds: 15);

/// One programme on this classroom, paired with the learning units it runs
/// here and the workflow each of those uses IN THIS CLASSROOM.
class ProgrammeActivities {
  const ProgrammeActivities({
    required this.programme,
    required this.activities,
  });

  final ClassroomProgramme programme;
  final List<Activity> activities;
}

/// A learning unit as this classroom runs it.
///
/// The [workflowId] is not a property of the unit. It comes from the binding on
/// the classroom, which is why it is carried alongside rather than read off
/// [unit]: the same unit in another classroom resolves to a different workflow.
class Activity {
  const Activity({
    required this.learningUnitId,
    required this.workflowId,
    this.unit,
    this.progress = const WorkflowProgress(),
  });

  final String learningUnitId;
  final String workflowId;

  /// Null when the classroom references a unit whose document is missing.
  final LearningUnit? unit;

  /// This teacher's progress through the activity IN THIS CLASSROOM. Defaults
  /// to nothing done, which is also what an unreadable progress collection
  /// leaves every card showing.
  final WorkflowProgress progress;

  String get label => unit?.label ?? learningUnitId;

  /// Derived from the unit's own `stepCount` rather than from the workflow,
  /// which this screen deliberately does not read. See
  /// [WorkflowProgress.statusForCount].
  ActivityProgressStatus get status =>
      progress.statusForCount(unit?.stepCount);
}

class ClassroomDetailProvider extends ChangeNotifier {
  ClassroomDetailProvider({
    required FirestoreService firestore,
    Duration timeout = kClassroomDetailTimeout,
  })  : _firestore = firestore,
        _timeout = timeout;

  final FirestoreService _firestore;
  final Duration _timeout;

  ClassroomDetailStatus _status = ClassroomDetailStatus.loading;
  Classroom? _classroom;
  List<ProgrammeActivities> _programmes = const [];
  String? _errorKey;
  String? _classroomId;

  /// Needed only for the progress read, which is why it is nullable: signed out
  /// there is no progress to show, and the screen still renders the classroom.
  String? _uid;
  bool _inFlight = false;
  bool _disposed = false;

  ClassroomDetailStatus get status => _status;
  Classroom? get classroom => _classroom;
  List<ProgrammeActivities> get programmes => _programmes;
  String? get errorKey => _errorKey;

  /// True when the classroom loaded but runs no programmes at all.
  bool get hasNoProgrammes =>
      _status == ClassroomDetailStatus.loaded && _programmes.isEmpty;

  Future<void> load(String classroomId, {String? uid}) async {
    if (_classroomId == classroomId && _status != ClassroomDetailStatus.error) {
      return;
    }
    _classroomId = classroomId;
    _uid = uid;
    await _fetch();
  }

  Future<void> retry() async {
    if (_classroomId == null) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    if (_inFlight) return;
    _inFlight = true;
    _status = ClassroomDetailStatus.loading;
    _errorKey = null;
    _notify();

    try {
      final loaded = await _load(_classroomId!).timeout(_timeout);
      if (loaded == null) {
        // Referenced by the teacher but the document is gone. A real state, and
        // not an error the teacher can retry their way out of.
        _classroom = null;
        _programmes = const [];
        _status = ClassroomDetailStatus.notFound;
      } else {
        _classroom = loaded.$1;
        _programmes = loaded.$2;
        _status = ClassroomDetailStatus.loaded;
      }
    } on TimeoutException {
      _status = ClassroomDetailStatus.error;
      _errorKey = 'classroom.error_offline';
    } catch (e) {
      debugPrint('ClassroomDetailProvider: load failed: $e');
      _status = ClassroomDetailStatus.error;
      _errorKey = 'classroom.error_generic';
    } finally {
      _inFlight = false;
      _notify();
    }
  }

  Future<(Classroom, List<ProgrammeActivities>)?> _load(
    String classroomId,
  ) async {
    final classroom = await _firestore.fetchClassroom(classroomId);
    if (classroom == null) return null;

    // One read per distinct unit across every programme, rather than per
    // binding: the same unit can appear in two programmes on one classroom.
    final unitIds = {
      for (final binding in classroom.allWorkflows) binding.learningUnitId,
    };
    final units = await _firestore.fetchLearningUnits(unitIds);
    final byId = {for (final unit in units) unit.learningUnitId: unit};
    final progress = await _loadProgress(classroomId);

    return (
      classroom,
      [
        for (final programme in classroom.programmes)
          ProgrammeActivities(
            programme: programme,
            activities: [
              for (final binding in programme.workflows)
                Activity(
                  learningUnitId: binding.learningUnitId,
                  workflowId: binding.workflowId,
                  unit: byId[binding.learningUnitId],
                  progress:
                      progress[binding.learningUnitId] ??
                      const WorkflowProgress(),
                ),
            ],
          ),
      ],
    );
  }

  /// One query for the whole classroom, and allowed to fail on its own.
  ///
  /// Progress is an ENHANCEMENT to this screen, not its subject. A teacher who
  /// cannot read their own progress should still get their programmes and
  /// activities, with every card reading "Not Started", rather than an error
  /// page in place of a classroom.
  Future<Map<String, WorkflowProgress>> _loadProgress(
    String classroomId,
  ) async {
    final uid = _uid;
    if (uid == null) return const {};
    try {
      return await _firestore.fetchClassroomProgress(
        uid: uid,
        classroomId: classroomId,
      );
    } catch (e) {
      debugPrint('ClassroomDetailProvider: progress unavailable: $e');
      return const {};
    }
  }

  void _notify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
