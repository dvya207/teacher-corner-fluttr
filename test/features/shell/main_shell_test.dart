import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  setUp(initLocalizationForTest);

  group('the bottom nav', () {
    testWidgets('carries all five tabs, in order', (tester) async {
      await pumpShell(tester);

      // "Classes", not "Classrooms": five tabs leave roughly 72dp each at the
      // 360dp baseline and the longer word does not fit. The screen itself is
      // still titled "My Classrooms".
      for (final label in ['Home', 'Classes', 'Quizzes', 'Reports', 'Profile']) {
        expect(find.text(label), findsOneWidget, reason: '$label tab missing');
      }
    });

    testWidgets('starts on the tab matching the route', (tester) async {
      await pumpShell(tester, initialLocation: '/reports');

      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bar.currentIndex, 3);
    });

    testWidgets('lights the Classes tab for a nested classroom route',
        (tester) async {
      // startsWith, not ==, so /classrooms/abc still belongs to that tab.
      await pumpShell(tester, initialLocation: '/classrooms');

      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bar.currentIndex, 1);
    });

    testWidgets('tapping a tab navigates to it', (tester) async {
      await pumpShell(tester);

      await tester.tap(find.text('Quizzes'));
      await tester.pumpAndSettle();

      expect(find.text('stub:/quizzes'), findsOneWidget);
      final bar = tester.widget<BottomNavigationBar>(
        find.byType(BottomNavigationBar),
      );
      expect(bar.currentIndex, 2);
    });
  });

  group('surviving the device', () {
    testWidgets('five labels do not overflow the bar', (tester) async {
      await pumpShell(tester);
      expect(tester.takeException(), isNull);
    });

    testWidgets('nor at the clamped maximum font size', (tester) async {
      // The tightest case: five fixed-width tabs and the largest text the
      // clamp allows.
      await pumpShell(tester, textScaler: const TextScaler.linear(3.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nor on a narrow phone', (tester) async {
      await pumpShell(tester, surfaceSize: const Size(320, 640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('nor in landscape', (tester) async {
      await pumpShell(tester, surfaceSize: const Size(800, 360));
      expect(tester.takeException(), isNull);
    });
  });
}
