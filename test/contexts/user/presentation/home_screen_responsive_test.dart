import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/application/sign_out.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
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
import 'package:life_os/contexts/vitals/presentation/vitals_controller.dart';
import 'package:life_os/contexts/user/application/get_profile.dart';
import 'package:life_os/contexts/user/domain/profile_repository.dart';
import 'package:life_os/contexts/user/domain/user_profile.dart';
import 'package:life_os/contexts/user/presentation/home_controller.dart';
import 'package:life_os/contexts/user/presentation/home_screen.dart';
import 'package:life_os/shared/theme/app_theme.dart';
import 'package:life_os/shared/theme/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../support/l10n_test_app.dart';

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

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getProfile(String idToken) async => UserProfile(
    id: 'user-1',
    firebaseUid: 'firebase-abc',
    email: 'test@example.com',
    displayName: 'Test User',
    createdAt: '2026-01-01T00:00:00.000Z',
  );
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<String?> idToken() async => 'fake-token';

  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

Future<HomeController> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final controller = HomeController(
    GetProfile(_FakeProfileRepository()),
    SignOut(_FakeAuthRepository()),
  );
  await controller.load('token-123');
  final localeController = await testLocaleController();
  SharedPreferences.setMockInitialValues({});
  final themeController = ThemeController(await SharedPreferences.getInstance());
  final mealRepository = _FakeMealRepository();
  final dailyTargetRepository = _FakeDailyTargetRepository();
  final foodDictionaryRepository = _FakeFoodDictionaryRepository();
  final waterRepository = _FakeWaterRepository();
  final bowelRepository = _FakeBowelRepository();
  final vitalsRepository = _FakeVitalsRepository();
  await tester.pumpWidget(
    l10nTestApp(
      theme: lightTheme,
      home: HomeScreen(
        controller: controller,
        localeController: localeController,
        themeController: themeController,
        signOut: SignOut(_FakeAuthRepository()),
        authRepository: _FakeAuthRepository(),
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
      ),
    ),
  );
  await tester.pump();
  return controller;
}

SliverGridDelegateWithFixedCrossAxisCount _gridDelegate(WidgetTester tester) {
  final gridView = tester.widget<GridView>(find.byKey(const Key('spaces-grid')));
  return gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
}

void main() {
  group('HomeScreen responsive layout', () {
    testWidgets('narrow phone width: spaces grid uses fewer columns, no overflow', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(360, 800));

      expect(tester.takeException(), isNull);
      expect(_gridDelegate(tester).crossAxisCount, 2);
    });

    testWidgets('wide desktop width: spaces grid uses more columns', (
      tester,
    ) async {
      await _pumpAt(tester, const Size(1200, 800));

      expect(tester.takeException(), isNull);
      expect(_gridDelegate(tester).crossAxisCount, 4);
    });
  });
}
