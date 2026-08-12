import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/finance/application/list_finance_budgets.dart';
import 'package:life_os/contexts/finance/application/networth_use_cases.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/split_repository.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/privacy/privacy_mask_controller.dart';
import 'package:life_os/shared/routing/finance_tab.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';
import 'dashboard_repositories_fake.dart';

class FakeProfileRepository implements ProfileRepository {
  UserProfile? profileToReturn;
  Object? errorToThrow;

  @override
  Future<UserProfile> getProfile(String idToken) async {
    if (errorToThrow != null) throw errorToThrow!;
    return profileToReturn!;
  }
}

class FakeAuthRepository implements AuthRepository {
  @override
  Future<void> sendPasswordReset(String email) async {}

  bool signOutCalled = false;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<ThemeController> testThemeController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ThemeController(prefs);
}

/// A [PrivacyMaskController] backed by mocked prefs, already loaded for [uid].
///
/// Loaded for a real uid by default because a controller with no user refuses
/// to persist — a tile toggle in a test would silently do nothing.
Future<PrivacyMaskController> testPrivacyMaskController({
  Map<String, Object> initialValues = const {},
  String? uid = 'uid-test',
}) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final prefs = await SharedPreferences.getInstance();
  return PrivacyMaskController(prefs)..loadForUser(uid);
}

/// What a `pumpHomeScreen` test can look at afterwards: the router, and the
/// **full location `/finance` was entered with**, query string included.
///
/// The location is recorded by the route builder rather than read back from
/// `routerDelegate.currentConfiguration.uri`, which reports `/` for an
/// imperative `push` — the exact shape that would make a URL guard here pass
/// no matter what the tile linked to.
class HomeHarness {
  final GoRouter router;
  final List<String> financeLocations;

  HomeHarness(this.router, this.financeLocations);
}

Future<HomeHarness> pumpHomeScreen(
  WidgetTester tester,
  HomeController controller, {
  DateTime Function()? clock,
  Locale locale = const Locale('en'),
  AuthRepository? authRepository,
  HomeDashboardController? dashboardController,
  Future<String> Function()? idToken,

  /// Hands the screen a dashboard controller but NO token provider — the
  /// combination where a reload can never run. `idToken: null` cannot express
  /// it, since that is also the default.
  bool omitIdToken = false,
  PrivacyMaskController? privacyMaskController,
}) async {
  final financeLocations = <String>[];
  final localeController = await testLocaleController();
  final resolvedPrivacyMaskController =
      privacyMaskController ?? await testPrivacyMaskController();
  // HomeScreen now navigates by pushing routes (the app router builds the target
  // screens), so give it a router with marker destinations for `/health` and
  // `/settings` to assert the tile/icon navigate there.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(
          controller: controller,
          privacyMaskController: resolvedPrivacyMaskController,
          clock: clock ?? DateTime.now,
          dashboardController: dashboardController,
          idToken: omitIdToken
              ? null
              : (idToken ??
                    (dashboardController == null ? null : () async => 'tok')),
        ),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const Scaffold(body: Text('HEALTH-ROUTE')),
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) {
          financeLocations.add(state.uri.toString());
          return const Scaffold(body: Text('FINANCE-ROUTE'));
        },
      ),
      GoRoute(
        path: '/assistant',
        builder: (context, state) =>
            const Scaffold(body: Text('ASSISTANT-ROUTE')),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) =>
            const Scaffold(body: Text('SETTINGS-ROUTE')),
      ),
    ],
  );
  await tester.pumpWidget(
    AnimatedBuilder(
      animation: localeController,
      builder: (context, _) => MaterialApp.router(
        locale: localeController.locale ?? locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: testSupportedLocales,
        routerConfig: router,
      ),
    ),
  );
  return HomeHarness(router, financeLocations);
}

void main() {
  group('HomeScreen', () {
    testWidgets(
      'uses the loaded name in the greeting and keeps account details off home',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
            isAdmin: false,
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(
          tester,
          controller,
          clock: () => DateTime(2026, 1, 1, 8),
        );

        expect(find.text('Good morning, Test User'), findsOneWidget);
        expect(find.text('test@example.com'), findsNothing);
        expect(find.text('user-1'), findsNothing);
      },
    );

    testWidgets('tapping the health tile navigates to the health route', (
      tester,
    ) async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      await pumpHomeScreen(tester, controller);

      expect(find.text('HEALTH-ROUTE'), findsNothing);

      await tester.tap(find.byKey(const Key('health-tile')));
      await tester.pumpAndSettle();

      // HomeScreen pushes `/health`; the app router builds the module there.
      // The full grid → health → diet flow is covered at the app level.
      expect(find.text('HEALTH-ROUTE'), findsOneWidget);
    });

    testWidgets('tapping the finance tile navigates to the finance route', (
      tester,
    ) async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      await pumpHomeScreen(tester, controller);

      expect(find.text('FINANCE-ROUTE'), findsNothing);

      await tester.tap(find.byKey(const Key('finance-tile')));
      await tester.pumpAndSettle();

      expect(find.text('FINANCE-ROUTE'), findsOneWidget);
    });

    testWidgets(
      'shows a semver build label (defaults to "1.0.0+dev" without CI defines)',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
            isAdmin: false,
          );
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(FakeAuthRepository()),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        expect(find.byKey(const Key('build-label')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('build-label'))).data,
          '1.0.0+dev',
        );
      },
    );

    testWidgets(
      'shows an error state and a sign-out option when the profile request fails',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = const ProfileFetchFailure('server error');
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        expect(find.byKey(const Key('error-message')), findsOneWidget);
        final signOutButton = find.byKey(const Key('sign-out-button'));
        expect(signOutButton, findsOneWidget);

        await tester.tap(signOutButton);
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
      },
    );

    testWidgets(
      'shows the profile-load error message in Traditional Chinese when '
      'that is the active locale',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = const ProfileFetchFailure('server error');
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(
          tester,
          controller,
          locale: const Locale.fromSubtags(
            languageCode: 'zh',
            scriptCode: 'Hant',
          ),
        );

        expect(
          find.text(
            lookupAppLocalizations(
              const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
            ).errorProfileLoadFailed,
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'unexpected errors set a generic, untyped error without leaking the '
      'original exception text',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = Exception(
            'SocketException: Connection refused at 10.0.0.5:443',
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');

        // The error is a typed enum, not a string — it structurally cannot
        // leak exception text.
        expect(controller.error, ProfileError.unknown);
      },
    );

    testWidgets('401 shows a "sign in again" exit rather than a dead end', (
      tester,
    ) async {
      final profileRepository = FakeProfileRepository()
        ..errorToThrow = const ReauthenticationRequired();
      final authRepository = FakeAuthRepository();
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(authRepository),
      );
      await controller.load('token-123');
      await pumpHomeScreen(tester, controller);

      final signInAgainButton = find.byKey(const Key('sign-in-again-button'));
      expect(signInAgainButton, findsOneWidget);

      await tester.tap(signInAgainButton);
      await tester.pumpAndSettle();

      expect(authRepository.signOutCalled, isTrue);
    });

    testWidgets('tapping the settings icon navigates to the settings route', (
      tester,
    ) async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      await pumpHomeScreen(tester, controller);

      expect(find.text('SETTINGS-ROUTE'), findsNothing);

      await tester.tap(find.byKey(const Key('settings-icon-button')));
      await tester.pumpAndSettle();

      expect(find.text('SETTINGS-ROUTE'), findsOneWidget);
    });

    testWidgets(
      'no longer shows a language chip or sign-out button directly on the '
      'loaded home screen (moved into settings)',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
            isAdmin: false,
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        expect(find.byKey(const Key('language-switcher')), findsNothing);
        expect(find.byKey(const Key('sign-out-button')), findsNothing);
      },
    );
  });

  group('HomeScreen assistant bar and space tiles', () {
    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      return controller;
    }

    testWidgets('tapping the assistant bar navigates to the assistant route', (
      tester,
    ) async {
      final controller = await loadedController();
      await pumpHomeScreen(tester, controller);

      expect(find.text('ASSISTANT-ROUTE'), findsNothing);

      await tester.tap(find.byKey(const Key('home-assistant-bar')));
      await tester.pumpAndSettle();

      expect(find.text('ASSISTANT-ROUTE'), findsOneWidget);
    });

    testWidgets('the assistant bar remains visible above dashboard sections', (
      tester,
    ) async {
      final controller = await loadedController();
      await pumpHomeScreen(tester, controller);

      expect(find.byKey(const Key('home-assistant-bar')), findsOneWidget);
      expect(find.byKey(const Key('health-dashboard-section')), findsOneWidget);
      expect(
        find.byKey(const Key('finance-dashboard-section')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('primary-navigation-bar')), findsNothing);
    });

    testWidgets(
      'tasks and journal destinations stay on home and show coming soon',
      (tester) async {
        final controller = await loadedController();
        await pumpHomeScreen(tester, controller);

        await tester.ensureVisible(find.byKey(const Key('tasks-tile')));
        await tester.tap(find.byKey(const Key('tasks-tile')));
        await tester.pump();
        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('HEALTH-ROUTE'), findsNothing);
        expect(find.text('FINANCE-ROUTE'), findsNothing);
        expect(find.text('ASSISTANT-ROUTE'), findsNothing);

        await tester.ensureVisible(find.byKey(const Key('journal-tile')));
        await tester.tap(find.byKey(const Key('journal-tile')));
        await tester.pump();
        expect(find.text('HEALTH-ROUTE'), findsNothing);
        expect(find.text('FINANCE-ROUTE'), findsNothing);
        expect(find.text('ASSISTANT-ROUTE'), findsNothing);
        expect(find.byType(SnackBar), findsOneWidget);
      },
    );

    testWidgets(
      'dashboard hub replaces primary navigation and the spaces grid',
      (tester) async {
        final controller = await loadedController();
        await pumpHomeScreen(tester, controller);

        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('finance-dashboard-section')),
          findsOneWidget,
        );
        expect(find.byKey(const Key('primary-navigation-bar')), findsNothing);
        expect(find.byKey(const Key('spaces-grid')), findsNothing);
        expect(find.byKey(const Key('assistant-tile')), findsNothing);
      },
    );
  });

  group('HomeScreen greeting', () {
    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      return controller;
    }

    testWidgets('shows a morning greeting before noon', (tester) async {
      final controller = await loadedController();
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 8),
      );

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).greetingMorningName('Test User'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows an afternoon greeting from noon until evening', (
      tester,
    ) async {
      final controller = await loadedController();
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 14),
      );

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).greetingAfternoonName('Test User'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows an evening greeting after 6pm', (tester) async {
      final controller = await loadedController();
      await pumpHomeScreen(
        tester,
        controller,
        clock: () => DateTime(2026, 1, 1, 20),
      );

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).greetingEveningName('Test User'),
        ),
        findsOneWidget,
      );
    });
  });

  // ------------------------------------------------------ finance tile targets
  //
  // A snapshot tile must land on the tab that shows the number it just
  // printed, and the tab has to be on the URL (a refresh or a shared link
  // otherwise drops back to 總覽). Both dashboard states are covered: the
  // placeholder is what a cold-start user actually taps, and it used to build
  // its four tiles from one loop with a single shared destination.
  group('finance snapshot tiles open the tab their number lives on', () {
    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      return controller;
    }

    Future<void> tapTile(WidgetTester tester, Key key) async {
      await tester.ensureVisible(find.byKey(key));
      await tester.tap(find.byKey(key));
      await tester.pumpAndSettle();
    }

    /// `false` = the `dashboard == null` placeholder block; `true` = the
    /// loaded block. Both are run because they are two separate lists of
    /// tiles in the source, and only one of them is what a cold start shows.
    for (final loaded in [false, true]) {
      final state = loaded ? 'loaded dashboard' : 'placeholder dashboard';

      Future<HomeHarness> pump(WidgetTester tester) async {
        final harness = await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: loaded ? loadedDashboardFixture() : null,
        );
        if (loaded) {
          // The fixture prints real figures, so "the loaded block rendered"
          // cannot be satisfied by the 無資料 placeholder wearing the same
          // keys — i.e. this loop really does cover two different blocks.
          expect(find.text('530,900'), findsOneWidget); // 淨值
          expect(find.text('456,700'), findsOneWidget); // 總負債
        } else {
          expect(find.text('530,900'), findsNothing);
        }
        return harness;
      }

      testWidgets('$state: 淨值 opens /finance?tab=networth', (tester) async {
        final harness = await pump(tester);
        await tapTile(tester, const Key('home-net-worth'));
        expect(harness.financeLocations, ['/finance?tab=networth']);
      });

      testWidgets('$state: 總負債 opens /finance?tab=networth', (tester) async {
        final harness = await pump(tester);
        await tapTile(tester, const Key('home-total-liabilities'));
        expect(harness.financeLocations, ['/finance?tab=networth']);
      });

      testWidgets('$state: 分帳總覽 opens /finance?tab=split', (tester) async {
        final harness = await pump(tester);
        await tapTile(tester, const Key('home-split-overview'));
        expect(harness.financeLocations, ['/finance?tab=split']);
      });

      testWidgets('$state: 預算 and the 開啟財務 button stay on a bare /finance', (
        tester,
      ) async {
        // The reverse case. Without it, "append ?tab=networth to every
        // finance tile" passes the three tests above.
        final harness = await pump(tester);
        await tapTile(tester, const Key('home-budget'));
        expect(
          harness.financeLocations,
          ['/finance'],
          reason: '預算 lives on 總覽, the shell default — no query string',
        );

        harness.router.go('/');
        await tester.pumpAndSettle();
        harness.financeLocations.clear();

        await tapTile(tester, const Key('finance-tile'));
        expect(harness.financeLocations, ['/finance']);
      });
    }

    testWidgets(
      'the tile destinations are built from FinanceTab, not hand-written',
      (tester) async {
        // Pins the tiles to the same vocabulary the route builder parses: a
        // hand-typed '?tab=net-worth' would satisfy a `contains('networth')`
        // check and still land on 總覽 in production.
        final harness = await pumpHomeScreen(tester, await loadedController());
        await tapTile(tester, const Key('home-net-worth'));

        final uri = Uri.parse(harness.financeLocations.single);
        expect(uri.path, FinanceTab.financeLocation);
        expect(
          FinanceTab.fromSlug(uri.queryParameters[FinanceTab.queryParameter]),
          FinanceTab.networth,
        );
      },
    );
  });

  // ------------------------------------------------------------------ 淨值 tile
  //
  // LINCHPIN: the tile prints net worth (assets minus liabilities), not the
  // gross total assets it used to print — and a negative net worth, which the
  // gross figure never was, has to be grouped correctly.
  group('the 淨值 tile', () {
    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      return controller;
    }

    testWidgets('prints net worth, and total assets no longer appear at all', (
      tester,
    ) async {
      await pumpHomeScreen(
        tester,
        await loadedController(),
        dashboardController: loadedDashboardFixture(),
      );

      // 987,600 is the fixture's totalAsset and 530,900 its netWorth — three
      // distinct numbers, so this cannot pass by accident.
      expect(find.text('530,900'), findsOneWidget);
      expect(find.text('987,600'), findsNothing);
    });

    testWidgets('groups a negative net worth without a stray comma', (
      tester,
    ) async {
      final dashboard = loadedDashboardFixture();
      final data = dashboard.data!;
      dashboard.data = HomeDashboardData(
        weightGoal: data.weightGoal,
        bloodPressure: data.bloodPressure,
        menstrualStatus: data.menstrualStatus,
        overallBudget: data.overallBudget,
        // Six digits on purpose: only a digit count divisible by three catches
        // a negative fed straight into formatMinorUnitsForDisplay ("-,356,700").
        netWorth: const MonthlyNetWorth(
          month: '2026-01',
          accounts: [],
          totalAsset: 100000,
          totalLiability: 456700,
          netWorth: -356700,
          prevNetWorth: null,
          growthRate: null,
        ),
        splitBalances: data.splitBalances,
      );

      await pumpHomeScreen(
        tester,
        await loadedController(),
        dashboardController: dashboard,
      );

      expect(find.text('-356,700'), findsOneWidget);
    });
  });

  // ------------------------------------------------------------ pull-to-refresh
  //
  // Unlike `loadedDashboardFixture()` above, this group drives the real
  // six-request fan-out through `FakeDashboardRepositories`, because what is
  // under test *is* the reload: which token it carries, when its future
  // settles, and what the screen shows while and after it runs.
  group('HomeScreen pull-to-refresh', () {
    final loc = lookupAppLocalizations(const Locale('en'));

    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
          isAdmin: false,
        );
      final controller = HomeController(
        GetProfile(profileRepository),
        SignOut(FakeAuthRepository()),
      );
      await controller.load('token-123');
      return controller;
    }

    HomeDashboardController dashboardFor(FakeDashboardRepositories repos) =>
        HomeDashboardController(
          GetWeightGoal(repos),
          GetVitalsTrends(repos),
          GetMenstrualOverview(repos),
          ListFinanceBudgets(repos),
          GetMonthlyNetWorth(repos),
          GetBalances(repos),
        );

    RefreshIndicator indicator(WidgetTester tester) =>
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));

    testWidgets(
      'the loaded home wraps its scroll view in one RefreshIndicator whose '
      'scrollable always accepts an overscroll pull (a short home still '
      'refreshes)',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
        );

        expect(find.byType(RefreshIndicator), findsOneWidget);
        final scrollView = tester.widget<SingleChildScrollView>(
          find.descendant(
            of: find.byType(RefreshIndicator),
            matching: find.byType(SingleChildScrollView),
          ),
        );
        expect(scrollView.physics, isA<AlwaysScrollableScrollPhysics>());
      },
    );

    testWidgets(
      'the app bar carries a refresh button for keyboard/mouse users who '
      'cannot pull-to-refresh, wired to the same reload as the gesture',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
        );

        final button = find.byKey(const Key('home-refresh-button'));
        expect(button, findsOneWidget);

        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(repos.rounds, 2);
      },
    );

    testWidgets(
      'LINCHPIN: the refresh button stays enabled (and so stays focusable) '
      'while a round runs, showing a spinner in place of its icon',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
        );

        final button = find.byKey(const Key('home-refresh-button'));
        final gate = Completer<void>();
        repos.gate = gate;
        await tester.tap(button);
        await tester.pump();

        // Disabling it drops keyboard focus mid-round and never gives it back,
        // so a keyboard user has to Tab the whole page again. `load` already
        // dedupes concurrent rounds, so there is nothing to protect here.
        expect(
          tester.widget<IconButton>(button).onPressed,
          isNotNull,
          reason: 'a disabled IconButton cannot hold keyboard focus',
        );
        expect(
          find.descendant(
            of: button,
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
          reason: 'the button must still SAY a reload is running',
        );
        expect(
          find.descendant(of: button, matching: find.byIcon(Icons.refresh)),
          findsNothing,
        );

        // And pressing it again while it runs does not start a second fan-out.
        await tester.tap(button);
        await tester.pump();
        expect(repos.rounds, 2);

        gate.complete();
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: button, matching: find.byIcon(Icons.refresh)),
          findsOneWidget,
          reason: 'the icon comes back once the round lands',
        );
      },
    );

    testWidgets(
      'LINCHPIN: no refresh button when there is no token to reload with — '
      'the button appears exactly when a press can do something',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          omitIdToken: true,
        );

        expect(
          find.byKey(const Key('home-refresh-button')),
          findsNothing,
          reason:
              '_refreshDashboard returns immediately without a token, so '
              'this button would be dead on arrival',
        );
      },
    );

    testWidgets(
      'a pull after a token renewal refetches with the freshly resolved token',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        var token = 'token-1';
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          idToken: () async => token,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );
        expect(repos.goalTokens, ['token-1']);

        // Firebase renewed the token while home stayed mounted.
        token = 'token-2';
        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();

        expect(repos.goalTokens, ['token-1', 'token-2']);
      },
    );

    testWidgets('the gesture future settles only when the reload finishes', (
      tester,
    ) async {
      final repos = FakeDashboardRepositories();
      final dashboard = dashboardFor(repos);
      await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
      await pumpHomeScreen(
        tester,
        await loadedController(),
        dashboardController: dashboard,
        clock: () => DateTime(2026, 1, 1, 11, 45),
      );

      final gate = Completer<void>();
      repos.gate = gate;
      var settled = false;
      unawaited(indicator(tester).onRefresh().then((_) => settled = true));
      await tester.pump();

      expect(repos.rounds, 2);
      expect(
        settled,
        isFalse,
        reason: 'the spinner stopped before the reload finished',
      );

      gate.complete();
      await tester.pumpAndSettle();
      expect(settled, isTrue);
    });

    testWidgets(
      'a token fetch that throws during a pull still settles the gesture '
      '(the spinner never hangs forever)',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          idToken: () async => throw StateError('token renewal failed'),
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );

        // Awaiting it is the assertion: an unswallowed throw fails the test
        // here, and in production leaves the pull spinner turning forever.
        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();

        expect(repos.rounds, 1, reason: 'no round can run without a token');
        expect(find.text(loc.lastUpdatedAt('09:30')), findsOneWidget);
      },
    );

    testWidgets('the label shows when the dashboard last loaded', (
      tester,
    ) async {
      final repos = FakeDashboardRepositories();
      final dashboard = dashboardFor(repos);
      await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
      await pumpHomeScreen(
        tester,
        await loadedController(),
        dashboardController: dashboard,
      );

      expect(find.text(loc.lastUpdatedAt('09:30')), findsOneWidget);
    });

    testWidgets('a successful refresh advances the label', (tester) async {
      final repos = FakeDashboardRepositories();
      final dashboard = dashboardFor(repos);
      await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
      await pumpHomeScreen(
        tester,
        await loadedController(),
        dashboardController: dashboard,
        clock: () => DateTime(2026, 1, 1, 11, 45),
      );

      await indicator(tester).onRefresh();
      await tester.pumpAndSettle();

      expect(find.text(loc.lastUpdatedAt('11:45')), findsOneWidget);
      expect(find.text(loc.lastUpdatedAt('09:30')), findsNothing);
    });

    testWidgets(
      'LINCHPIN: a refresh that fails leaves the label on the OLD time and '
      'keeps the figures on screen behind a stale notice',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );

        repos.fail = true;
        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();

        // The exact old time, not merely "non-null": stamping the clock
        // unconditionally would still leave a label on screen.
        expect(dashboard.lastLoadedAt, DateTime(2026, 1, 1, 9, 30));
        expect(find.text(loc.lastUpdatedAt('09:30')), findsOneWidget);
        expect(find.text(loc.lastUpdatedAt('11:45')), findsNothing);

        // The stale figures stay, marked as stale — the whole screen must not
        // become the first-load "couldn't load your dashboard" card.
        expect(find.text('530,900'), findsOneWidget);
        expect(find.byKey(const Key('stale-notice-row')), findsOneWidget);
        expect(find.text(loc.homeDashboardLoadFailed), findsNothing);
      },
    );

    testWidgets(
      'the stale notice sits above the fold on a phone-sized viewport, and '
      'names the dashboard rather than the whole app',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );

        repos.fail = true;
        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();

        final noticeTop = tester
            .getTopLeft(find.byKey(const Key('stale-notice-row')))
            .dy;
        expect(
          noticeTop,
          lessThan(844),
          reason: 'a failed refresh must be visible without scrolling',
        );
        // Not `loc.appTitle`: the notice's contract is the card's own title,
        // and the app name in its screen-reader label would read as "the
        // whole app is broken" rather than naming just the dashboard.
        expect(
          find.bySemanticsLabel(
            '${loc.homeDashboardTitle}: ${loc.cardRefreshFailed}. ${loc.retry}',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a refresh in flight does not blank the figures already on screen',
      (tester) async {
        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );

        final gate = Completer<void>();
        repos.gate = gate;
        unawaited(indicator(tester).onRefresh());
        await tester.pump();

        expect(dashboard.status, HomeDashboardStatus.loading);
        expect(find.byKey(const Key('home-latest-weight')), findsOneWidget);
        expect(
          find.byKey(const Key('health-dashboard-section')),
          findsOneWidget,
        );
        expect(find.text('530,900'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
          reason: 'the reload replaced the dashboard with a spinner',
        );

        gate.complete();
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'the first load failing with no data still shows the unavailable card',
      (tester) async {
        // The other side of the stale-data decision: with nothing on screen
        // to keep, the error card (and its retry) is still the right state.
        final repos = FakeDashboardRepositories()..fail = true;
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
        );

        expect(find.text(loc.homeDashboardLoadFailed), findsOneWidget);
        expect(find.byKey(const Key('stale-notice-row')), findsNothing);
        expect(find.text(loc.lastUpdatedAt('09:30')), findsNothing);
      },
    );

    testWidgets(
      'LINCHPIN: the stale notice starts on the same left edge as the rest of '
      'the page (its own padding must not stack on the page padding)',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );

        repos.fail = true;
        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();

        final noticeLeft = tester
            .getTopLeft(find.byIcon(Icons.cloud_off_outlined))
            .dx;
        final greetingLeft = tester
            .getTopLeft(find.byKey(const Key('home-greeting')))
            .dx;
        expect(
          noticeLeft,
          greetingLeft,
          reason: 'the notice is indented past every other line on the page',
        );
        // And its tappable row runs the full width of the page rather than
        // floating rounded corners over the page ground.
        final rowLeft = tester
            .getTopLeft(find.byKey(const Key('stale-notice-row')))
            .dx;
        expect(rowLeft, 0);
      },
    );

    testWidgets(
      'LINCHPIN: a real overscroll pull — not a hand-called onRefresh — runs '
      'a round and advances the timestamp',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.binding.setSurfaceSize(const Size(390, 844));

        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );
        expect(repos.rounds, 1);

        // Every other test here calls `onRefresh()` directly, which passes
        // even if the RefreshIndicator sits somewhere the overscroll never
        // reaches. This one drags the actual scrollable.
        await tester.fling(
          find.byType(SingleChildScrollView),
          const Offset(0, 350),
          1000,
        );
        await tester.pumpAndSettle();

        expect(repos.rounds, 2, reason: 'the pull started no reload');
        expect(dashboard.lastLoadedAt, DateTime(2026, 1, 1, 11, 45));
        expect(find.text(loc.lastUpdatedAt('11:45')), findsOneWidget);
      },
    );

    testWidgets('the pull gesture carries a screen-reader label', (
      tester,
    ) async {
      final repos = FakeDashboardRepositories();
      final dashboard = dashboardFor(repos);
      await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
      await pumpHomeScreen(
        tester,
        await loadedController(),
        dashboardController: dashboard,
      );

      expect(indicator(tester).semanticsLabel, loc.homeRefreshTooltip);
    });

    testWidgets(
      'LINCHPIN: a finished refresh announces itself — the new time on '
      'success, the failure copy on failure',
      (tester) async {
        final announced = _captureAnnouncements(tester);

        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );
        expect(announced, isEmpty, reason: 'nothing was refreshed yet');

        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();
        expect(announced, [loc.lastUpdatedAt('11:45')]);

        repos.fail = true;
        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();
        expect(announced, [loc.lastUpdatedAt('11:45'), loc.cardRefreshFailed]);
      },
    );

    testWidgets(
      'a refresh whose token renewal throws announces the failure, not a '
      'success carrying the old timestamp',
      (tester) async {
        final announced = _captureAnnouncements(tester);

        final repos = FakeDashboardRepositories();
        final dashboard = dashboardFor(repos);
        await dashboard.load('token-1', DateTime(2026, 1, 1, 9, 30));
        await pumpHomeScreen(
          tester,
          await loadedController(),
          dashboardController: dashboard,
          idToken: () async => throw StateError('token renewal failed'),
          clock: () => DateTime(2026, 1, 1, 11, 45),
        );

        await indicator(tester).onRefresh();
        await tester.pumpAndSettle();

        expect(announced, [loc.cardRefreshFailed]);
      },
    );
  });
}

/// Collects what the screen sends to the platform's accessibility channel —
/// what `SemanticsService.announce` actually puts on the wire, rather than a
/// spy wrapped around the call site.
List<String> _captureAnnouncements(WidgetTester tester) {
  final announced = <String>[];
  tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
    SystemChannels.accessibility,
    (message) async {
      final event = message! as Map<Object?, Object?>;
      if (event['type'] == 'announce') {
        final data = event['data']! as Map<Object?, Object?>;
        announced.add(data['message']! as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<Object?>(
          SystemChannels.accessibility,
          null,
        ),
  );
  return announced;
}

/// A [HomeDashboardController] already in its loaded state, with figures the
/// tiles actually print — so a tile that renders is distinguishable from the
/// 無資料 placeholder wearing the same key.
///
/// Assigned rather than loaded: `load` is a six-request fan-out and none of
/// those six requests is what these tests are about.
HomeDashboardController loadedDashboardFixture() {
  final unused = _UnusedRepositories();
  return HomeDashboardController(
      GetWeightGoal(unused),
      GetVitalsTrends(unused),
      GetMenstrualOverview(unused),
      ListFinanceBudgets(unused),
      GetMonthlyNetWorth(unused),
      GetBalances(unused),
    )
    ..status = HomeDashboardStatus.loaded
    ..data = const HomeDashboardData(
      weightGoal: WeightGoal(currentWeightKg: 62.5),
      bloodPressure: null,
      menstrualStatus: NextPeriodStatus(state: NextPeriodState.noRecords),
      overallBudget: FinanceBudget(
        id: 'b1',
        categoryId: null,
        amount: 500000,
        spent: 377600,
        remaining: 123400,
        percent: 76,
      ),
      netWorth: MonthlyNetWorth(
        month: '2026-01',
        accounts: [],
        totalAsset: 987600,
        totalLiability: 456700,
        netWorth: 530900,
        prevNetWorth: null,
        growthRate: null,
      ),
      splitBalances: [
        Balance(
          userId: 'friend-1',
          displayName: 'Friend',
          balances: [CurrencyBalance(currency: 'TWD', amount: 55500)],
        ),
      ],
    );
}

/// The three repositories behind the dashboard arms this fixture never runs.
/// Throws rather than returning empties: if a future change makes the loaded
/// fixture actually fetch, that must be loud, not silently blank.
class _UnusedRepositories
    implements
        BodyProfileRepository,
        VitalsRepository,
        MenstrualRepository,
        FinanceRepository,
        SplitRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError(
    'the loaded dashboard fixture is assigned directly, never fetched',
  );
}
