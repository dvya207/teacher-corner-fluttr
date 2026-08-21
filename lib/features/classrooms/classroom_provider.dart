import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/classroom.dart';
import '../../core/models/classroom_ref.dart';
import '../../core/services/firestore_service.dart';
import 'classroom_list_item.dart';
import 'classroom_search.dart';

enum ClassroomListStatus { loading, loaded, error }

/// Same reasoning as the dashboard: a read that has not answered by now is not
/// going to, and a teacher mid-class needs to be told so.
const Duration kClassroomLoadTimeout = Duration(seconds: 15);

class ClassroomProvider extends ChangeNotifier {
  ClassroomProvider({
    required FirestoreService firestore,
    Duration timeout = kClassroomLoadTimeout,
  })  : _firestore = firestore,
        _timeout = timeout;

  final FirestoreService _firestore;
  final Duration _timeout;

  ClassroomListStatus _status = ClassroomListStatus.loading;
  List<ClassroomListItem> _all = const [];
  String _query = '';
  String? _errorKey;
  String? _uid;
  bool _inFlight = false;
  bool _disposed = false;

  ClassroomListStatus get status => _status;
  String? get errorKey => _errorKey;
  String get query => _query;

  /// Every classroom the teacher has, unfiltered.
  List<ClassroomListItem> get all => _all;

  /// What the list renders. Recomputed on read rather than cached, because the
  /// list is small and a stale cached copy is a worse bug than a cheap filter.
  List<ClassroomListItem> get visible => ClassroomSearch.filter(_all, _query);

  /// The teacher genuinely has no classrooms, as opposed to having some that
  /// the current search hides. Different empty states, different wording.
  bool get isEmpty => _status == ClassroomListStatus.loaded && _all.isEmpty;

  /// The search matched nothing, but there are classrooms to match.
  bool get hasNoMatches =>
      _status == ClassroomListStatus.loaded &&
      _all.isNotEmpty &&
      visible.isEmpty;

  void search(String query) {
    if (query == _query) return;
    _query = query;
    // No refetch: filtering is local, so typing must never touch the network.
    _notify();
  }

  Future<void> load(String uid) async {
    if (_uid == uid && _status != ClassroomListStatus.error) return;
    _uid = uid;
    await _fetch();
  }

  Future<void> retry() async {
    if (_uid == null) return;
    await _fetch();
  }

  Future<void> _fetch() async {
    // Re-entry guard before the first await.
    if (_inFlight) return;
    _inFlight = true;
    _status = ClassroomListStatus.loading;
    _errorKey = null;
    _notify();

    try {
      _all = await _loadItems(_uid!).timeout(_timeout);
      _status = ClassroomListStatus.loaded;
    } on TimeoutException {
      _status = ClassroomListStatus.error;
      _errorKey = 'classrooms.error_offline';
    } catch (e) {
      debugPrint('ClassroomProvider: load failed: $e');
      _status = ClassroomListStatus.error;
      _errorKey = 'classrooms.error_generic';
    } finally {
      _inFlight = false;
      _notify();
    }
  }

  Future<List<ClassroomListItem>> _loadItems(String uid) async {
    final teacher = await _firestore.fetchTeacher(uid);
    final refs = teacher?.classrooms ?? const <ClassroomRef>[];
    if (refs.isEmpty) return const [];

    // The teacher document says which classrooms are ours; the authoritative
    // documents carry the student count the card has to show.
    final full = await _firestore.fetchClassrooms(
      refs.map((r) => r.classroomId),
    );
    final byId = <String, Classroom>{
      for (final classroom in full) classroom.classroomId: classroom,
    };

    return [
      for (final ref in refs)
        ClassroomListItem.merge(ref: ref, full: byId[ref.classroomId]),
    ];
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
