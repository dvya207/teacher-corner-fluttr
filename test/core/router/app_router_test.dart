import 'package:flutter_test/flutter_test.dart';
import 'package:tc_starter/core/router/app_router.dart';

/// Tests the routing POLICY, not the widget tree. `resolveRedirect` is a pure
/// function of three inputs, and it is the piece that regresses.
void main() {
  // Every route the app has, plus one it does not, because the guard has to
  // hold for unknown locations too (a stale deep link, a typo in a push).
  const everywhere = <String>[
    '/splash',
    '/login',
    '/dashboard',
    '/classrooms',
    '/classrooms/cls_oak_7a',
    '/profile',
    '/lu/lu_magnetic_pen_stand',
    '/not-a-real-route',
  ];

  group('auth not yet resolved', () {
    test('holds on the splash from anywhere else', () {
      for (final location in everywhere.where((l) => l != '/splash')) {
        expect(
          AppRouter.resolveRedirect(
            location: location,
            authLoaded: false,
            isAuthenticated: false,
          ),
          '/splash',
          reason: '$location should wait on the splash while auth is unknown',
        );
      }
    });

    test('stays put once already on the splash', () {
      expect(
        AppRouter.resolveRedirect(
          location: '/splash',
          authLoaded: false,
          isAuthenticated: false,
        ),
        isNull,
      );
    });

    test('never routes to login, which is what would flash on cold start', () {
      // The trap in Phase 1: "not yet known" is not "signed out". If this ever
      // returns /login the user sees the login screen for a few frames on every
      // single launch before being bounced to the dashboard.
      for (final location in everywhere) {
        for (final authenticated in [true, false]) {
          expect(
            AppRouter.resolveRedirect(
              location: location,
              authLoaded: false,
              isAuthenticated: authenticated,
            ),
            isNot('/login'),
            reason: '$location leaked to login while auth was unresolved',
          );
        }
      }
    });
  });

  group('resolved and signed out', () {
    test('no route reaches a signed-in screen', () {
      for (final location in everywhere.where((l) => l != '/login')) {
        expect(
          AppRouter.resolveRedirect(
            location: location,
            authLoaded: true,
            isAuthenticated: false,
          ),
          '/login',
          reason: '$location was reachable without a session',
        );
      }
    });

    test('stays put on the login screen', () {
      expect(
        AppRouter.resolveRedirect(
          location: '/login',
          authLoaded: true,
          isAuthenticated: false,
        ),
        isNull,
      );
    });
  });

  group('resolved and signed in', () {
    test('splash and login are no longer destinations', () {
      for (final location in ['/splash', '/login']) {
        expect(
          AppRouter.resolveRedirect(
            location: location,
            authLoaded: true,
            isAuthenticated: true,
          ),
          '/dashboard',
        );
      }
    });

    test('leaves every real destination alone', () {
      for (final location in everywhere.where(
        (l) => l != '/splash' && l != '/login',
      )) {
        expect(
          AppRouter.resolveRedirect(
            location: location,
            authLoaded: true,
            isAuthenticated: true,
          ),
          isNull,
          reason: '$location was redirected away from unnecessarily',
        );
      }
    });
  });
}
