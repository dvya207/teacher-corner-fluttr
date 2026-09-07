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
/// `teacher_submissions/{uid}/{classroomId}_{luId}_{millis}_{index}.jpg`
///
/// THE UID IS THE FIRST SEGMENT, AND THAT IS THE WHOLE POINT. Storage rules
/// match on PATHS and have no document to read an owner from, so the only way
/// to express "this teacher's own upload" is to put the uid in a path segment
/// and compare it to `request.auth.uid`. The deployed rule for this prefix is
///
///     match /teacher_submissions/{teacherId}/{fileName} {
///       allow write: if request.auth.uid == teacherId
///                    && request.resource.size <= 3 * 1024 * 1024
///                    && contentType.matches('image/(png|jpeg)');
///     }
///
/// WHY NOT `activityEvidence/...`, WHICH THIS USED TO BE. That prefix is
/// claimed by NO block in the bucket's ruleset, and that ruleset ends "No
/// catch-all. Firebase Storage denies by default", so every upload was refused
/// with `storage/unauthorized`. It had never worked. The bucket is shared and
/// its rules are owned and deployed by the Angular web app in
/// `~/code/teacher-corner`, so the fix is to use a prefix that is ALREADY
/// granted rather than to add one from here. A Storage rules deploy REPLACES
/// the whole bucket ruleset and would take four other apps down with it.
///
/// EVERYTHING ELSE FOLDS INTO THE FILENAME, because `{fileName}` binds exactly
/// ONE segment. A slash anywhere after the uid puts the object at a path no
/// rule claims and it is denied again. That is the same trap the
/// `learningUnits` block hit and documents, where `{fileName}` silently
/// missed every grade-dependent file one level deeper.
///
/// The classroom and the learning unit stay in the name rather than being
/// dropped: the object is otherwise untraceable to the activity it evidences,
/// and the recorded path is all a report has to go on.
String evidenceStoragePath({
  required String classroomId,
  required String learningUnitId,
  required String uid,
  required int millisSinceEpoch,
  required int index,
}) =>
    'teacher_submissions/$uid/'
    '${classroomId}_${learningUnitId}_${millisSinceEpoch}_$index.jpg';
