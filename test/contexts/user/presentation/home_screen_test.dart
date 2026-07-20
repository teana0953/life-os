import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/delete_entry.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_diet_log.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/log_food_from_dictionary.dart';
import 'package:life_os/contexts/health/application/log_manual_entry.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/application/update_food_entry.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';
import 'package:life_os/contexts/health/domain/diet_log_repository.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_entry.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/diet_shell_screen.dart';
import 'package:life_os/contexts/health/presentation/edit_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/log_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/manual_entry_controller.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_exceptions.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/settings/presentation/settings_screen.dart';
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
  Future<FoodEntry> logManualEntry(
    String idToken, {
    required String day,
    required String meal,
    String? name,
    required Portions portions,
    required DateTime eatenAt,
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

  @override
  Future<FoodEntry> updateEntry(
    String idToken,
    String entryId, {
    String? name,
    String? meal,
    DateTime? eatenAt,
    Portions? portions,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
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
  final themeController = await testThemeController();
  final dietLogRepository = _FakeDietLogRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final foodDictionaryRepository = _FakeFoodDictionaryRepository();
  await tester.pumpWidget(
    l10nTestApp(
      locale: locale,
      localeController: localeController,
      home: HomeScreen(
        controller: controller,
        localeController: localeController,
        themeController: themeController,
        signOut: SignOut(FakeAuthRepository()),
        authRepository: authRepository ?? FakeAuthRepository(),
        healthTodayController: TodayController(
          GetDayDietLog(dietLogRepository),
          GetDailyTargetWithRemaining(dailyTargetRepository),
        ),
        healthDictionaryController: DictionaryController(
          SearchDictionary(foodDictionaryRepository),
          ListFavorites(foodDictionaryRepository),
          FavoriteFood(foodDictionaryRepository),
          UnfavoriteFood(foodDictionaryRepository),
        ),
        healthDailyTargetController: DailyTargetController(
          GetDailyTargetWithRemaining(dailyTargetRepository),
          SetDailyTarget(dailyTargetRepository),
        ),
        healthLogEntryController: LogEntryController(
          LogFoodFromDictionary(dietLogRepository),
        ),
        healthManualEntryController: ManualEntryController(
          LogManualEntry(dietLogRepository),
        ),
        healthEditEntryController: EditEntryController(
          UpdateFoodEntry(dietLogRepository),
          DeleteEntry(dietLogRepository),
        ),
        healthGetLoggedDays: GetLoggedDays(dietLogRepository),
        clock: clock ?? DateTime.now,
      ),
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets(
      'shows the loaded profile email and does not show the internal id',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        expect(find.text('test@example.com'), findsOneWidget);
        expect(find.text('user-1'), findsNothing);
      },
    );

    testWidgets(
      'tapping the health tile navigates to the DietShellScreen',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller, authRepository: authRepository);

        expect(find.byType(DietShellScreen), findsNothing);

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();

        expect(find.byType(DietShellScreen), findsOneWidget);
      },
    );

    testWidgets(
      'shows a build label (defaults to "dev" without a BUILD_TAG define)',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
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
          'dev',
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

    testWidgets(
      '401 shows a "sign in again" exit rather than a dead end',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..errorToThrow = const ReauthenticationRequired();
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        final signInAgainButton = find.byKey(
          const Key('sign-in-again-button'),
        );
        expect(signInAgainButton, findsOneWidget);

        await tester.tap(signInAgainButton);
        await tester.pumpAndSettle();

        expect(authRepository.signOutCalled, isTrue);
      },
    );

    testWidgets(
      'tapping the settings icon navigates to the SettingsScreen',
      (tester) async {
        final profileRepository = FakeProfileRepository()
          ..profileToReturn = UserProfile(
            id: 'user-1',
            firebaseUid: 'firebase-abc',
            email: 'test@example.com',
            displayName: 'Test User',
            createdAt: '2026-01-01T00:00:00.000Z',
          );
        final authRepository = FakeAuthRepository();
        final controller = HomeController(
          GetProfile(profileRepository),
          SignOut(authRepository),
        );
        await controller.load('token-123');
        await pumpHomeScreen(tester, controller);

        expect(find.byType(SettingsScreen), findsNothing);

        await tester.tap(find.byKey(const Key('settings-icon-button')));
        await tester.pumpAndSettle();

        expect(find.byType(SettingsScreen), findsOneWidget);
      },
    );

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

  group('HomeScreen greeting', () {
    Future<HomeController> loadedController() async {
      final profileRepository = FakeProfileRepository()
        ..profileToReturn = UserProfile(
          id: 'user-1',
          firebaseUid: 'firebase-abc',
          email: 'test@example.com',
          displayName: 'Test User',
          createdAt: '2026-01-01T00:00:00.000Z',
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
        find.text(lookupAppLocalizations(const Locale('en')).greetingMorning),
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
          lookupAppLocalizations(const Locale('en')).greetingAfternoon,
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
        find.text(lookupAppLocalizations(const Locale('en')).greetingEvening),
        findsOneWidget,
      );
    });
  });
}
