import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';

/// A step that must run before `runApp`.
typedef StartupStep = Future<void> Function();

/// What survived startup.
///
/// The two steps are graded differently on purpose. Localization failing is
/// cosmetic: `.tr()` degrades to the key, which is ugly but usable. Firebase
/// failing means there is no data layer at all, so the app must say so rather
/// than route the teacher into screens that can only ever spin.
class StartupOutcome {
  const StartupOutcome({
    required this.firebaseReady,
    required this.localizationReady,
    this.error,
  });

  final bool firebaseReady;
  final bool localizationReady;

  /// The first failure, kept for the log and for the retry screen. Never shown
  /// to a teacher verbatim.
  final Object? error;

  bool get canRunApp => firebaseReady;

  bool get isDegraded => !firebaseReady || !localizationReady;
}

/// Runs the pre-`runApp` steps so that a failure degrades instead of hanging.
///
/// This is the shape of a bug the production app shipped: something before
/// `runApp` threw on upgrade and the app sat on a blank splash forever. It was
/// invisible in debug because it arose from install history, never from a fresh
/// install, so the only defence is structural. Nothing here is allowed to throw
/// out of [runStartup]; every step reports instead.
///
/// Both steps are injectable so the failure paths are testable without breaking
/// a real Firebase project.
Future<StartupOutcome> runStartup({
  StartupStep? initLocalization,
  StartupStep? initFirebase,
}) async {
  Object? firstError;

  var localizationReady = false;
  try {
    await (initLocalization ?? _initLocalization)();
    localizationReady = true;
  } catch (error, stack) {
    firstError ??= error;
    debugPrint('startup: localization failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  var firebaseReady = false;
  try {
    await (initFirebase ?? _initFirebase)();
    firebaseReady = true;
  } catch (error, stack) {
    firstError ??= error;
    debugPrint('startup: Firebase failed: $error');
    debugPrintStack(stackTrace: stack);
  }

  return StartupOutcome(
    firebaseReady: firebaseReady,
    localizationReady: localizationReady,
    error: firstError,
  );
}

Future<void> _initLocalization() => EasyLocalization.ensureInitialized();

/// Idempotent, so pressing Retry after a transient failure does not trip over
/// a duplicate-app error.
Future<void> _initFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
}
