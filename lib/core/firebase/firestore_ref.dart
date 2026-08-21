import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Single source of truth for WHICH Firestore database this app talks to.
///
/// `helix-staging-india` hosts several named databases side by side, the
/// `(default)` one plus `bugpulse`, `ezblog`, `sidteachercorner` and
/// `teacher-corner-dev`. Named databases are NOT reachable through
/// `FirebaseFirestore.instance`: that constant always resolves to `(default)`,
/// silently, with no error. If you write through it you will spend an afternoon
/// wondering why the Console shows nothing.
///
/// So every read and write in this app goes through [db], never through
/// `FirebaseFirestore.instance` directly. Put your own database id below -
/// do not point this at someone else's.
const String kDatabaseId = 'divya-teacher-corner';

/// The one Firestore handle the app uses.
final FirebaseFirestore db = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: kDatabaseId,
);
