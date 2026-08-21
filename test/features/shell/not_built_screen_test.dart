import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/shell/not_built_screen.dart';

import '../../support/pump_app.dart';

void main() {
  setUp(initLocalizationForTest);

  testWidgets('names the tab and says it is outside this slice',
      (tester) async {
    await pumpScreen(
      tester,
      child: const NotBuiltScreen(
        titleKey: 'nav.reports',
        icon: Icons.bar_chart_outlined,
      ),
    );

    // The tab keeps its own name in the app bar, so a teacher knows where they
    // landed rather than seeing a generic error.
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Not part of this build yet'), findsOneWidget);
    expect(find.byIcon(Icons.bar_chart_outlined), findsOneWidget);
  });

  testWidgets('does not overflow in landscape', (tester) async {
    await pumpScreen(
      tester,
      surfaceSize: const Size(800, 360),
      child: const NotBuiltScreen(
        titleKey: 'nav.quizzes',
        icon: Icons.quiz_outlined,
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
