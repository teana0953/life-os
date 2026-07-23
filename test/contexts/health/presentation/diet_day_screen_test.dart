import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/favorite_food.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
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
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';
import 'package:life_os/contexts/health/presentation/daily_target_screen.dart';
import 'package:life_os/contexts/health/presentation/dictionary_controller.dart';
import 'package:life_os/contexts/health/presentation/diet_day_screen.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';
import 'package:life_os/l10n/generated/app_localizations.dart';

import '../../../support/l10n_test_app.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> signUp(String email, String password) async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<String?> idToken() async => 'token';
  @override
  Stream<bool> get authStateChanges => const Stream.empty();
}

class _FakeMealRepository implements MealRepository {
  final List<String> receivedDays = [];

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    receivedDays.add(day);
    return DayMealsLog.fromJson({
      'day': day,
      'meals': const <dynamic>[],
      'totals': {
        'carb_g': 0, 'protein_g': 0, 'fat_g': 0, 'sugar_g': 0, 'fiber_g': 0, 'kcal': 0,
        'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0,
      },
    });
  }

  @override
  Future<MealEntry> createMeal(String idToken, {required String day, required String meal, DateTime? time, required List<CreateMealItem> items}) async => throw UnimplementedError();
  @override
  Future<List<String>> loggedDays(String idToken, String month) async => const [];
  @override
  Future<void> patchMealItem(String idToken, String id, {double? quantity, double? measure, Portions? portions}) async => throw UnimplementedError();
  @override
  Future<void> deleteMealItem(String idToken, String id) async => throw UnimplementedError();
  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async => throw UnimplementedError();
  @override
  Future<void> deleteMeal(String idToken, String id) async => throw UnimplementedError();
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
  Future<DailyTarget> setTarget(String idToken, {required String day, required double baseStaple, required double baseMeat, required double baseFruit, required double baseVeg, double? bonusStaple, double? bonusMeat, double? bonusFruit, double? bonusVeg}) async => throw UnimplementedError();
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

/// The diet day screen wired to the given [meals] repo. Controllers are created
/// fresh each call unless [reuse] is passed, so a re-mount can share state.
Widget _dietDay({
  required _FakeMealRepository meals,
  DateTime Function() clock = _clock,
  _Controllers? reuse,
}) {
  final target = _FakeDailyTargetRepository();
  final dict = _FakeFoodDictionaryRepository();
  final c = reuse ??
      _Controllers(
        today: TodayController(
          GetDayMeals(meals),
          GetDailyTargetWithRemaining(target),
          EditMealItem(meals),
          DeleteMealItem(meals),
          ChangeMealTime(meals),
          DeleteMeal(meals),
        ),
        dailyTarget: DailyTargetController(
          GetDailyTargetWithRemaining(target),
          SetDailyTarget(target),
        ),
        dictionary: DictionaryController(
          SearchDictionary(dict),
          ListFavorites(dict),
          FavoriteFood(dict),
          UnfavoriteFood(dict),
        ),
        createMeal: CreateMealController(CreateMeal(meals)),
        getLoggedDays: GetLoggedDays(meals),
      );
  return DietDayScreen(
    authRepository: _FakeAuthRepository(),
    idToken: 'token',
    todayController: c.today,
    dictionaryController: c.dictionary,
    dailyTargetController: c.dailyTarget,
    createMealController: c.createMeal,
    getLoggedDays: c.getLoggedDays,
    clock: clock,
  );
}

class _Controllers {
  final TodayController today;
  final DailyTargetController dailyTarget;
  final DictionaryController dictionary;
  final CreateMealController createMeal;
  final GetLoggedDays getLoggedDays;
  _Controllers({required this.today, required this.dailyTarget, required this.dictionary, required this.createMeal, required this.getLoggedDays});
}

DateTime _clock() => DateTime(2026, 7, 15, 9);

AppLocalizations get _en => lookupAppLocalizations(const Locale('en'));

void main() {
  testWidgets('loads today on mount', (tester) async {
    final meals = _FakeMealRepository();
    await tester.pumpWidget(l10nTestApp(home: _dietDay(meals: meals)));
    await tester.pumpAndSettle();

    expect(meals.receivedDays.last, '2026-07-15');
  });

  testWidgets('browsing to the previous day loads that day', (tester) async {
    final meals = _FakeMealRepository();
    await tester.pumpWidget(l10nTestApp(home: _dietDay(meals: meals)));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip(_en.dietDayPrevTooltip));
    await tester.pumpAndSettle();

    expect(meals.receivedDays.last, '2026-07-14');
  });

  testWidgets(
    'regression: re-entering the screen reloads today after a past day was browsed',
    (tester) async {
      final meals = _FakeMealRepository();
      // Build once, keep the (shared) controllers so a fresh mount reuses them —
      // mirroring re-opening the diet tile from the record hub.
      final first = _dietDay(meals: meals) as DietDayScreen;
      final shared = _Controllers(
        today: first.todayController,
        dailyTarget: first.dailyTargetController,
        dictionary: first.dictionaryController,
        createMeal: first.createMealController,
        getLoggedDays: first.getLoggedDays,
      );
      await tester.pumpWidget(l10nTestApp(home: first));
      await tester.pumpAndSettle();

      // Browse to a past day: the shared controllers now hold that day.
      await tester.tap(find.byTooltip(_en.dietDayPrevTooltip));
      await tester.pumpAndSettle();
      expect(meals.receivedDays.last, '2026-07-14');

      // Fully unmount, then re-mount a fresh screen with the same controllers —
      // exactly what re-opening the diet tile (a new pushed route) does, so
      // initState runs again.
      await tester.pumpWidget(l10nTestApp(home: const SizedBox.shrink()));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        l10nTestApp(home: _dietDay(meals: meals, reuse: shared)),
      );
      await tester.pumpAndSettle();

      // initState reloads today — not the last-browsed day.
      expect(meals.receivedDays.last, '2026-07-15');
    },
  );

  testWidgets('the target action opens the daily target screen', (tester) async {
    await tester.pumpWidget(l10nTestApp(home: _dietDay(meals: _FakeMealRepository())));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diet-open-target')));
    await tester.pumpAndSettle();

    expect(find.byType(DailyTargetScreen), findsOneWidget);
  });
}
