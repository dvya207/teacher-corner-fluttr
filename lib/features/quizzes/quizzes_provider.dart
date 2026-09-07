import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/assignment.dart';
import '../../core/models/classroom.dart';
import '../../core/models/programme.dart';
import '../../core/models/teacher_account.dart';
import '../../core/services/firestore_service.dart';

enum QuizzesStatus { loading, loaded, empty, error }

const Duration kQuizzesTimeout = Duration(seconds: 20);

/// One assignment as a specific classroom and programme set it.
///
/// THE PROGRAMME IS CARRIED ON THE ROW, not looked up again later. A submission
/// is keyed `{classroomId}-{programmeId}`, so the player has to know which
/// programme allotted this assignment — and since the same assignment can be
/// allotted by more than one, that is a property of the row rather than of the
/// assignment.
class AssignmentInClassroom {
  const AssignmentInClassroom({
    required this.assignment,
    required this.programmeId,
  });

  final Assignment assignment;
  final String programmeId;
}

/// One classroom and the assignments set across its programmes.
class ClassroomAssignments {
  const ClassroomAssignments({
    required this.classroom,
    required this.assignments,
  });

  final Classroom classroom;
  final List<AssignmentInClassroom> assignments;

  bool get isEmpty => assignments.isEmpty;

  /// `Airaa Academy` or `Grade 2 · A · ThinkTac` — whatever the card can say
  /// under the classroom's own name.
  String get subtitle {
    final parts = [
      classroom.institutionName?.trim() ?? '',
    ].where((p) => p.isNotEmpty);

    return parts.join(' · ');
  }
}

/// The Quizzes tab: every classroom this teacher has, with its assignments.
///
/// GROUPED BY CLASSROOM BECAUSE THAT IS THE QUESTION BEING ASKED. An assignment
/// is not attached to a classroom directly — the chain is classroom → programmes
/// → `assignmentIds` → `Assignments/{docId}` — so the grouping has to be built
/// here rather than queried. A classroom with nothing set still appears, because
/// "no assignments in this classroom yet" is an answer and a missing row is not.
///
/// ONE READ PER PROGRAMME AND PER ASSIGNMENT, deduplicated. The same assignment
/// can be allotted to several programmes, and the same programme can be attached
/// to several classrooms, so both are fetched once and shared.
class QuizzesProvider extends ChangeNotifier {
  QuizzesProvider({
    required FirestoreService firestore,
    Duration timeout = kQuizzesTimeout,
  }) : _firestore = firestore,
       _timeout = timeout;

  final FirestoreService _firestore;
  final Duration _timeout;

  QuizzesStatus _status = QuizzesStatus.loading;
  List<ClassroomAssignments> _rows = const [];
  String? _errorKey;
  bool _inFlight = false;
  bool _disposed = false;

  QuizzesStatus get status => _status;
  List<ClassroomAssignments> get rows => _rows;
  String? get errorKey => _errorKey;

  /// How many classrooms the Classrooms chip counts.
  int get classroomCount => _rows.length;

  /// Every assignment across every classroom, deduplicated by id.
  int get assignmentCount => _rows
      .expand((row) => row.assignments)
      .map((row) => row.assignment.docId)
      .toSet()
      .length;

  Future<void> load(TeacherAccount account) async {
    if (_inFlight) return;

    _inFlight = true;
    _set(QuizzesStatus.loading);

    try {
      /*
       * THE IDS COME FROM THE TEACHING RECORD'S DENORMALISED SUMMARY, which is
       * what the dashboard and the classroom list also read. It answers "which
       * classrooms are mine" without a query; the authoritative
       * `classrooms/{id}` documents are then read for the programmes on them.
       */
      final refs = account.teaching?.classrooms ?? const [];

      final classrooms = await _firestore
          .fetchClassrooms(refs.map((ref) => ref.classroomId))
          .timeout(_timeout);

      if (classrooms.isEmpty) {
        _rows = const [];
        _set(QuizzesStatus.empty);

        return;
      }

      // Every programme named by any classroom, read once.
      final programmeIds = <String>{
        for (final classroom in classrooms)
          for (final programme in classroom.programmes) programme.programmeId,
      }..removeWhere((id) => id.trim().isEmpty);

      final programmes = <String, Programme>{};

      await Future.wait(
        programmeIds.map((id) async {
          final programme = await _firestore.fetchProgramme(id);
          if (programme != null) programmes[id] = programme;
        }),
      );

      // Every assignment any of those programmes allots, read once. The due date
      // belongs to the PROGRAMME's entry, not to the assignment, so it is carried
      // alongside; where two programmes allot the same assignment the first date
      // seen wins, which is as meaningful as any other choice.
      final dueDates = <String, DateTime?>{};

      for (final programme in programmes.values) {
        programme.assignments.forEach((id, due) {
          dueDates.putIfAbsent(id, () => due);
        });
      }

      final assignments = {
        for (final assignment in await _firestore.fetchAssignments(
          dueDates.keys,
          dueDates: dueDates,
        ))
          assignment.docId: assignment,
      };

      _rows = classrooms.map((classroom) {
        // KEYED BY ASSIGNMENT ID so the same assignment allotted by two of this
        // classroom's programmes appears once. The first programme seen owns the
        // row, the same rule the due date above follows.
        final byId = <String, String>{};

        for (final programme in classroom.programmes) {
          for (final id
              in programmes[programme.programmeId]?.assignmentIds ??
                  const <String>[]) {
            byId.putIfAbsent(id, () => programme.programmeId);
          }
        }

        final rows = <AssignmentInClassroom>[];

        byId.forEach((id, programmeId) {
          final assignment = assignments[id];

          // An id pointing at nothing is DROPPED rather than rendered blank: the
          // assignment was deleted after being allotted, and a row with no title
          // is worse than no row.
          if (assignment == null) return;

          /*
           * QUIZZES ONLY. Uploads and forms are set on a classroom exactly the
           * same way and used to be listed here, greyed out and untappable,
           * because a teacher should arguably see everything set for their
           * class. They are dropped instead: this app can answer neither, so
           * every one of them was a row that could only disappoint, and they
           * pushed the quizzes that ARE answerable further down the card.
           *
           * FILTERED HERE RATHER THAN IN THE SCREEN so the chip count and the
           * "no assignments" empty state agree with what is actually rendered.
           * A classroom whose only assignment is an upload now correctly reads
           * as having nothing, rather than showing a count of one and a list of
           * none.
           */
          if (!assignment.isQuiz) return;

          rows.add(
            AssignmentInClassroom(
              assignment: assignment,
              programmeId: programmeId,
            ),
          );
        });

        // DATED FIRST, SOONEST FIRST, undated last. A due date is the only
        // ordering the data offers, and an assignment without one has not been
        // scheduled — so it belongs after the ones that have been.
        rows.sort((a, b) {
          final left = a.assignment.dueDate;
          final right = b.assignment.dueDate;

          if (left == null && right == null) {
            return a.assignment.displayName.compareTo(b.assignment.displayName);
          }
          if (left == null) return 1;
          if (right == null) return -1;

          return left.compareTo(right);
        });

        return ClassroomAssignments(classroom: classroom, assignments: rows);
      }).toList();

      _set(_rows.isEmpty ? QuizzesStatus.empty : QuizzesStatus.loaded);
    } on TimeoutException {
      _errorKey = 'errors.timeout';
      _set(QuizzesStatus.error);
    } catch (_) {
      _errorKey = 'errors.generic';
      _set(QuizzesStatus.error);
    } finally {
      _inFlight = false;
    }
  }

  void _set(QuizzesStatus status) {
    _status = status;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
