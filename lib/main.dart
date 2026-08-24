import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/l10n/locales.dart';
import 'core/router/app_router.dart';
import 'core/services/firestore_service.dart';
import 'core/splash_gate.dart';
import 'core/startup.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/text_scaling.dart';
import 'features/auth/auth_provider.dart';
import 'features/classrooms/classroom_provider.dart';
import 'features/dashboard/dashboard_provider.dart';
import 'features/startup/startup_failure_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Nothing here throws. A step that fails reports instead, so a bad upgrade
  // lands on a screen with a Retry rather than a blank splash forever.
  final outcome = await runStartup();
  runApp(TcStarterRoot(initialOutcome: outcome));
}

/// Decides whether the app can run at all, and offers a way back if not.
class TcStarterRoot extends StatefulWidget {
  const TcStarterRoot({super.key, required this.initialOutcome});

  final StartupOutcome initialOutcome;

  @override
  State<TcStarterRoot> createState() => _TcStarterRootState();
}

class _TcStarterRootState extends State<TcStarterRoot> {
  late StartupOutcome _outcome = widget.initialOutcome;
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    final next = await runStartup();
    if (!mounted) return;
    setState(() {
      _outcome = next;
      _retrying = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_outcome.canRunApp) {
      // ScreenUtilInit is still needed: the design tokens are `.sp`/`.w`
      // getters and throw without it. It depends on nothing that just failed.
      final failure = _Shell(
        child: StartupFailureScreen(
          onRetry: _retry,
          busy: _retrying,
          localized: _outcome.localizationReady,
        ),
      );
      // Only wrap in EasyLocalization when it actually initialised, otherwise
      // the widget itself would be the second thing to fail.
      return _outcome.localizationReady ? _localized(failure) : failure;
    }

    return _localized(const TcStarterApp());
  }

  Widget _localized(Widget child) => EasyLocalization(
        // The list lives in core/l10n/locales.dart, because the profile
        // screen's language picker is built from the same one.
        supportedLocales: kSupportedLocales,
        path: 'assets/l10n',
        fallbackLocale: kFallbackLocale,
        child: child,
      );
}

/// The minimum chrome a screen needs before the real app is running.
class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(360, 800),
      minTextAdapt: true,
      fontSizeResolver: FontSizeResolvers.width,
      builder: (context, _) => MaterialApp(
        theme: AppTheme.light,
        debugShowCheckedModeBanner: false,
        home: child,
      ),
    );
  }
}

class TcStarterApp extends StatefulWidget {
  const TcStarterApp({super.key});

  @override
  State<TcStarterApp> createState() => _TcStarterAppState();
}

class _TcStarterAppState extends State<TcStarterApp> {
  late final FirestoreService _firestore;
  late final AuthProvider _auth;
  late final SplashGate _splashGate;
  late final Listenable _routerRefresh;
  late final GoRouter _router;

  /// Owned here rather than created by the providers, so that [_onAuthChanged]
  /// has something to reset. They must outlive the screens — the dashboard is
  /// rebuilt on every tab change and a per-screen provider would refetch each
  /// time — which is exactly why they need clearing when the teacher changes.
  late final DashboardProvider _dashboard;
  late final ClassroomProvider _classrooms;

  /// The uid the per-teacher providers currently hold data for. Compared against
  /// the session on every auth notification.
  String? _loadedUid;

  @override
  void initState() {
    super.initState();
    // One FirestoreService for the whole app, so every read goes through one
    // handle on one database.
    _firestore = FirestoreService();
    _auth = AuthProvider(firestore: _firestore);
    _splashGate = SplashGate();
    // Merged ONCE and stored: `refreshListenable` must be a stable object, and
    // `Listenable.merge` returns a new instance on every call. Building it
    // inline would rebuild the router and wipe the navigation stack.
    _routerRefresh = Listenable.merge([_auth, _splashGate]);
    // Built ONCE, here, never in build(). See the note in app_router.dart.
    _router = AppRouter.router(
      refreshListenable: _routerRefresh,
      isAuthenticated: () => _auth.isAuthenticated,
      isAuthLoaded: () => _auth.authLoaded,
      isSplashHoldElapsed: () => _splashGate.elapsed,
    );
    // Listening starts only after the router exists, so the very first auth
    // notification has something to refresh. Same for the splash clock: it
    // ends by asking the router to re-evaluate.
    _dashboard = DashboardProvider(firestore: _firestore);
    _classrooms = ClassroomProvider(firestore: _firestore);
    // WHO IS SIGNED IN IS THE ONLY INPUT TO EVERY PER-TEACHER READ, so a change
    // of user has to invalidate everything already loaded. Registered before
    // _auth.start() so the very first notification is seen.
    _auth.addListener(_onAuthChanged);
    _loadedUid = _auth.uid;
    _auth.start();
    _splashGate.start();
  }

  /// Clears every per-teacher provider when the signed-in user changes.
  ///
  /// WHY THIS IS NOT OPTIONAL. Both providers are created above the router, so
  /// they survive a sign-out with the previous teacher's name, school and
  /// classrooms still in them. The dashboard asks for its own data from a
  /// post-frame callback, which runs AFTER the first frame is built — so without
  /// this, the first thing a second teacher sees on the same device is the first
  /// teacher's dashboard, fully rendered, until their own read returns.
  ///
  /// Fires on sign-out too, not only on a switch between two teachers: clearing
  /// at sign-out means there is nothing left to leak in the first place, rather
  /// than a race between the next sign-in and the next load.
  void _onAuthChanged() {
    final uid = _auth.uid;
    if (uid == _loadedUid) return;
    _loadedUid = uid;
    _dashboard.reset();
    _classrooms.reset();
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _splashGate.dispose();
    // Disposed here because this State owns them; the .value providers below
    // deliberately do not take ownership.
    _dashboard.dispose();
    _classrooms.dispose();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Exposed so per-route providers (the classroom detail and the
        // learning unit) can build their own scoped instance against the
        // same single Firestore handle.
        Provider<FirestoreService>.value(value: _firestore),
        // .value, not the default constructor: this State owns _auth and
        // disposes it, and the router already holds a reference to the same
        // instance. A second owner would dispose it out from under the router.
        ChangeNotifierProvider<AuthProvider>.value(value: _auth),
        // .value, not create: this State owns both and disposes them, because
        // it also has to be able to reset them when the signed-in user changes.
        // See _onAuthChanged.
        ChangeNotifierProvider<DashboardProvider>.value(value: _dashboard),
        ChangeNotifierProvider<ClassroomProvider>.value(value: _classrooms),
      ],
      // ScreenUtilInit MUST sit above MaterialApp so that every route, dialog
      // and bottom sheet has an initialised ScreenUtil. 360x800 is the Android
      // baseline the design tokens were tuned against.
      child: ScreenUtilInit(
        designSize: const Size(360, 800),
        minTextAdapt: true,
        splitScreenMode: false,
        fontSizeResolver: FontSizeResolvers.width,
        builder: (context, child) => MaterialApp.router(
          title: 'Teacher Corner',
          theme: AppTheme.light,
          routerConfig: _router,
          debugShowCheckedModeBanner: false,
          locale: context.locale,
          supportedLocales: context.supportedLocales,
          localizationsDelegates: context.localizationDelegates,
          // Compose, do not replace: `.sp` already scales for screen width, so
          // the system accessibility scale is capped on top of it to stop text
          // double-scaling out of the layout.
          builder: (context, routerChild) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: clampTextScaler(mq.textScaler)),
              child: routerChild ?? const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
  }
}
