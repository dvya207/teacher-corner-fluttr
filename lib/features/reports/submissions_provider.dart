import 'package:flutter/foundation.dart';

import '../../core/models/assignment.dart';
import '../../core/models/classroom.dart';
import '../../core/models/classroom_ref.dart';
import '../../core/models/submission_report.dart';
import '../../core/models/workflow.dart';
import '../../core/services/firestore_service.dart';

enum SubmissionsStatus { loading, loaded, error, empty }

/// One classroom as the Submissions list shows it.
class ClassroomSubmissions {
  const ClassroomSubmissions({
    required this.classroom,
    required this.programmeCount,
    required this.activityCount,
  });

  final Classroom classroom;

  /// How many programmes this classroom runs, and how many activities across
  /// all of them. BOTH COUNTED FROM THE CLASSROOM'S OWN BINDINGS rather than
  /// from the programme documents: a programme lists every unit it contains,
  /// while the classroom lists the ones actually bound to a workflow here, and
  /// only the second is a thing a teacher could have submitted against.
  final int programmeCount;
  final int activityCount;
}

/// The teacher's classrooms, for the first level of the Submissions report.
///
/// THE SIGNED-IN TEACHER'S OWN RECORD AND NOBODY ELSE'S, which is a limit of
/// the data rather than a choice. This app writes submissions under
/// `users/{uid}/`, and the deployed rule grants that subtree to that uid
/// alone:
///
///     match /users/{uid}/{document=**} {
///       allow read, write: if signedIn() && request.auth.uid == uid;
///     }
///
/// The production app can list several teachers per activity because it keeps
/// submissions in a top-level `Submissions` collection, which this database
/// does not have. Showing other teachers here would need that collection and a
/// rules deploy from the web app's repo, so the report is built for one teacher
/// and says so on screen rather than showing rows it cannot fill.
class SubmissionsProvider extends ChangeNotifier {
  SubmissionsProvider({
    required FirestoreService firestore,
    required this.uid,
    this.phoneNumber,
  }) : _firestore = firestore;

  final FirestoreService _firestore;
  final String? uid;

  /// Passed through to [FirestoreService.fetchTeacher] for the same reason the
  /// classroom list passes it: the teacher document is not keyed by uid, and
  /// the phone number is the fallback that finds it.
  final String? phoneNumber;

  static const Duration _timeout = Duration(seconds: 12);

  SubmissionsStatus _status = SubmissionsStatus.loading;
  SubmissionsStatus get status => _status;

  String? _errorKey;
  String? get errorKey => _errorKey;

  List<ClassroomSubmissions> _classrooms = const [];
  List<ClassroomSubmissions> get classrooms => _classrooms;

  bool _inFlight = false;

  Future<void> load() async {
    if (_inFlight) return;
    _inFlight = true;
    _status = SubmissionsStatus.loading;
    _errorKey = null;
    notifyListeners();

    try {
      final id = uid;
      if (id == null || id.isEmpty) {
        _status = SubmissionsStatus.empty;
        return;
      }

      // THE TEACHER DOCUMENT SAYS WHICH CLASSROOMS ARE MINE, exactly as it
      // does for the classroom list. There is no query from a classroom back
      // to its teachers, so the denormalised map is the only route in.
      final teacher = await _firestore
          .fetchTeacher(id, phoneNumber: phoneNumber)
          .timeout(_timeout);
      final ids = (teacher?.classrooms ?? const <ClassroomRef>[])
          .map((r) => r.classroomId)
          .toList();
      if (ids.isEmpty) {
        _classrooms = const [];
        _status = SubmissionsStatus.empty;
        return;
      }

      final classrooms = await _firestore
          .fetchClassrooms(ids)
          .timeout(_timeout);

      _classrooms = [
        for (final classroom in classrooms)
          ClassroomSubmissions(
            classroom: classroom,
            programmeCount: classroom.programmes.length,
            activityCount: classroom.programmes.fold<int>(
              0,
              (sum, p) => sum + p.workflows.length,
            ),
          ),
      ];
      _status = _classrooms.isEmpty
          ? SubmissionsStatus.empty
          : SubmissionsStatus.loaded;
    } catch (e) {
      debugPrint('SubmissionsProvider: load failed: $e');
      _errorKey = 'reports.submissions_error';
      _status = SubmissionsStatus.error;
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }
}

/// Every activity of one programme in one classroom, with what the teacher
/// submitted against each.
///
/// THE WORKFLOW IS THE SOURCE OF WHAT COULD BE SUBMITTED, and the three stored
/// documents are the source of what was. That split is the whole design: a
/// programme's activity that a teacher never opened has no submission document
/// at all, and the only way to list it as "Not submitted" rather than to omit
/// it is to read the workflow that declares its assignments.
class ActivitySubmissionsProvider extends ChangeNotifier {
  ActivitySubmissionsProvider({
    required FirestoreService firestore,
    required this.uid,
    required this.classroomId,
    required this.programmeId,
  }) : _firestore = firestore;

  final FirestoreService _firestore;
  final String? uid;
  final String classroomId;
  final String programmeId;

  static const Duration _timeout = Duration(seconds: 20);

  SubmissionsStatus _status = SubmissionsStatus.loading;
  SubmissionsStatus get status => _status;

  String? _errorKey;
  String? get errorKey => _errorKey;

  List<ActivitySubmissions> _activities = const [];
  List<ActivitySubmissions> get activities => _activities;

  String? _programmeName;
  String? get programmeName => _programmeName;

  bool _inFlight = false;

  Future<void> load() async {
    if (_inFlight) return;
    _inFlight = true;
    _status = SubmissionsStatus.loading;
    _errorKey = null;
    notifyListeners();

    try {
      final id = uid;
      if (id == null || id.isEmpty) {
        _status = SubmissionsStatus.empty;
        return;
      }

      final classroom = await _firestore
          .fetchClassroom(classroomId)
          .timeout(_timeout);
      final programme = classroom?.programmes.firstWhere(
        (p) => p.programmeId == programmeId,
        orElse: () => const ClassroomProgramme(programmeId: ''),
      );
      _programmeName = programme?.label;

      final bindings = programme?.workflows ?? const <WorkflowBinding>[];
      if (bindings.isEmpty) {
        _activities = const [];
        _status = SubmissionsStatus.empty;
        return;
      }

      // THE THREE STORES, FETCHED ONCE EACH for the whole programme rather
      // than per activity. A programme with seven activities would otherwise
      // be seven reads of the same two documents.
      final responsesFuture = _firestore
          .fetchFormResponsesForClassroom(uid: id, classroomId: classroomId)
          .timeout(_timeout);
      final recordFuture = _firestore
          .fetchSubmissionRecord(
            uid: id,
            classroomId: classroomId,
            programmeId: programmeId,
          )
          .timeout(_timeout);

      final responses = await responsesFuture;
      final record = await recordFuture;

      _activities = await _buildActivities(
        bindings: bindings,
        responses: responses,
        record: record,
      );
      _status = _activities.isEmpty
          ? SubmissionsStatus.empty
          : SubmissionsStatus.loaded;
    } catch (e) {
      debugPrint('ActivitySubmissionsProvider: load failed: $e');
      _errorKey = 'reports.submissions_error';
      _status = SubmissionsStatus.error;
    } finally {
      _inFlight = false;
      notifyListeners();
    }
  }

  Future<List<ActivitySubmissions>> _buildActivities({
    required List<WorkflowBinding> bindings,
    required Map<String, Map<String, dynamic>> responses,
    required Map<String, dynamic>? record,
  }) async {
    final out = <ActivitySubmissions>[];

    for (final binding in bindings) {
      final unit = await _safe(
        () => _firestore.fetchLearningUnit(binding.learningUnitId),
      );
      final workflow = await _safe(
        () => _firestore.fetchWorkflow(binding.workflowId),
      );

      // Every assignment the workflow declares, in step order. That order is
      // what the detail sheet renders in, so a teacher reads their record in
      // the sequence they lived it.
      final assignmentIds = <String>[];
      final contents = <WorkflowContent>[];
      for (final step in workflow?.steps ?? const <WorkflowStep>[]) {
        for (final content in step.contents) {
          if (!content.isAssignment) continue;
          final assignmentId = content.assignmentId?.trim();
          if (assignmentId == null || assignmentId.isEmpty) continue;
          assignmentIds.add(assignmentId);
          contents.add(content);
        }
      }

      final assignments = assignmentIds.isEmpty
          ? const <String, Assignment>{}
          : {
              for (final a in await _safe(
                    () => _firestore.fetchAssignments(assignmentIds),
                  ) ??
                  const <Assignment>[])
                a.docId: a,
            };

      final blocks = <SubmissionBlock>[];
      for (final content in contents) {
        final assignmentId = content.assignmentId!.trim();
        final assignment = assignments[assignmentId];

        if (content.isFormAssignment) {
          final block = SubmissionParser.formBlock(
            assignment: assignment,
            response: responses[assignmentId],
          );
          if (block != null) blocks.add(block);
        } else if (content.isUploadAssignment) {
          final entry = record?[assignmentId];
          final block = SubmissionParser.uploadBlock(
            assignment: assignment,
            entry: entry is Map
                ? entry.map((k, v) => MapEntry('$k', v))
                : null,
          );
          if (block != null) blocks.add(block);
        } else if (content.isQuizAssignment) {
          // THE QUIZ RECORD IS THE DOCUMENT'S OWN TOP LEVEL, so it is only
          // this activity's quiz when the document names this assignment.
          // Without that check every activity of the programme would report
          // the same score.
          final belongs = record?['assignmentId'] == assignmentId;
          final block = SubmissionParser.quizBlock(
            assignment: assignment,
            record: belongs ? record : null,
          );
          if (block != null) blocks.add(block);
        }
      }

      out.add(
        ActivitySubmissions(
          learningUnitId: binding.learningUnitId,
          unit: unit,
          blocks: blocks,
        ),
      );
    }

    return out;
  }

  /// One activity's reads must not take the screen down.
  ///
  /// A DELETED UNIT OR AN UNREADABLE WORKFLOW IS ONE ROW, not the report. The
  /// row still lists, named by its id, because a submission against a deleted
  /// activity is still a record of work the teacher did.
  Future<T?> _safe<T>(Future<T?> Function() read) async {
    try {
      return await read().timeout(_timeout);
    } catch (e) {
      debugPrint('ActivitySubmissionsProvider: a read failed: $e');
      return null;
    }
  }
}
