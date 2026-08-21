import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/auth/login_screen.dart';

import '../../support/fakes.dart';
import '../../support/pump_app.dart';

Future<void> pumpLogin(
  WidgetTester tester, {
  LoginStage stage = LoginStage.phoneEntry,
  String? errorKey,
  String pendingPhone = '',
  Size surfaceSize = const Size(360, 800),
  TextScaler textScaler = TextScaler.noScaling,
}) =>
    pumpScreen(
      tester,
      surfaceSize: surfaceSize,
      textScaler: textScaler,
      providers: [
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => StubAuthProvider(
            stubUid: null,
            stubStage: stage,
            stubErrorKey: errorKey,
            stubPendingPhone: pendingPhone,
          ),
        ),
      ],
      child: const LoginScreen(),
    );

void main() {
  setUp(initLocalizationForTest);

  group('the number step', () {
    testWidgets('shows the dial code and the hint together', (tester) async {
      // Regression: a Center inside prefixIcon expanded to the field's whole
      // width and swallowed the input area, so the hint never rendered. Every
      // test passed anyway, because the field still accepted text.
      await pumpLogin(tester);

      expect(find.text('+91'), findsOneWidget);
      expect(find.text('10-digit mobile number'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
    });

    testWidgets('rejects a number that is not ten digits', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid 10-digit mobile number.'),
        findsOneWidget,
      );
    });

    testWidgets('rejects a ten-digit number starting with 5', (tester) async {
      // Indian mobile numbers start 6-9. Checked locally so an obvious typo
      // does not spend an SMS learning the same thing from the server.
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField), '5123456789');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      expect(
        find.text('Enter a valid 10-digit mobile number.'),
        findsOneWidget,
      );
    });

    testWidgets('accepts a valid number', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.tap(find.text('Send OTP'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid 10-digit mobile number.'), findsNothing);
    });

    testWidgets('keeps non-digits out of the field', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField), '98a76-543 210xyz');
      await tester.pumpAndSettle();

      final field = tester.widget<TextFormField>(find.byType(TextFormField));
      expect(field.controller!.text, '9876543210');
    });
  });

  group('the code step', () {
    testWidgets('names the number the code went to', (tester) async {
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
      );

      expect(find.textContaining('+919876543210'), findsOneWidget);
      expect(find.text('Verify'), findsOneWidget);
      expect(find.text('Change number'), findsOneWidget);
      expect(find.text('Resend code'), findsOneWidget);
    });

    testWidgets('renders a provider error as a readable sentence',
        (tester) async {
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
        errorKey: 'auth.error_invalid_code',
      );

      // The provider carries a KEY; the screen renders the sentence. A raw
      // Firebase code never reaches the teacher.
      expect(
        find.text('That code is not correct. Check it and try again.'),
        findsOneWidget,
      );
      expect(find.textContaining('auth.'), findsNothing);
    });

    testWidgets('rejects a code that is not six digits', (tester) async {
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
      );

      await tester.enterText(find.byType(TextFormField), '123');
      await tester.tap(find.text('Verify'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the 6-digit code.'), findsOneWidget);
    });
  });

  group('surviving the device', () {
    testWidgets('does not overflow in landscape', (tester) async {
      await pumpLogin(tester, surfaceSize: const Size(800, 360));
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at the clamped maximum font size',
        (tester) async {
      await pumpLogin(tester, textScaler: const TextScaler.linear(3.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the code step survives landscape too', (tester) async {
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
        errorKey: 'auth.error_invalid_code',
        surfaceSize: const Size(800, 360),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
