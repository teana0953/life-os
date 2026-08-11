import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import 'app_test.dart';

/// The home hub's dashboard is a six-request fan-out (weight goal, vitals
/// trends, menstrual, budgets, net worth, split balances) that paints nothing
/// unless home is the visible page. A PWA launcher shortcut or a push deep
/// link builds home underneath the destination and then never shows it — so
/// those six requests used to go out on every such cold start, competing for
/// the connection with the one screen the user actually asked for.
///
/// Both directions are pinned here: it must not fire when home is merely in
/// the stack, and it must still fire when home IS the page (which is what a
/// too-eager "defer" would break).
void main() {
  final testProfile = UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'user@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
    isAdmin: false,
  );

  /// Counts the weight-goal read — one arm of the fan-out, and enough to tell
  /// "the batch went out" from "it did not".
  late _CountingBodyProfileRepository bodyProfile;

  HomeDashboardController buildDashboard() {
    bodyProfile = _CountingBodyProfileRepository();
    return testHomeDashboardController(bodyProfileRepository: bodyProfile);
  }

  Future<GoRouter> pumpSignedIn(
    WidgetTester tester,
    HomeDashboardController dashboard, {
    FakeAuthRepository? auth,
  }) async {
    final authRepository = auth ?? FakeAuthRepository(initiallyAuthenticated: true);
    await pumpApp(
      tester,
      authRepository: authRepository,
      loginController: LoginController(SignIn(authRepository)),
      homeController: HomeController(
        GetProfile(FakeProfileRepository(testProfile)),
        SignOut(authRepository),
      ),
      homeDashboardController: dashboard,
    );
    await tester.pumpAndSettle();
    return GoRouter.of(tester.element(find.byKey(const Key('health-tile'))));
  }

  testWidgets('landing on home loads the dashboard', (tester) async {
    final dashboard = buildDashboard();
    await pumpSignedIn(tester, dashboard);

    // The ordinary cold start: home IS the page. Deferring must not turn into
    // never loading — this is the assertion a too-aggressive gate breaks.
    expect(bodyProfile.reads, 1);
    expect(dashboard.status, isNot(HomeDashboardStatus.idle));
  });

  testWidgets(
    'a cold start deep-linked past home does not fire the fan-out, and '
    'returning to home does',
    (tester) async {
      final dashboard = buildDashboard();
      final router = await pumpSignedIn(tester, dashboard);
      // Undo the ordinary landing so this test starts from a clean count:
      // `go` below is the deep link, and what matters is what happens FROM
      // there. (`reset()` is exactly what sign-out does.)
      dashboard.reset();
      bodyProfile.reads = 0;

      // The launcher shortcut / push deep link: home is built underneath, but
      // the vitals screen is what the user is looking at.
      router.go('/health/vitals');
      await tester.pumpAndSettle();

      expect(
        bodyProfile.reads,
        0,
        reason:
            'the dashboard must not fetch while its screen is buried under '
            'the deep-linked destination',
      );
      expect(dashboard.status, HomeDashboardStatus.idle);

      // Walking back down to home — the whole point of nesting the routes —
      // is when it becomes worth fetching.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');

      expect(
        bodyProfile.reads,
        1,
        reason: 'arriving on home is what triggers the fan-out',
      );
    },
  );

  testWidgets(
    '"home is visible" means the top of the stack, not the URL — an '
    'imperative push leaves the URL on / while the user is elsewhere',
    (tester) async {
      final dashboard = buildDashboard();
      final router = await pumpSignedIn(tester, dashboard);
      dashboard.reset();
      bodyProfile.reads = 0;

      // `push` deliberately does not change `currentConfiguration.uri`, which
      // still reads `/` from here on. A visibility check written against the
      // URI would therefore call this "home is showing" and fire the fan-out
      // over a screen the user is actually looking at.
      router.push('/settings');
      await tester.pumpAndSettle();

      expect(
        router.routerDelegate.currentConfiguration.uri.toString(),
        '/',
        reason: 'this is the trap: the URI has NOT moved',
      );
      expect(
        bodyProfile.reads,
        0,
        reason: 'settings is on top — home is not the visible page',
      );
    },
  );

  testWidgets(
    'home never paints "no data yet" figures while the deferred fan-out is '
    'still idle',
    (tester) async {
      final loc = lookupAppLocalizations(const Locale('en'));
      final dashboard = buildDashboard();
      // The delay is the whole point of this test. `idToken()` reaches the
      // network whenever the cached token is close to expiring — exactly the
      // situation on a cold start — and the deferred fan-out cannot start
      // until it lands. With the harness default (zero delay) the idle window
      // closes before the first `pump` and this test cannot fail no matter
      // what home paints.
      final auth = FakeAuthRepository(initiallyAuthenticated: true)
        ..idTokenDelay = const Duration(milliseconds: 300);
      final router = await pumpSignedIn(tester, dashboard, auth: auth);
      dashboard.reset();
      bodyProfile.reads = 0;

      // Cold-start shape: the user lands past home and walks back down to it.
      // The profile (`/api/me`) is loaded by then, so home is out of its own
      // full-page spinner and its BODY is what the user reads.
      router.go('/health/vitals');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      await tester.binding.handlePopRoute();
      var idleMs = 0;
      while (idleMs < 300) {
        await tester.pump(const Duration(milliseconds: 20));
        if (dashboard.status != HomeDashboardStatus.idle) break;
        expect(
          find.byKey(const Key('build-label')),
          findsOneWidget,
          reason: 'home\'s loaded body is what is on screen during this gap',
        );
        expect(
          find.text(loc.homeNoData),
          findsNothing,
          reason:
              'the figures have not been fetched yet — telling a user with '
              'records that they have none is worse than showing nothing',
        );
        idleMs += 20;
      }
      expect(
        idleMs,
        greaterThanOrEqualTo(200),
        reason:
            'the assertions above must have run against a REAL idle window; '
            'if the token resolves instantly there is nothing to observe and '
            'this guard proves nothing',
      );

      await tester.pumpAndSettle();
      expect(bodyProfile.reads, 1);
      expect(find.byKey(const Key('home-latest-weight')), findsOneWidget);
    },
  );

  testWidgets(
    'pushing away from home and coming back does not re-fire the fan-out',
    (tester) async {
      final dashboard = buildDashboard();
      final router = await pumpSignedIn(tester, dashboard);
      expect(bodyProfile.reads, 1);

      router.push('/settings');
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // The controller is no longer `idle`, so every later return to home is
      // free. Without that check this listener would refetch six endpoints on
      // every single back-navigation.
      expect(bodyProfile.reads, 1);
    },
  );
}

class _CountingBodyProfileRepository implements BodyProfileRepository {
  int reads = 0;

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    reads++;
    return const WeightGoal();
  }

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async =>
      const BodyProfile();

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async => const BodyProfile();
}
