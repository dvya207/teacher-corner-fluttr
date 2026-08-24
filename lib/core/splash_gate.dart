import 'dart:async';

import 'package:flutter/foundation.dart';

/// Keeps the splash on screen for a minimum window after launch.
///
/// Why this exists at all: `authLoaded` can flip in well under 200ms on a warm
/// start, so the branded splash was effectively invisible. Divya asked for it
/// to be seen before the login page, which means a floor on its display time.
///
/// Why it is a separate notifier rather than a flag on `AuthProvider`: this is
/// a presentation concern with nothing to do with who is signed in, and
/// `AuthProvider` is already the `refreshListenable` the router depends on.
/// Keeping them apart means the routing policy stays a pure function of its
/// inputs and this can be driven to `true` instantly in a test.
///
/// The cost is real and deliberate: every launch now pays [minimum], including
/// warm ones. See NOTES.md.
class SplashGate extends ChangeNotifier {
  SplashGate({this.minimum = kSplashMinimumDisplay});

  /// Floor on how long the splash stays up. Pass [Duration.zero] in tests that
  /// are not about the hold itself.
  final Duration minimum;

  Timer? _timer;
  bool _elapsed = false;
  bool _disposed = false;

  /// True once the splash has been up for at least [minimum].
  bool get elapsed => _elapsed;

  /// Starts the clock. Idempotent, so a hot restart or a second call cannot
  /// stack two timers.
  void start() {
    if (_elapsed || _timer != null) return;
    if (minimum <= Duration.zero) {
      _finish();
      return;
    }
    _timer = Timer(minimum, _finish);
  }

  void _finish() {
    _timer = null;
    if (_elapsed) return;
    _elapsed = true;
    // Same guard as AuthProvider: notifying a disposed ChangeNotifier throws,
    // and this fires from a timer that can outlive the tree on a fast exit.
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}

/// How long the splash is held before the router will route past it.
///
/// 2 SECONDS. This was 30, and the cost of that was the objection recorded here
/// at the time: it is paid on EVERY launch, warm ones included, by a teacher
/// standing in front of a class who wants the activity on screen, and it is long
/// enough that a teacher may conclude the app has hung and force-close it.
///
/// WHY A FLOOR AT ALL, rather than zero. Auth and Firebase usually resolve in
/// well under a second on a warm start, so with no floor the branded splash
/// appears for a frame or two and reads as a flicker. Two seconds is long enough
/// to register the brand and short enough not to be waited on.
///
/// It is also a FLOOR, not a delay: if auth takes longer than this the splash
/// stays up until it resolves, which is what stops the login screen flashing
/// before the dashboard on a cold start.
///
/// It is one constant. Change it here and nothing else moves.
const Duration kSplashMinimumDisplay = Duration(seconds: 2);
