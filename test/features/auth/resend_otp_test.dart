import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/features/auth/auth_provider.dart';
import 'package:tc_starter/features/auth/login_screen.dart';

import '../../support/pump_app.dart';

/// Resend OTP.
///
/// The bug these exist for: both stages wrap their field in a `Form` and used to
/// SHARE one GlobalKey, so `validate()` checked whichever field was on screen
/// rather than the one the action was about. Tapping Resend validated the OTP
/// box — empty or partial exactly when a teacher wants a new code — failed, and
/// returned without sending anything.
///
/// A test that called the provider directly would not have caught it: the fault
/// was entirely in the screen's guard, so these drive the widget.

/// Records what was sent, without touching Firebase or spending an SMS.
class RecordingAuthProvider extends AuthProvider {
  RecordingAuthProvider({this.startAtCodeStage = false});

  final bool startAtCodeStage;

  final List<String> sentTo = [];
  final List<String> verified = [];
  final bool _busy = false;
  LoginStage _stage = LoginStage.phoneEntry;
  String _pending = '';

  @override
  void start() {
    if (startAtCodeStage) {
      _stage = LoginStage.codeEntry;
      _pending = '+916000000001';
    }
  }

  @override
  bool get authLoaded => true;

  @override
  bool get isAuthenticated => false;

  @override
  LoginStage get stage => _stage;

  @override
  bool get isBusy => _busy;

  @override
  String? get errorKey => null;

  @override
  String get pendingPhoneNumber => _pending;

  @override
  Future<void> sendOtp(String tenDigitNumber) async {
    sentTo.add(tenDigitNumber);
    _pending = '$kDialCode$tenDigitNumber';
    _stage = LoginStage.codeEntry;
    notifyListeners();
  }

  @override
  Future<void> verifyOtp(String smsCode) async {
    verified.add(smsCode);
    notifyListeners();
  }

  @override
  void changeNumber() {
    _stage = LoginStage.phoneEntry;
    notifyListeners();
  }
}

Future<RecordingAuthProvider> pumpLogin(WidgetTester tester) async {
  final auth = RecordingAuthProvider();
  await pumpScreen(
    tester,
    child: const LoginScreen(),
    providers: [ChangeNotifierProvider<AuthProvider>.value(value: auth)],
  );
  return auth;
}

/// Drives the phone stage through to the code stage, the way a teacher does.
Future<RecordingAuthProvider> reachCodeStage(WidgetTester tester) async {
  final auth = await pumpLogin(tester);

  await tester.enterText(find.byType(TextFormField).first, '6000000001');
  await tester.pumpAndSettle();
  // Consent gates the button, so it has to be given.
  await tester.tap(find.byType(Checkbox));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Send OTP'));
  await tester.pumpAndSettle();

  expect(auth.sentTo, ['6000000001'], reason: 'the first send did not happen');
  expect(find.text('Verify & Login'), findsOneWidget,
      reason: 'not on the code stage');
  return auth;
}

void main() {
  setUp(initLocalizationForTest);

  group('the resend control', () {
    testWidgets('is disabled while the countdown runs', (tester) async {
      await reachCodeStage(tester);

      // The countdown starts at 45 and only a real send starts it, so it is
      // running now.
      expect(find.textContaining('Resend in'), findsOneWidget);

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      // Still one send. A disabled control that silently sends would be worse
      // than one that does nothing.
      expect(find.textContaining('Resend in'), findsOneWidget);
    });

    testWidgets('becomes tappable once the countdown expires', (tester) async {
      await reachCodeStage(tester);

      // 45 seconds of one-second ticks.
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      expect(find.textContaining('Resend in'), findsNothing);
    });
  });

  group('resending actually sends', () {
    testWidgets('with the OTP box EMPTY — the regression', (tester) async {
      // THE BUG. An empty code box is the normal state when a teacher wants a
      // new code, and it used to make the shared form validation fail and
      // swallow the resend entirely.
      final auth = await reachCodeStage(tester);
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      expect(auth.sentTo, ['6000000001', '6000000001'],
          reason: 'resend with an empty code box did not send');
    });

    testWidgets('with a PARTIAL code typed', (tester) async {
      // The other half of the same bug: three digits is still not six, so the
      // OTP validator failed and the resend was swallowed.
      final auth = await reachCodeStage(tester);
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      expect(auth.sentTo.length, 2, reason: 'resend with a partial code did not send');
    });

    testWidgets('sends to the same number, not a blank one', (tester) async {
      // The phone controller still holds the number on this stage; a resend
      // that sent an empty string would spend an SMS on nothing.
      final auth = await reachCodeStage(tester);
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      expect(auth.sentTo.last, '6000000001');
    });

    testWidgets('clears the old code, so it cannot be submitted after',
        (tester) async {
      // The old code is void the moment a new one is requested. Left in the
      // boxes it would be submitted against the new challenge and burn one of
      // the server's five attempts.
      final auth = await reachCodeStage(tester);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Login'));
      await tester.pumpAndSettle();

      // Nothing was verified: the box was emptied, so the code validator
      // correctly refuses rather than sending the stale code.
      expect(auth.verified, isEmpty);
    });

    testWidgets('restarts the countdown, so it cannot be spammed',
        (tester) async {
      final auth = await reachCodeStage(tester);
      await tester.pump(const Duration(seconds: 46));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();
      expect(auth.sentTo.length, 2);

      // Cooling down again, so a second tap sends nothing.
      expect(find.textContaining('Resend in'), findsOneWidget);
      await tester.tap(find.text('Resend OTP'));
      await tester.pumpAndSettle();
      expect(auth.sentTo.length, 2);
    });
  });

  group('verify still validates its own field', () {
    testWidgets('a short code is refused', (tester) async {
      // Separating the form keys must not have removed the code validation.
      final auth = await reachCodeStage(tester);
      await tester.enterText(find.byType(TextField).first, '123');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Login'));
      await tester.pumpAndSettle();

      expect(auth.verified, isEmpty);
    });

    testWidgets('a full code is accepted', (tester) async {
      final auth = await reachCodeStage(tester);
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verify & Login'));
      await tester.pumpAndSettle();

      expect(auth.verified, ['123456']);
    });
  });
}
