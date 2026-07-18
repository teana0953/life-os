import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/app.dart';
import 'package:life_os/contexts/auth/application/sign_in.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_exceptions.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/auth/presentation/login_controller.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/shared/i18n/locale_controller.dart';
import 'package:life_os/shared/theme/app_colors.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/l10n_test_app.dart';

class _FakeFoodDictionaryRepository implements FoodDictionaryRepository {
  @override
  Future<List<FoodItem>> search(String idToken, String query) async => [];

  @override
  Future<List<FoodItem>> listFavorites(String idToken) async => [];

  @override
  Future<void> favorite(String idToken, String foodItemId) async {}

  @override
  Future<void> unfavorite(String idToken, String foodItemId) async {}
}

class _FakeDietLogRepository implements DietLogRepository {
  @override
  Future<FoodEntry> logFromDictionary(
    String idToken, {
    required String day,
    required String meal,
    required String foodItemId,
    double? quantity,
    double? grams,
    DateTime? eatenAt,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<DayDietLog> getDayLog(String idToken, String day) async {
    return DayDietLog.fromJson({
      'day': day,
      'meals': [],
      'totals': {'carbG': 0, 'proteinG': 0, 'fatG': 0, 'sugarG': 0, 'fiberG': 0, 'kcal': 0},
    });
  }

  @override
  Future<void> deleteEntry(String idToken, String entryId) async {}
}

class _FakeDailyTargetRepository implements DailyTargetRepository {
  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return DailyTargetWithRemaining.fromJson({
      'day': day,
      'base': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'logged': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
      'remaining': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
    });
  }

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) async {
    throw UnimplementedError();
  }
}

/// Builds a fresh set of fake-backed health controllers for wiring [App] in
/// tests that don't exercise the diet module themselves.
({
  TodayController today,
  DictionaryController dictionary,
  DailyTargetController dailyTarget,
  LogEntryController logEntry,
}) testHealthControllers() {
  final dietLogRepository = _FakeDietLogRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final foodDictionaryRepository = _FakeFoodDictionaryRepository();
  return (
    today: TodayController(
      GetDayDietLog(dietLogRepository),
      GetDailyTargetWithRemaining(dailyTargetRepository),
    ),
    dictionary: DictionaryController(
      SearchDictionary(foodDictionaryRepository),
      ListFavorites(foodDictionaryRepository),
      FavoriteFood(foodDictionaryRepository),
      UnfavoriteFood(foodDictionaryRepository),
    ),
    dailyTarget: DailyTargetController(
      GetDailyTargetWithRemaining(dailyTargetRepository),
      SetDailyTarget(dailyTargetRepository),
    ),
    logEntry: LogEntryController(LogFoodFromDictionary(dietLogRepository)),
  );
}

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

/// Builds a fresh [ThemeController] backed by an empty, mocked
/// [SharedPreferences] instance (so it defaults to [ThemeMode.system]).
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
  final health = testHealthControllers();
  await tester.pumpWidget(
    App(
      authRepository: authRepository,
      loginController: loginController,
      homeController: homeController,
      localeController: resolvedLocaleController,
      themeController: resolvedThemeController,
      signOut: resolvedSignOut,
      healthTodayController: health.today,
      healthDictionaryController: health.dictionary,
      healthDailyTargetController: health.dailyTarget,
      healthLogEntryController: health.logEntry,
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
