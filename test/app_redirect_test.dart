import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';

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
}
