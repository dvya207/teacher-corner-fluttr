import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Single source of truth for WHICH Firestore database this app talks to.
///
/// `helix-staging-india` hosts several named databases side by side, the
/// `(default)` one plus `bugpulse`, `ezblog`, `sidteachercorner` and
/// `teacher-corner-dev`. Named databases are NOT
/// reachable through `FirebaseFirestore.instance`: that constant always resolves
/// to `(default)`, silently, with no error. If you write through it you will
/// spend an afternoon wondering why the Console shows nothing.
///
/// So every read and write in this app goes through [db], never through
/// `FirebaseFirestore.instance` directly.
///
/// THIS APP IS A GUEST IN SOMEBODY ELSE'S DATABASE, and that is the whole point
/// of the current value. `teacher-corner-dev` is owned outright by the Angular
/// Teacher Corner web app in `~/code/teacher-corner`, which is live and working.
/// This app reads its teachers, classrooms, programmes and learning units so
/// that there is ONE source of truth for a teacher rather than a seeded copy of
/// one. Three consequences, none of them optional:
///
///   1. READ ONLY, except for evidence. The only thing this app writes is
///      `users/{uid}/submissions/*`, which is owner-scoped by path and which the
///      web app does not use. Nothing here rewrites a teacher, a classroom, a
///      programme or a learning unit.
///   2. NO RULES DEPLOY FROM THIS REPO. The rules governing this data live in
///      `~/code/teacher-corner/firestore.rules` and are deployed from there.
///      `firebase.json` in this repo carries no `firestore` block precisely so
///      that a deploy from here cannot reach them. Do not add one back.
///   3. NO SEEDING. `tools/seed.js` is disabled. Writing fixtures here would
///      put duplicate teachers and classrooms into a database a working app is
///      reading.
///
/// `divya-teacher-corner` is the database this app used to own. It was DELETED
/// on 2026-08-24, after the `tcDivya*` OTP functions were repointed at
/// `teacher-corner-dev` and redeployed, so this app now uses one database for
/// everything it touches. It is gone, not dormant: pointing this constant back
/// at it would not fall back to anything, every read and write would simply
/// fail. There is exactly one correct value.
const String kDatabaseId = 'teacher-corner-dev';

/// The one Firestore handle the app uses.
final FirebaseFirestore db = FirebaseFirestore.instanceFor(
  app: Firebase.app(),
  databaseId: kDatabaseId,
);
