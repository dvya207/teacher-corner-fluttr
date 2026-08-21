import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// Uploads and deletes evidence objects.
///
/// Narrow and injectable so the submit contract can be tested without touching
/// a bucket: the ordering rules around these two calls are the whole risk in
/// Phase 5.
abstract class EvidenceStorage {
  /// Uploads [file] to [storagePath] and returns a download URL.
  Future<String> upload({
    required String storagePath,
    required File file,
    String contentType,
  });

  /// Removes the object at [storagePath].
  Future<void> delete(String storagePath);
}

class FirebaseEvidenceStorage implements EvidenceStorage {
  FirebaseEvidenceStorage({FirebaseStorage? storage}) : _injected = storage;

  final FirebaseStorage? _injected;

  /// Lazy, so constructing this never requires an initialised Firebase.
  late final FirebaseStorage _storage = _injected ?? FirebaseStorage.instance;

  @override
  Future<String> upload({
    required String storagePath,
    required File file,
    String contentType = 'image/jpeg',
  }) async {
    final ref = _storage.ref(storagePath);
    await ref.putFile(file, SettableMetadata(contentType: contentType));
    return ref.getDownloadURL();
  }

  @override
  Future<void> delete(String storagePath) => _storage.ref(storagePath).delete();
}

/// Builds the evidence object path.
///
/// `activityEvidence/{classroomId}/{luId}/{uid}_{millis}_{index}.jpg`
///
/// The uid is in the path on purpose: it is what makes a submission
/// attributable. Leave it out and the image is evidence nobody can trace to a
/// teacher.
String evidenceStoragePath({
  required String classroomId,
  required String learningUnitId,
  required String uid,
  required int millisSinceEpoch,
  required int index,
}) =>
    'activityEvidence/$classroomId/$learningUnitId/'
    '${uid}_${millisSinceEpoch}_$index.jpg';
