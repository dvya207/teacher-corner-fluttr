import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/startup/startup_failure_screen.dart';

import '../../support/pump_app.dart';

void main() {
  setUp(initLocalizationForTest);

  testWidgets('says what happened and offers a way out', (tester) async {
    var retries = 0;
    await pumpScreen(
      tester,
      child: StartupFailureScreen(onRetry: () async => retries++),
    );

    expect(find.text('Teacher Corner could not start'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(retries, 1);
  });

  testWidgets('the retry is disabled while it is running', (tester) async {
    var retries = 0;
    await pumpScreen(
      tester,
      settle: false,
      child: StartupFailureScreen(onRetry: () async => retries++, busy: true),
    );

    await tester.tap(find.byType(ElevatedButton), warnIfMissed: false);
    await tester.pump();

    expect(retries, 0);
  });

  testWidgets('falls back to English when localization itself failed',
      (tester) async {
    // The one path where a user-facing string cannot come from assets/l10n,
    // because the thing that reads assets/l10n is what broke.
    await pumpScreen(
      tester,
      child: StartupFailureScreen(
        onRetry: () async {},
        localized: false,
      ),
    );

    expect(find.text('Teacher Corner could not start'), findsOneWidget);
    // Never a raw key.
    expect(find.textContaining('startup.'), findsNothing);
  });

  testWidgets('does not overflow in landscape', (tester) async {
    await pumpScreen(
      tester,
      surfaceSize: const Size(800, 360),
      child: StartupFailureScreen(onRetry: () async {}),
    );

    expect(tester.takeException(), isNull);
  });
}
