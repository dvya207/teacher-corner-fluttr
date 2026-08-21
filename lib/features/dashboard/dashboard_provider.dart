import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/teacher.dart';
import '../../core/services/firestore_service.dart';

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
  String? _errorKey;
  String? _uid;
  bool _inFlight = false;
  bool _disposed = false;

  DashboardStatus get status => _status;
  Teacher? get teacher => _teacher;

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
      _teacher = await _firestore.fetchTeacher(_uid!).timeout(_timeout);
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
