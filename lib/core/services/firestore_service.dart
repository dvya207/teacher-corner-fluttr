import 'package:cloud_firestore/cloud_firestore.dart';

import '../firebase/firestore_ref.dart';
import '../models/teacher.dart';

/// Every Firestore read in the app goes through this class. No screen and no
/// provider touches `cloud_firestore` directly.
///
/// It is a class rather than a pile of static helpers for two reasons: the
/// [FirebaseFirestore] handle is injected, so a widget test can hand it a fake
/// without a live project, and the collection-name string literals live in
/// exactly one file.
///
/// The default handle is [db] from `firestore_ref.dart`, never
/// `FirebaseFirestore.instance` — that constant always resolves to `(default)`,
/// which is not this app's database and fails silently rather than loudly.
class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore}) : _db = firestore ?? db;

  final FirebaseFirestore _db;

  /// The signed-in teacher's profile, or null when no document exists.
  ///
  /// A missing document is a legitimate state, not an error: a Firebase Auth
  /// user can exist before anyone has provisioned a teacher record against that
  /// uid, which is exactly what happens on a freshly seeded database. Callers
  /// degrade the profile rather than treating it as a failure.
  Future<Teacher?> fetchTeacher(String uid) async {
    final snap = await _db.collection(Teacher.collection).doc(uid).get();
    if (!snap.exists) return null;
    return Teacher.fromMap(snap.id, snap.data() ?? const <String, dynamic>{});
  }
}
