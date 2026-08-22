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

    testWidgets('consent starts unticked and untickable, and gates the send',
        (tester) async {
      // Consent is asked for, never assumed, and it is only asked once there is
      // a number to consent about. Both gates are independent: a number with no
      // consent must not send, and consent with no number cannot be given.
      await pumpLogin(tester);

      Checkbox box() => tester.widget<Checkbox>(find.byType(Checkbox));
      ElevatedButton cta() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      expect(box().value, isFalse, reason: 'never pre-ticked');
      expect(
        box().onChanged,
        isNull,
        reason: 'nothing to consent about before a number',
      );
      expect(cta().onPressed, isNull, reason: 'no number, no send');

      // A partial number is not a number.
      await tester.enterText(find.byType(TextFormField), '98765');
      await tester.pumpAndSettle();
      expect(box().onChanged, isNull, reason: 'still untickable at 5 digits');
      expect(cta().onPressed, isNull);

      // Ten digits opens the box, but does not tick it for them.
      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pumpAndSettle();
      expect(box().onChanged, isNotNull, reason: 'tickable at 10 digits');
      expect(box().value, isFalse, reason: 'opening it must not tick it');
      expect(cta().onPressed, isNull, reason: 'number alone is not consent');

      // Consent given, and only now can it send.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(box().value, isTrue);
      expect(cta().onPressed, isNotNull);
    });

    testWidgets('losing the number withdraws the consent with it',
        (tester) async {
      // Otherwise the box sits ticked over an empty field, which is precisely
      // the state the unticked default exists to prevent.
      await pumpLogin(tester);

      Checkbox box() => tester.widget<Checkbox>(find.byType(Checkbox));
      ElevatedButton cta() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      await tester.enterText(find.byType(TextFormField), '9876543210');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      expect(cta().onPressed, isNotNull, reason: 'armed');

      await tester.enterText(find.byType(TextFormField), '987654321');
      await tester.pumpAndSettle();

      expect(box().value, isFalse, reason: 'consent withdrawn with the number');
      expect(box().onChanged, isNull, reason: 'and untickable again');
      expect(cta().onPressed, isNull);
    });

    testWidgets('rejects a number that is not ten digits', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField), '12345');
      await tester.pumpAndSettle();

      // Under the length gate a short number cannot be submitted at all, so
      // the validator never speaks. Being unable to press is the rejection.
      final cta = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(cta.onPressed, isNull, reason: 'five digits cannot submit');
      expect(find.text('Enter a valid 10-digit mobile number.'), findsNothing);
    });

    testWidgets('rejects a ten-digit number starting with 5', (tester) async {
      // Indian mobile numbers start 6-9. Checked locally so an obvious typo
      // does not spend an SMS learning the same thing from the server.
      //
      // Ten digits, so the length gate opens and the button is pressable. That
      // is deliberate: gating on the regex instead would leave the screen dead
      // with nothing explaining why, so it stays pressable in order to explain.
      await pumpLogin(tester);

      await tester.enterText(find.byType(TextFormField), '5123456789');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
        reason: 'pressable, so it can explain',
      );

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
      await tester.pumpAndSettle();
      // Consent too, or the button is disabled and this asserts nothing.
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

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
    testWidgets('names the number the code went to, grouped', (tester) async {
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
      );

      // Grouped for reading, per the mockup: one 12-digit run is hard to check
      // against the handset you are holding.
      expect(find.text('+91 98765 43210'), findsOneWidget);
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.text('Verify & Login'), findsOneWidget);
      expect(find.text('Resend OTP'), findsOneWidget);
      // "Change number" is the app bar's back arrow now, not a text button, so
      // the action survives the redesign as a tooltip.
      expect(find.byTooltip('Change number'), findsOneWidget);
    });

    testWidgets('shows the raw number if it is not the expected shape',
        (tester) async {
      // The grouping regex must not eat a value it does not understand.
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+4477009',
      );

      expect(find.text('+4477009'), findsOneWidget);
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

    testWidgets('holds the CTA disabled until six digits are in',
        (tester) async {
      // The mockup greys the CTA out rather than letting a short code be
      // submitted and bounced, so "not six digits" is now enforced by the
      // button's own state. The validator behind it is the backstop.
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
      );

      ElevatedButton cta() =>
          tester.widget<ElevatedButton>(find.byType(ElevatedButton));

      expect(cta().onPressed, isNull, reason: 'disabled with no code');

      await tester.enterText(find.byType(TextField), '123');
      await tester.pumpAndSettle();
      expect(cta().onPressed, isNull, reason: 'still disabled at 3 digits');

      await tester.enterText(find.byType(TextField), '123456');
      await tester.pumpAndSettle();
      expect(cta().onPressed, isNotNull, reason: 'enabled at 6 digits');
    });

    testWidgets('draws one box per digit, and fills them as you type',
        (tester) async {
      await pumpLogin(
        tester,
        stage: LoginStage.codeEntry,
        pendingPhone: '+919876543210',
      );

      await tester.enterText(find.byType(TextField), '1234');
      await tester.pumpAndSettle();

      for (final digit in ['1', '2', '3', '4']) {
        expect(find.text(digit), findsOneWidget);
      }
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
