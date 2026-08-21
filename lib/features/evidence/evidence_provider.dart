import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/models/assignment_evidence.dart';
import '../../core/services/evidence_storage.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/photo_picker.dart';

enum EvidenceStatus { loading, ready, error }

/// Hard caps, stated to the teacher before they hit them.
const int kMaxEvidencePhotos = 3;
const int kMaxEvidenceBytes = 3 * 1024 * 1024;
const Duration kEvidenceLoadTimeout = Duration(seconds: 15);

class EvidenceProvider extends ChangeNotifier {
  EvidenceProvider({
    required FirestoreService firestore,
    required EvidenceStorage storage,
    required PhotoPicker picker,
    required this.uid,
    required this.classroomId,
    required this.programmeId,
    required this.learningUnitId,
    required this.assignmentId,
    this.displayName,
    int Function()? clock,
    Duration timeout = kEvidenceLoadTimeout,
  })  : _firestore = firestore,
        _storage = storage,
        _picker = picker,
        _clock = clock ?? _systemClock,
        _timeout = timeout;

  static int _systemClock() => DateTime.now().millisecondsSinceEpoch;

  final FirestoreService _firestore;
  final EvidenceStorage _storage;
  final PhotoPicker _picker;
  final int Function() _clock;
  final Duration _timeout;

  final String uid;
  final String classroomId;
  final String programmeId;
  final String learningUnitId;
  final String assignmentId;
  final String? displayName;

  EvidenceStatus _status = EvidenceStatus.loading;
  AssignmentEvidence? _record;
  final List<PickedPhoto> _pending = [];
  String? _errorKey;
  List<String> _errorArgs = const [];
  bool _busy = false;
  bool _disposed = false;

  EvidenceStatus get status => _status;

  /// Photos already in Storage and referenced by Firestore.
  List<EvidencePhoto> get submitted => _record?.photos ?? const [];

  /// Photos the teacher has chosen but NOT sent. These exist only on the
  /// device: nothing reaches Storage until [submit].
  List<PickedPhoto> get pending => List.unmodifiable(_pending);

  int get totalCount => submitted.length + _pending.length;

  int get remainingSlots => kMaxEvidencePhotos - totalCount;

  bool get isBusy => _busy;

  bool get canSubmit => _pending.isNotEmpty && !_busy;

  bool get isEmpty => totalCount == 0;

  String? get errorKey => _errorKey;

  /// Arguments for [errorKey], where the message names a number.
  List<String> get errorArgs => _errorArgs;

  Future<void> load() async {
    _status = EvidenceStatus.loading;
    _errorKey = null;
    _notify();
    try {
      _record = await _firestore
          .fetchEvidence(
            uid: uid,
            classroomId: classroomId,
            programmeId: programmeId,
            assignmentId: assignmentId,
          )
          .timeout(_timeout);
      _status = EvidenceStatus.ready;
    } catch (e) {
      debugPrint('EvidenceProvider: load failed: $e');
      // Failing to read the existing record must not stop a teacher adding
      // photos, but it would be dishonest to imply none exist.
      _status = EvidenceStatus.error;
      _errorKey = 'evidence.error_load';
    }
    _notify();
  }

  /// Chooses a photo. Local only.
  Future<void> pick(PhotoSource source) async {
    if (_busy) return;
    _clearError();

    // Checked before opening the camera, so the teacher is not invited to take
    // a photo that is going to be refused.
    if (remainingSlots <= 0) {
      _fail('evidence.error_limit', ['$kMaxEvidencePhotos']);
      return;
    }

    _busy = true;
    _notify();
    try {
      final photo = await _picker.pick(source);
      if (photo == null) return; // cancelled, not an error
      if (photo.sizeBytes > kMaxEvidenceBytes) {
        _fail('evidence.error_too_large', ['${kMaxEvidenceBytes ~/ 1048576}']);
        return;
      }
      _pending.add(photo);
    } catch (e) {
      debugPrint('EvidenceProvider: pick failed: $e');
      _fail('evidence.error_pick_failed', const []);
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Discards a chosen photo. Nothing to clean up: it was never uploaded, which
  /// is the entire reason uploads wait for submit.
  void removePending(int index) {
    if (index < 0 || index >= _pending.length) return;
    _pending.removeAt(index);
    _clearError();
    _notify();
  }

  /// Uploads every pending photo, then records them.
  Future<void> submit() async {
    // Re-entry guard: read AND set before the first await. Without it a double
    // tap uploads every photo twice and the second write clobbers the first.
    if (_busy) return;
    if (_pending.isEmpty) return;
    _busy = true;
    _clearError();
    _notify();

    final batch = List<PickedPhoto>.from(_pending);
    final millis = _clock();
    final uploadedPaths = <String>[];
    final uploadedUrls = <String>[];

    try {
      for (var i = 0; i < batch.length; i++) {
        final path = evidenceStoragePath(
          classroomId: classroomId,
          learningUnitId: learningUnitId,
          uid: uid,
          millisSinceEpoch: millis,
          index: i,
        );
        final url = await _storage.upload(
          storagePath: path,
          file: batch[i].file,
          contentType: 'image/jpeg',
        );
        uploadedPaths.add(path);
        uploadedUrls.add(url);
      }

      final next = _base().copyWith(
        photoUrls: [...submitted.map((p) => p.url), ...uploadedUrls],
        storagePaths: [...submitted.map((p) => p.storagePath), ...uploadedPaths],
      );

      await _firestore.writeEvidence(
        uid: uid,
        classroomId: classroomId,
        programmeId: programmeId,
        evidence: next,
      );

      _record = next;
      _pending.removeWhere(batch.contains);
    } catch (e) {
      debugPrint('EvidenceProvider: submit failed: $e');
      // Whatever reached Storage before the failure is unreferenced. Removing it
      // now is the difference between a retry and a permanent orphan nobody can
      // find. Best effort: a failed cleanup must not mask the original error.
      await _deleteQuietly(uploadedPaths);
      _fail(
        _looksOffline(e) ? 'evidence.error_offline' : 'evidence.error_upload_failed',
        const [],
      );
    } finally {
      _busy = false;
      _notify();
    }
  }

  /// Removes an already-submitted photo.
  ///
  /// Firestore FIRST, then the object. In this order a failure leaves a record
  /// that no longer references a file that still exists, which is recoverable.
  /// The other order leaves a record pointing at a deleted object, which breaks
  /// every render of that submission.
  Future<void> removeSubmitted(int index) async {
    if (_busy) return;
    final photos = submitted;
    if (index < 0 || index >= photos.length) return;

    _busy = true;
    _clearError();
    _notify();

    final removed = photos[index];
    final keptUrls = [
      for (var i = 0; i < photos.length; i++)
        if (i != index) photos[i].url,
    ];
    final keptPaths = [
      for (var i = 0; i < photos.length; i++)
        if (i != index) photos[i].storagePath,
    ];

    try {
      final next = _base().copyWith(
        photoUrls: keptUrls,
        storagePaths: keptPaths,
      );
      await _firestore.writeEvidence(
        uid: uid,
        classroomId: classroomId,
        programmeId: programmeId,
        evidence: next,
      );
      _record = next;

      // The record is already consistent, so a failure here leaves an
      // unreferenced object rather than a broken submission. Logged, not
      // surfaced: there is nothing the teacher can do about it.
      await _deleteQuietly([removed.storagePath]);
    } catch (e) {
      debugPrint('EvidenceProvider: removeSubmitted failed: $e');
      _fail('evidence.error_remove_failed', const []);
    } finally {
      _busy = false;
      _notify();
    }
  }

  AssignmentEvidence _base() =>
      _record ??
      AssignmentEvidence(
        assignmentId: assignmentId,
        displayName: displayName,
        luId: learningUnitId,
        type: 'UPLOAD',
        contentType: 'image/jpeg',
      );

  Future<void> _deleteQuietly(List<String> paths) async {
    for (final path in paths) {
      try {
        await _storage.delete(path);
      } catch (e) {
        debugPrint('EvidenceProvider: orphan cleanup failed for $path: $e');
      }
    }
  }

  static bool _looksOffline(Object error) {
    if (error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('network') ||
        text.contains('unavailable') ||
        text.contains('offline') ||
        text.contains('retry-limit');
  }

  void _fail(String key, List<String> args) {
    _errorKey = key;
    _errorArgs = args;
  }

  void _clearError() {
    _errorKey = null;
    _errorArgs = const [];
  }

  void clearError() {
    if (_errorKey == null) return;
    _clearError();
    _notify();
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
