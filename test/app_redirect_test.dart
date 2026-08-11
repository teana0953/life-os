import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/app.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/finance/presentation/finance_scaffold.dart';
import 'package:life_os/contexts/health/presentation/diet_day_screen.dart';
import 'package:life_os/contexts/health/presentation/health_scaffold.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';

import 'app_test.dart';

/// Regression for the push-notification deep-link bug: a cold start opens the
/// app while auth is still `loading`, which used to redirect every location to
/// `/splash` and then, once resolved, to `/` — dropping the originally
/// requested route (e.g. `/care-today` from a notification). [resolveAuthRedirect]
/// now remembers the intended destination and replays it after auth resolves.
void main() {
  // Convenience wrapper: most cases don't exercise query strings, so default
  // [deepLink] to [loc].
  AuthRedirect resolve({
    required String loc,
    String? deepLink,
    bool error = false,
    bool loading = false,
    bool signedIn = false,
    String? pending,
  }) => resolveAuthRedirect(
    loc: loc,
    deepLink: deepLink ?? loc,
    error: error,
    loading: loading,
    signedIn: signedIn,
    pendingDeepLink: pending,
  );

  group('normal cold start (no deep link)', () {
    test('loading at / goes to splash, nothing remembered', () {
      final r = resolve(loc: '/', loading: true);
      expect(r.location, '/splash');
      expect(r.pendingDeepLink, isNull);
    });

    test('resolved+signedIn at splash with nothing pending lands home', () {
      final r = resolve(loc: '/splash', signedIn: true, pending: null);
      expect(r.location, '/');
      expect(r.pendingDeepLink, isNull);
    });
  });

  group('invite link deep-link (design.md D6): query is not dropped', () {
    test('loading at /invite?token=abc remembers the full URI, query included', () {
      final r = resolve(
        loc: '/invite',
        deepLink: '/invite?token=abc',
        loading: true,
      );
      expect(r.location, '/splash');
      expect(r.pendingDeepLink, '/invite?token=abc');
    });

    test('resolved at splash replays /invite?token=abc with the query intact', () {
      final r = resolve(
        loc: '/splash',
        signedIn: true,
        pending: '/invite?token=abc',
      );
      expect(r.location, '/invite?token=abc');
      expect(r.pendingDeepLink, isNull);
    });

    test('a signed-out user opening the link is sent to login, keeping it pending', () {
      final r = resolve(
        loc: '/invite',
        deepLink: '/invite?token=abc',
        loading: false,
        signedIn: false,
        pending: '/invite?token=abc',
      );
      expect(r.location, '/login');
      expect(r.pendingDeepLink, '/invite?token=abc');
    });

    test('once signed in and replayed, the login screen replays it and clears it', () {
      final r = resolve(loc: '/login', signedIn: true, pending: '/invite?token=abc');
      expect(r.location, '/invite?token=abc');
      expect(r.pendingDeepLink, isNull);
    });
  });

  group('deep-link cold start, already signed in', () {
    test('loading at a deep link remembers it and shows splash', () {
      final r = resolve(loc: '/care-today', loading: true);
      expect(r.location, '/splash');
      expect(r.pendingDeepLink, '/care-today');
    });

    test('still loading at splash keeps the remembered deep link', () {
      final r = resolve(loc: '/splash', loading: true, pending: '/care-today');
      expect(r.location, isNull);
      expect(r.pendingDeepLink, '/care-today');
    });

    test('resolved at splash replays the deep link and clears it', () {
      final r = resolve(loc: '/splash', signedIn: true, pending: '/care-today');
      expect(r.location, '/care-today');
      expect(r.pendingDeepLink, isNull);
    });
  });

  group('deep-link cold start, not signed in then signs in', () {
    test('resolved+notSignedIn at splash goes to login, keeps the deep link', () {
      final r = resolve(loc: '/splash', signedIn: false, pending: '/care-today');
      expect(r.location, '/login');
      expect(r.pendingDeepLink, '/care-today');
    });

    test('staying on login keeps the deep link', () {
      final r = resolve(loc: '/login', signedIn: false, pending: '/care-today');
      expect(r.location, isNull);
      expect(r.pendingDeepLink, '/care-today');
    });

    test('after sign-in on the login gate, the deep link is replayed', () {
      final r = resolve(loc: '/login', signedIn: true, pending: '/care-today');
      expect(r.location, '/care-today');
      expect(r.pendingDeepLink, isNull);
    });
  });

  group('capture rules', () {
    test('the default home route is not captured as a deep link', () {
      final r = resolve(loc: '/', loading: true);
      expect(r.pendingDeepLink, isNull);
    });

    test('an auth gate is not captured as a deep link', () {
      final r = resolve(loc: '/login', loading: true);
      expect(r.pendingDeepLink, isNull);
    });

    test('a query string on the deep link is preserved', () {
      final r = resolve(
        loc: '/care-today',
        deepLink: '/care-today?slot=abc',
        loading: true,
      );
      expect(r.pendingDeepLink, '/care-today?slot=abc');
    });

    test('an already-remembered deep link is not overwritten while loading', () {
      final r = resolve(loc: '/splash', loading: true, pending: '/care-items');
      expect(r.pendingDeepLink, '/care-items');
    });
  });

  group('unaffected paths', () {
    test('error routes to the auth-error screen', () {
      expect(resolve(loc: '/care-today', error: true).location, '/auth-error');
      expect(resolve(loc: '/auth-error', error: true).location, isNull);
    });

    test('signed in on a real route with nothing pending stays put', () {
      final r = resolve(loc: '/care-today', signedIn: true, pending: null);
      expect(r.location, isNull);
      expect(r.pendingDeepLink, isNull);
    });

    test('signed in on a real route defensively clears any stray pending', () {
      final r = resolve(loc: '/health', signedIn: true, pending: '/care-today');
      expect(r.location, isNull);
      expect(r.pendingDeepLink, isNull);
    });

    test('the register gate is also honored when signed out', () {
      final r = resolve(loc: '/register', signedIn: false, pending: '/care-today');
      expect(r.location, isNull);
      expect(r.pendingDeepLink, '/care-today');
    });

    test('an error while a deep link is pending preserves it for after recovery', () {
      final r = resolve(loc: '/care-today', error: true, pending: '/care-today');
      expect(r.location, '/auth-error');
      expect(r.pendingDeepLink, '/care-today');
      // On recovery (resolved+signedIn) from the error screen, it replays.
      final recovered = resolve(loc: '/auth-error', signedIn: true, pending: '/care-today');
      expect(recovered.location, '/care-today');
      expect(recovered.pendingDeepLink, isNull);
    });

    test('a stale transient pending never causes a redirect loop', () {
      // Defensive: if somehow /splash got remembered, replay resolves to home.
      final r = resolve(loc: '/splash', signedIn: true, pending: '/splash');
      expect(r.location, '/');
      expect(r.pendingDeepLink, isNull);
    });
  });

  _redirectWidgetTests();
}

/// The other redirect in `app.dart`: the `_Redirect` widget a route builder
/// returns when it cannot build anything for the current URL (an unknown
/// tracker name, a `/health/diet/*` screen rebuilt with no `extra`).
///
/// It used to `go`, which discards the whole page stack. Now that every
/// signed-in route is nested under `/`, that would throw away exactly what
/// nesting is for. These cases pin BOTH repairs — pop when the page below is
/// already the destination, replace otherwise — because a fix for one of them
/// is what breaks the other.
void _redirectWidgetTests() {
  final testProfile = UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'user@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
    isAdmin: false,
  );

  Future<GoRouter> pumpSignedIn(WidgetTester tester) async {
    final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
    await pumpApp(
      tester,
      authRepository: authRepository,
      loginController: LoginController(SignIn(authRepository)),
      homeController: HomeController(
        GetProfile(FakeProfileRepository(testProfile)),
        SignOut(authRepository),
      ),
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byKey(const Key('health-tile'))));
  }

  String location(GoRouter router) =>
      router.routerDelegate.currentConfiguration.uri.toString();

  group('_Redirect keeps the stack it landed in', () {
    testWidgets(
      'a URL-driven unknown tracker settles on ONE health shell, with home '
      'still underneath',
      (tester) async {
        final router = await pumpSignedIn(tester);

        // URL-driven: the stack is rebuilt as [/, /health, /health/nope].
        // The page below the redirect is already `/health`, so the repair is
        // a pop. A blanket `pushReplacement` would leave [/, /health,
        // /health] — two shells, each loading a screenful of data.
        router.go('/health/nope');
        await tester.pumpAndSettle();

        expect(location(router), '/health');
        expect(find.byType(HealthScaffold), findsOneWidget);
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

        // And the back button reaches home in ONE step — which is only true
        // if there is a single health shell in the stack.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(location(router), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'an unknown tracker pushed from home replaces itself with the health '
      'shell, leaving home underneath',
      (tester) async {
        final router = await pumpSignedIn(tester);

        // In-app: the stack is [/, /health/nope] — nothing below is
        // `/health`, so the repair is a replace. A blanket `pop` would take
        // the user back to home and show nothing at all.
        router.push('/health/nope');
        await tester.pumpAndSettle();

        expect(find.byType(HealthScaffold), findsOneWidget);
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(location(router), '/');
        expect(find.byType(HomeScreen), findsOneWidget);
      },
    );

    testWidgets(
      'it discards only itself — pages pushed below it survive',
      (tester) async {
        final router = await pumpSignedIn(tester);

        // The user walked in: home → finance → (somewhere that could not be
        // built). `go` would collapse all of that and rebuild from
        // `/health` alone, silently deleting the finance page the user
        // expects the back button to return to.
        router.push('/finance');
        await tester.pumpAndSettle();
        router.push('/health/nope');
        await tester.pumpAndSettle();

        expect(find.byType(HealthScaffold), findsOneWidget);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byType(FinanceScaffold),
          findsOneWidget,
          reason: 'the redirect must not discard the page it was pushed over',
        );
      },
    );

    testWidgets(
      'a URL-driven /health/diet/target with no extra falls back to the diet '
      'day it was built over, not past it',
      (tester) async {
        final router = await pumpSignedIn(tester);

        router.go('/health/diet/target');
        await tester.pumpAndSettle();

        expect(location(router), '/health/diet');
        expect(find.byType(DietDayScreen), findsOneWidget);
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      },
    );

    testWidgets(
      'a URL-driven /health/diet/food-search with no extra does the same',
      (tester) async {
        final router = await pumpSignedIn(tester);

        router.go('/health/diet/food-search');
        await tester.pumpAndSettle();

        expect(location(router), '/health/diet');
        expect(find.byType(DietDayScreen), findsOneWidget);
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget);
      },
    );
  });
}
