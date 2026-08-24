import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/splash_gate.dart';

/// The splash hold, on its own. Short real durations rather than a fake clock,
/// because the gate is a `Timer` and the whole behaviour is about wall time.
void main() {
  test('starts closed, opens after the minimum window', () async {
    final gate = SplashGate(minimum: const Duration(milliseconds: 30));
    addTearDown(gate.dispose);

    expect(gate.elapsed, isFalse, reason: 'closed before start()');
    gate.start();
    expect(gate.elapsed, isFalse, reason: 'still closed immediately after');

    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(gate.elapsed, isTrue);
  });

  test('a zero window opens at once, for tests that are not about the hold',
      () {
    final gate = SplashGate(minimum: Duration.zero);
    addTearDown(gate.dispose);

    gate.start();
    expect(gate.elapsed, isTrue);
  });

  test('notifies exactly once, so the router refreshes once', () async {
    final gate = SplashGate(minimum: const Duration(milliseconds: 20));
    addTearDown(gate.dispose);

    var notifications = 0;
    gate.addListener(() => notifications++);

    gate.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(notifications, 1);
  });

  test('start is idempotent, so a second call cannot stack a second timer',
      () async {
    final gate = SplashGate(minimum: const Duration(milliseconds: 20));
    addTearDown(gate.dispose);

    var notifications = 0;
    gate.addListener(() => notifications++);

    gate.start();
    gate.start();
    gate.start();
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(notifications, 1);
    expect(gate.elapsed, isTrue);
  });

  test('disposing mid-window does not notify a disposed notifier', () async {
    // Notifying after dispose throws, and this timer can outlive the tree when
    // the app is closed during the splash.
    final gate = SplashGate(minimum: const Duration(milliseconds: 30));
    gate.start();
    gate.dispose();

    await Future<void>.delayed(const Duration(milliseconds: 90));
    expect(gate.elapsed, isFalse, reason: 'the timer was cancelled');
  });
}
