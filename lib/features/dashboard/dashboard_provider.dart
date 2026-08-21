import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/classroom_ref.dart';
import '../../core/models/teacher.dart';
import '../../core/services/firestore_service.dart';
import '../classrooms/classroom_list_item.dart';

/// The three states the dashboard can be in. Explicitly three, because
/// "loaded with nothing" and "still loading" and "failed" have to look
/// different on screen: a teacher who cannot tell them apart is a teacher
/// staring at a spinner wondering whether to wait.
enum DashboardStatus { loading, loaded, error }

/// A load that has not answered by now is not going to. Firestore with no
/// network and no cached copy can sit unresolved for a long time, and PLAN.md is
/// blunt about it: a spinner that never resolves is worse than an error message.
const Duration kDashboardLoadTimeout = Duration(seconds: 15);

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required FirestoreService firestore,
    Duration timeout = kDashboardLoadTimeout,
  }) : _firestore = firestore,
       _timeout = timeout;

  final FirestoreService _firestore;

  /// Injectable so a test can exercise the timeout path without waiting the
  /// real fifteen seconds for it.
  final Duration _timeout;

  DashboardStatus _status = DashboardStatus.loading;
  Teacher? _teacher;
  List<ClassroomListItem> _classrooms = const [];
  String? _errorKey;
  String? _uid;
  bool _inFlight = false;
  bool _disposed = false;

  DashboardStatus get status => _status;
  Teacher? get teacher => _teacher;

  /// The teacher's classrooms, merged with whichever authoritative documents
  /// were readable. Built from the summary alone when that second round of
  /// reads failed, which is why a row's student count can be null.
  List<ClassroomListItem> get classrooms => _classrooms;

  /// Total students across the teacher's classrooms, or null when the number is
  /// not knowable.
  ///
  /// Null rather than a partial sum: `studentCounter` lives only on the
  /// authoritative `Classrooms` documents, so if even one did not load, a total
  /// would understate the real figure while looking exact. No classrooms at all
  /// is a different case, where zero students is a fact and not a guess.
  int? get studentTotal {
    if (_classrooms.isEmpty) return 0;
    var total = 0;
    for (final classroom in _classrooms) {
      final count = classroom.studentCounter;
      if (count == null) return null;
      total += count;
    }
    return total;
  }

  /// Localisation key, not a sentence. Same reasoning as AuthProvider.
  String? get errorKey => _errorKey;

  /// True once a load has succeeded but the teacher has no document. Signed in,
  /// nothing provisioned: a real state on a freshly seeded database, and not an
  /// error the teacher can do anything about by retrying.
  bool get hasNoProfile =>
      _status == DashboardStatus.loaded && _teacher == null;

  /// Loads once per uid. Called from the screen's initState, which fires on
  /// every rebuild of the route, so repeat calls for the same uid are ignored
  /// rather than refetching on every navigation back to the tab.
  Future<void> load(String uid) async {
    if (_uid == uid && _status != DashboardStatus.error) return;
    _uid = uid;
    await _fetch();
  }

  /// What the Retry button calls. Unlike [load] this always refetches, because
  /// the teacher pressing Retry is explicitly asking for another attempt.
  Future<void> retry() async {
    if (_uid == null) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    // Re-entry guard, read and set before the first await: Retry is a button a
    // frustrated teacher taps repeatedly, and each tap must not start its own
    // request racing the others to write _teacher.
    if (_inFlight) return;
    _inFlight = true;
    _status = DashboardStatus.loading;
    _errorKey = null;
    _notify();

    try {
      final teacher = await _firestore.fetchTeacher(_uid!).timeout(_timeout);
      _teacher = teacher;
      _classrooms = await _loadClassrooms(teacher);
      _status = DashboardStatus.loaded;
    } on TimeoutException {
      _status = DashboardStatus.error;
      _errorKey = 'dashboard.error_offline';
    } catch (e) {
      debugPrint('DashboardProvider: load failed: $e');
      _status = DashboardStatus.error;
      _errorKey = 'dashboard.error_generic';
    } finally {
      _inFlight = false;
      _notify();
    }
  }

  /// The second round of reads: the authoritative classroom documents, which
  /// are the only place `studentCounter` exists.
  ///
  /// Deliberately allowed to fail on its own. The dashboard's job is the
  /// teacher's name, institution and counts, and all of that is already in hand
  /// by this point. A failure here costs the student total and the per-row
  /// counts; it must not cost the screen.
  Future<List<ClassroomListItem>> _loadClassrooms(Teacher? teacher) async {
    final refs = teacher?.classrooms ?? const <ClassroomRef>[];
    if (refs.isEmpty) return const [];
    try {
      final full = await _firestore
          .fetchClassrooms(refs.map((r) => r.classroomId))
          .timeout(_timeout);
      return ClassroomListItem.mergeAll(refs: refs, full: full);
    } catch (e) {
      debugPrint('DashboardProvider: classroom details unavailable: $e');
      return ClassroomListItem.mergeAll(refs: refs, full: const []);
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
