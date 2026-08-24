import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/classroom_ref.dart';
import '../../core/models/teacher_account.dart';
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
  TeacherAccount? _account;
  List<ClassroomListItem> _classrooms = const [];
  String? _errorKey;
  String? _uid;
  bool _inFlight = false;
  bool _disposed = false;

  DashboardStatus get status => _status;
  TeacherAccount? get account => _account;

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

  /// True once a load has succeeded but no `teachers` record is linked to this
  /// uid.
  ///
  /// Signed in, and no admin has registered this phone number against a
  /// classroom yet. A real state in `teacher-corner-dev`, not an error, and not
  /// something Retry can fix — which is why the screen shows an explanation
  /// rather than an error banner with a button.
  ///
  /// Deliberately NOT "the account is empty". A teacher can have a
  /// `users/{uid}` profile with a name and a school and still have no teaching
  /// record; the header shows what it has and this reports what is missing.
  bool get isTeacherNotLinked =>
      _status == DashboardStatus.loaded && !(_account?.isLinked ?? false);

  /// Loads once per uid. Called from the screen's initState, which fires on
  /// every rebuild of the route, so repeat calls for the same uid are ignored
  /// rather than refetching on every navigation back to the tab.
  ///
  /// A DIFFERENT uid drops the previous teacher's data SYNCHRONOUSLY, before the
  /// first await. Without that, a second teacher signing in on the same device
  /// would see the first one's name, school and classrooms for as long as their
  /// own read took.
  Future<void> load(String uid) async {
    if (_uid == uid && _status != DashboardStatus.error) return;
    if (_uid != uid) _clear();
    _uid = uid;
    await _fetch();
  }

  /// Forgets whoever was loaded. Called on every change of signed-in user,
  /// including sign-out.
  ///
  /// THIS PROVIDER OUTLIVES THE SCREEN. It is created above the router, so it
  /// survives a sign-out and is still holding the previous teacher's data when
  /// the next one arrives. [load] clearing on a uid change is not enough on its
  /// own: the dashboard's first frame renders BEFORE its post-frame callback
  /// calls load, so without this reset that frame shows the wrong teacher.
  void reset() {
    if (_uid == null && _status == DashboardStatus.loading) return;
    _clear();
    _uid = null;
    _notify();
  }

  /// Back to the pre-load state. Loading rather than loaded-and-empty, because
  /// "nothing has been asked for yet" must not render as "this teacher has
  /// nothing".
  void _clear() {
    _account = null;
    _classrooms = const [];
    _errorKey = null;
    _status = DashboardStatus.loading;
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

    // The uid this attempt is for. Compared again after every await, so a slow
    // read for a teacher who has since signed out cannot write their data over
    // the one who signed in after them.
    final requestedUid = _uid!;

    try {
      final account =
          await _firestore.fetchTeacherAccount(requestedUid).timeout(_timeout);
      if (_uid != requestedUid) return;
      _account = account;
      final classrooms = await _loadClassrooms(account);
      if (_uid != requestedUid) return;
      _classrooms = classrooms;
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
  Future<List<ClassroomListItem>> _loadClassrooms(
    TeacherAccount? account,
  ) async {
    final refs = account?.classrooms ?? const <ClassroomRef>[];
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
