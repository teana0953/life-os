import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/body_profile/application/get_body_profile.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/body_profile/application/set_body_profile.dart';
import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/body_profile/presentation/weight_goal_controller.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';
import 'package:life_os/contexts/health/presentation/dashboard_screen.dart';
import 'package:life_os/contexts/bowel/application/get_bowel_day.dart';
import 'package:life_os/contexts/bowel/application/save_bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_day.dart';
import 'package:life_os/contexts/bowel/domain/bowel_repository.dart';
import 'package:life_os/contexts/bowel/presentation/bowel_controller.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/application/list_favorites.dart';
import 'package:life_os/contexts/health/application/search_dictionary.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/application/unfavorite_food.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/food_dictionary_repository.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/diet_shell_screen.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_day.dart';
import 'package:life_os/contexts/vitals/application/save_vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_day.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';
import 'package:life_os/contexts/vitals/presentation/trend_controller.dart';
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/contexts/exercise/application/add_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/delete_exercise_entry.dart';
import 'package:life_os/contexts/exercise/application/get_exercise_day.dart';
import 'package:life_os/contexts/exercise/application/list_exercise_activities.dart';
import 'package:life_os/contexts/exercise/domain/exercise_day.dart';
import 'package:life_os/contexts/exercise/domain/exercise_repository.dart';
import 'package:life_os/contexts/exercise/presentation/exercise_controller.dart';
import 'package:life_os/contexts/menstrual/application/add_period.dart';
import 'package:life_os/contexts/menstrual/application/delete_period.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/menstrual/application/update_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/menstrual/presentation/menstrual_controller.dart';
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

class _FakeMealRepository implements MealRepository {
  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    return DayMealsLog.fromJson({
      'day': day,
      'meals': <dynamic>[],
      'totals': {
        'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
        'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
      },
    });
  }

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMealItem(String idToken, String id) async {
    throw UnimplementedError();
  }

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteMeal(String idToken, String id) async {
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

class _FakeWaterRepository implements WaterRepository {
  @override
  Future<WaterDay> getDay(String idToken, String day) async => WaterDay(
    day: day,
    totalMl: 0,
    targetMl: 2000,
    remainingMl: 2000,
  );

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async => 0;

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async => targetMl;
}

class _FakeBowelRepository implements BowelRepository {
  @override
  Future<BowelDay> getDay(String idToken, String day) async =>
      BowelDay(day: day, count: 0, isNormal: null, note: '');

  @override
  Future<BowelDay> save(
    String idToken, {
    required String day,
    required int count,
    required bool? isNormal,
    required String note,
  }) async =>
      BowelDay(day: day, count: count, isNormal: isNormal, note: note);
}

class _FakeVitalsRepository implements VitalsRepository {
  @override
  Future<VitalsRange> getRange(
    String idToken,
    DateTime from,
    DateTime to,
  ) async => VitalsRange(
    from: from,
    to: to,
    series: const VitalsSeries(
      weight: [],
      bodyFat: [],
      systolic: [],
      diastolic: [],
      pulse: [],
      glucose: [],
      spo2: [],
    ),
  );

  @override
  Future<VitalsDay> getDay(String idToken, String day) async => VitalsDay(
    day: day,
    weightKg: null,
    bodyFatPct: null,
    bpReadings: const [],
    glucoseReadings: const [],
    spo2Readings: const [],
  );

  @override
  Future<VitalsDay> save(String idToken, VitalsDay day) async => day;
}

class _FakeExerciseRepository implements ExerciseRepository {
  @override
  Future<List<ExerciseActivity>> listActivities(String idToken) async => const [];

  @override
  Future<ExerciseDay> getDay(String idToken, String day) async =>
      ExerciseDay(day: day, entries: const [], totalMinutes: 0);

  @override
  Future<ExerciseEntry> addEntry(
    String idToken, {
    required String day,
    required String activityId,
    required int durationMinutes,
    required String note,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deleteEntry(String idToken, String entryId) async => true;
}

class _FakeMenstrualRepository implements MenstrualRepository {
  @override
  Future<MenstrualOverview> getOverview(String idToken) async =>
      const MenstrualOverview(periods: [], stats: MenstrualStats());

  @override
  Future<MenstrualPeriod> addPeriod(
    String idToken, {
    required DateTime startDate,
    DateTime? endDate,
  }) async => throw UnimplementedError();

  @override
  Future<MenstrualPeriod> updatePeriod(
    String idToken,
    String id, {
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
  }) async => throw UnimplementedError();

  @override
  Future<bool> deletePeriod(String idToken, String id) async => true;
}

class _FakeBodyProfileRepository implements BodyProfileRepository {
  @override
  Future<WeightGoal> getWeightGoal(String idToken) async =>
      const WeightGoal(targetWeightKg: 51);

  @override
  Future<BodyProfile> getBodyProfile(String idToken) async =>
      const BodyProfile(heightCm: 165);

  @override
  Future<BodyProfile> setBodyProfile(
    String idToken, {
    double? heightCm,
    double? targetWeightKg,
  }) async => BodyProfile(heightCm: heightCm, targetWeightKg: targetWeightKg);
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
  final mealRepository = _FakeMealRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final foodDictionaryRepository = _FakeFoodDictionaryRepository();
  final waterRepository = _FakeWaterRepository();
  final bowelRepository = _FakeBowelRepository();
  final vitalsRepository = _FakeVitalsRepository();
  final exerciseRepository = _FakeExerciseRepository();
  final menstrualRepository = _FakeMenstrualRepository();
  final bodyProfileRepository = _FakeBodyProfileRepository();
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
          GetDayMeals(mealRepository),
          GetDailyTargetWithRemaining(dailyTargetRepository),
          EditMealItem(mealRepository),
          DeleteMealItem(mealRepository),
          ChangeMealTime(mealRepository),
          DeleteMeal(mealRepository),
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
        healthCreateMealController: CreateMealController(
          CreateMeal(mealRepository),
        ),
        healthGetLoggedDays: GetLoggedDays(mealRepository),
        waterController: WaterController(
          GetWaterDay(waterRepository),
          AddWater(waterRepository),
          SetWaterTarget(waterRepository),
        ),
        bowelController: BowelController(
          GetBowelDay(bowelRepository),
          SaveBowelDay(bowelRepository),
        ),
        vitalsController: VitalsController(
          GetVitalsDay(vitalsRepository),
          SaveVitalsDay(vitalsRepository),
        ),
        exerciseController: ExerciseController(
          ListExerciseActivities(exerciseRepository),
          GetExerciseDay(exerciseRepository),
          AddExerciseEntry(exerciseRepository),
          DeleteExerciseEntry(exerciseRepository),
        ),
        menstrualController: MenstrualController(
          GetMenstrualOverview(menstrualRepository),
          AddPeriod(menstrualRepository),
          UpdatePeriod(menstrualRepository),
          DeletePeriod(menstrualRepository),
        ),
        weightGoalController: WeightGoalController(
          GetWeightGoal(bodyProfileRepository),
          GetBodyProfile(bodyProfileRepository),
          SetBodyProfile(bodyProfileRepository),
        ),
        trendController: TrendController(GetVitalsTrends(vitalsRepository)),
        healthCalendarController: HealthCalendarController(GetHealthCalendar(_FakeHealthCalendarRepository())),
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
      'tapping the health tile navigates to the DashboardScreen, and the '
      'dashboard\'s record entry reaches the DietShellScreen',
      (tester) async {
        // A taller surface so the dashboard's record entry (now below the goal
        // and trend cards) is laid out and tappable in the lazy list.
        await tester.binding.setSurfaceSize(const Size(700, 1600));
        addTearDown(() => tester.binding.setSurfaceSize(null));
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

        expect(find.byType(DashboardScreen), findsNothing);

        await tester.tap(find.byKey(const Key('health-tile')));
        await tester.pumpAndSettle();

        // The health module now lands on the dashboard, not the shell directly.
        expect(find.byType(DashboardScreen), findsOneWidget);
        expect(find.byType(DietShellScreen), findsNothing);

        // The shell is one tap away via the dashboard's "record" entry.
        await tester.tap(find.byKey(const Key('dashboard-record-entry')));
        await tester.pumpAndSettle();

        expect(find.byType(DietShellScreen), findsOneWidget);
      },
    );

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

class _FakeHealthCalendarRepository implements HealthCalendarRepository {
  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async => HealthCalendar(
    year: year,
    month: month,
    loggedDays: const {},
    daysElapsed: 0,
    loggingRate: null,
    dietAdherenceRate: null,
  );
}
