import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/l10n_test_app.dart';

class FakeAuthRepository implements AuthRepository {
  static const validEmail = 'user@example.com';
  static const validPassword = 'correct-password';

  FakeAuthRepository({bool initiallyAuthenticated = false})
      : _isAuthenticated = initiallyAuthenticated;

  bool _isAuthenticated;
  bool signOutCalled = false;
  final _controller = StreamController<bool>.broadcast();

  @override
  Future<void> signIn(String email, String password) async {
    if (email != validEmail || password != validPassword) {
      throw const AuthFailure(AuthFailureCode.invalidCredentials);
    }
    _isAuthenticated = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    signOutCalled = true;
    _isAuthenticated = false;
    _controller.add(false);
  }

  @override
  Future<String?> idToken() async => _isAuthenticated ? 'fake-token' : null;

  @override
  Stream<bool> get authStateChanges async* {
    yield _isAuthenticated;
    yield* _controller.stream;
  }
}

class ErroringAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges =>
      Stream<bool>.error(Exception('boom: internal stream detail'));
}

class FakeProfileRepository implements ProfileRepository {
  final UserProfile profile;

  FakeProfileRepository(this.profile);

  @override
  Future<UserProfile> getProfile(String idToken) async => profile;
}

final _testProfile = UserProfile(
  id: 'user-1',
  firebaseUid: 'firebase-abc',
  email: 'user@example.com',
  displayName: 'Test User',
  createdAt: '2026-01-01T00:00:00.000Z',
);

/// Pumps [App], wiring in a [LocaleController] (defaulting to a fresh one
/// that follows the system locale, or [localeController] if provided).
/// Returns the [LocaleController] used, so tests can drive it directly.
Future<ThemeController> testThemeController() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ThemeController(prefs);
}

/// Pumps [App], wiring in a [LocaleController] (defaulting to a fresh one
/// that follows the system locale, or [localeController] if provided).
/// Returns the [LocaleController] used, so tests can drive it directly.
Future<LocaleController> pumpApp(
  WidgetTester tester, {
  required AuthRepository authRepository,
  required LoginController loginController,
  required HomeController homeController,
  LocaleController? localeController,
  ThemeController? themeController,
  SignOut? signOut,
}) async {
  final resolvedLocaleController =
      localeController ?? await testLocaleController();
  final resolvedThemeController =
      themeController ?? await testThemeController();
  final resolvedSignOut = signOut ?? SignOut(authRepository);
  await tester.pumpWidget(
    App(
      authRepository: authRepository,
      loginController: loginController,
      homeController: homeController,
      localeController: resolvedLocaleController,
      themeController: resolvedThemeController,
      signOut: resolvedSignOut,
    ),
  );
  return resolvedLocaleController;
}

void main() {
  group('App auth-state routing', () {
    testWidgets('starts unauthenticated shows the login screen', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('email-field')), findsOneWidget);
    });

    testWidgets(
      'starts authenticated fetches the profile and shows the home screen',
      (tester) async {
        final authRepository = FakeAuthRepository(initiallyAuthenticated: true);
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('user@example.com'), findsOneWidget);
        expect(find.text('user-1'), findsOneWidget);
      },
    );

    testWidgets('successful sign-in transitions to the home screen', (
      tester,
    ) async {
      final authRepository = FakeAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const Key('email-field')),
        FakeAuthRepository.validEmail,
      );
      await tester.enterText(
        find.byKey(const Key('password-field')),
        FakeAuthRepository.validPassword,
      );
      await tester.tap(find.byKey(const Key('submit-button')));
      await tester.pumpAndSettle();

      expect(find.text('user@example.com'), findsOneWidget);
      expect(find.text('user-1'), findsOneWidget);
    });

    testWidgets(
      'sign-out from settings returns to the login screen',
      (tester) async {
        final authRepository = FakeAuthRepository(
          initiallyAuthenticated: true,
        );
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('settings-icon-button')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('settings-sign-out-button')),
        );
        await tester.tap(find.byKey(const Key('settings-sign-out-button')));
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
        expect(find.byKey(const Key('email-field')), findsOneWidget);
      },
    );

    testWidgets(
      'auth stream error shows a recoverable error screen instead of an '
      'infinite spinner',
      (tester) async {
        final authRepository = ErroringAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(find.byKey(const Key('auth-retry-button')), findsOneWidget);
      },
    );
  });

  group('App theming', () {
    testWidgets(
      'wires light/dark Material 3 themes and follows the system',
      (tester) async {
        final authRepository = FakeAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pump();

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );

        expect(materialApp.theme!.useMaterial3, isTrue);
        expect(materialApp.theme!.colorScheme.primary, hachiwareBlue);
        expect(materialApp.theme!.colorScheme.brightness, Brightness.light);
        expect(materialApp.darkTheme!.useMaterial3, isTrue);
        expect(materialApp.darkTheme!.colorScheme.primary, hachiwareBlue);
        expect(
          materialApp.darkTheme!.colorScheme.brightness,
          Brightness.dark,
        );
        expect(materialApp.themeMode, ThemeMode.system);
      },
    );

    testWidgets(
      'themeMode follows the injected ThemeController and updates the '
      'MaterialApp on change',
      (tester) async {
        final authRepository = FakeAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        final themeController = await testThemeController();
        await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
          themeController: themeController,
        );
        await tester.pump();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.system,
        );

        await themeController.setThemeMode(ThemeMode.dark);
        await tester.pump();

        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
          ThemeMode.dark,
        );
      },
    );
  });

  group('App i18n', () {
    testWidgets('unsupported system locale falls back to English', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('fr');
      tester.platformDispatcher.localesTestValue = const [Locale('fr')];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final authRepository = ErroringAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pump();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('supported zh-Hant system locale shows Traditional Chinese', (
      tester,
    ) async {
      const zhHant = Locale.fromSubtags(
        languageCode: 'zh',
        scriptCode: 'Hant',
      );
      tester.platformDispatcher.localeTestValue = zhHant;
      tester.platformDispatcher.localesTestValue = [zhHant];
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);

      final authRepository = ErroringAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
      );
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
    });

    testWidgets(
      'switching the locale via the controller updates the UI immediately',
      (tester) async {
        final authRepository = ErroringAuthRepository();
        final profileRepository = FakeProfileRepository(_testProfile);
        final localeController = await pumpApp(
          tester,
          authRepository: authRepository,
          loginController: LoginController(SignIn(authRepository)),
          homeController: HomeController(
            GetProfile(profileRepository),
            SignOut(authRepository),
          ),
        );
        await tester.pump();
        expect(find.text('Retry'), findsOneWidget);

        await localeController.setLocale(
          const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
        );
        await tester.pump();

        expect(find.text('重試'), findsOneWidget);
        expect(find.text('Retry'), findsNothing);
      },
    );

    testWidgets('a persisted language choice overrides the system locale', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'locale_language_code': 'zh'});
      final prefs = await SharedPreferences.getInstance();
      final localeController = LocaleController(prefs);
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);

      final authRepository = ErroringAuthRepository();
      final profileRepository = FakeProfileRepository(_testProfile);
      await pumpApp(
        tester,
        authRepository: authRepository,
        loginController: LoginController(SignIn(authRepository)),
        homeController: HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        ),
        localeController: localeController,
      );
      await tester.pump();

      expect(find.text('重試'), findsOneWidget);
    });
  });
}
