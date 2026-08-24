import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/programme.dart';
import '../../core/services/firestore_service.dart';

/// The four states a programme load can end in.
///
/// [notFound] is separate from [error] on purpose, and the distinction is the
/// whole reason this is an enum rather than a nullable programme plus a bool: a
/// classroom naming a programme whose catalogue entry is gone is a DATA state
/// that Retry cannot fix, while a refused read or a dropped network is a
/// FAILURE that Retry might. Presenting the first as the second sends a teacher
/// round a loop.
enum ProgrammeDetailStatus { loading, loaded, notFound, error }

const Duration kProgrammeDetailTimeout = Duration(seconds: 15);

/// Loads one `programmes/{id}` document.
///
/// Built per route rather than app-wide, so opening a second programme starts
/// from a clean load instead of briefly showing the previous one's name and
/// description. Same reasoning as [ClassroomDetailProvider].
class ProgrammeDetailProvider extends ChangeNotifier {
  ProgrammeDetailProvider({
    required FirestoreService firestore,
    Duration timeout = kProgrammeDetailTimeout,
  })  : _firestore = firestore,
        _timeout = timeout;

  final FirestoreService _firestore;

  /// Injectable so a test can exercise the timeout path without waiting the
  /// real fifteen seconds.
  final Duration _timeout;

  ProgrammeDetailStatus _status = ProgrammeDetailStatus.loading;
  Programme? _programme;
  String? _errorKey;
  String? _programmeId;
  bool _inFlight = false;
  bool _disposed = false;

  ProgrammeDetailStatus get status => _status;

  /// The loaded programme, or null in every other state.
  Programme? get programme => _programme;

  /// Localisation KEY, never a sentence: this class has no BuildContext and the
  /// same failure has to read correctly in every shipped locale.
  String? get errorKey => _errorKey;

  /// Loads once per programme id. The screen calls this from a post-frame
  /// callback, which fires on every rebuild of the route, so a repeat call for
  /// the same id is ignored rather than refetching on every navigation.
  Future<void> load(String programmeId) async {
    if (_programmeId == programmeId && _status != ProgrammeDetailStatus.error) {
      return;
    }
    // A different id drops the previous programme synchronously, before the
    // first await, so no frame can show one programme's details under another's
    // heading.
    if (_programmeId != programmeId) {
      _programme = null;
      _errorKey = null;
      _status = ProgrammeDetailStatus.loading;
    }
    _programmeId = programmeId;
    await _fetch();
  }

  /// What the Retry button calls. Unlike [load] this always refetches, because
  /// a teacher pressing Retry is explicitly asking for another attempt.
  Future<void> retry() async {
    if (_programmeId == null) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    // Re-entry guard, read and set before the first await: Retry is a button a
    // frustrated teacher taps repeatedly, and each tap must not start its own
    // request racing the others to write _programme.
    if (_inFlight) return;
    _inFlight = true;
    _status = ProgrammeDetailStatus.loading;
    _errorKey = null;
    _notify();

    final requestedId = _programmeId!;

    try {
      final programme =
          await _firestore.fetchProgramme(requestedId).timeout(_timeout);
      // Discarded if the route moved on to another programme while this was in
      // flight.
      if (_programmeId != requestedId) return;

      if (programme == null) {
        _programme = null;
        _status = ProgrammeDetailStatus.notFound;
      } else {
        _programme = programme;
        _status = ProgrammeDetailStatus.loaded;
      }
    } on TimeoutException {
      _status = ProgrammeDetailStatus.error;
      _errorKey = 'programme.error_offline';
    } catch (e) {
      debugPrint('ProgrammeDetailProvider: load failed: $e');
      _status = ProgrammeDetailStatus.error;
      _errorKey = 'programme.error_generic';
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
