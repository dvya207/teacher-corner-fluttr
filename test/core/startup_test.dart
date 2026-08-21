import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/startup.dart';

void main() {
  Future<void> ok() async {}
  Future<void> boom() async => throw StateError('decrypt failed on upgrade');

  group('both steps succeed', () {
    test('the app is allowed to run', () async {
      final outcome = await runStartup(
        initLocalization: ok,
        initFirebase: ok,
      );

      expect(outcome.canRunApp, isTrue);
      expect(outcome.isDegraded, isFalse);
      expect(outcome.error, isNull);
    });
  });

  group('a failing step never throws out of runStartup', () {
    test('Firebase failing is reported, not raised', () async {
      // The bug this exists to prevent: something before runApp threw on
      // upgrade and the app sat on a blank splash forever.
      // No expectLater needed: if runStartup rethrew, this line never runs and
      // the test fails, which is exactly the contract.
      final outcome = await runStartup(
        initLocalization: ok,
        initFirebase: boom,
      );

      expect(outcome.canRunApp, isFalse);
      expect(outcome.error, isA<StateError>());
    });

    test('localization failing does NOT stop the app', () async {
      // Cosmetic by comparison: .tr() degrades to the key, which is ugly but
      // usable, so it must not block a teacher from signing in.
      final outcome = await runStartup(
        initLocalization: boom,
        initFirebase: ok,
      );

      expect(outcome.localizationReady, isFalse);
      expect(outcome.firebaseReady, isTrue);
      expect(outcome.canRunApp, isTrue);
      expect(outcome.isDegraded, isTrue);
    });

    test('both failing still returns an outcome', () async {
      final outcome = await runStartup(
        initLocalization: boom,
        initFirebase: boom,
      );

      expect(outcome.canRunApp, isFalse);
      expect(outcome.localizationReady, isFalse);
    });

    test('the first failure is the one kept', () async {
      final outcome = await runStartup(
        initLocalization: () async => throw StateError('localization first'),
        initFirebase: () async => throw StateError('firebase second'),
      );

      expect(outcome.error.toString(), contains('localization first'));
    });
  });

  group('Firebase is still attempted when localization failed', () {
    test('so one broken step does not cascade', () async {
      var firebaseAttempted = false;
      await runStartup(
        initLocalization: boom,
        initFirebase: () async => firebaseAttempted = true,
      );

      expect(firebaseAttempted, isTrue);
    });
  });
}
