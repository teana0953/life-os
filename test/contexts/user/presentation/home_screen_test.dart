import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

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

Future<void> pumpHomeScreen(
  WidgetTester tester,
  HomeController controller, {
  DateTime Function()? clock,
  Locale locale = const Locale('en'),
  AuthRepository? authRepository,
}) async {
  final localeController = await testLocaleController();
  // HomeScreen now navigates by pushing routes (the app router builds the target
  // screens), so give it a router with marker destinations for `/health` and
  // `/settings` to assert the tile/icon navigate there.
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) =>
            HomeScreen(controller: controller, clock: clock ?? DateTime.now),
      ),
      GoRoute(
        path: '/health',
        builder: (context, state) => const Scaffold(body: Text('HEALTH-ROUTE')),
      ),
      GoRoute(
        path: '/finance',
        builder: (context, state) =>
            const Scaffold(body: Text('FINANCE-ROUTE')),
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
}
