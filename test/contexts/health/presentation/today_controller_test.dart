import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';

class FakeMealRepository implements MealRepository {
  DayMealsLog? logToReturn;
  Object? errorToThrow;
  String? receivedDay;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    receivedDay = day;
    if (errorToThrow != null) throw errorToThrow!;
    return logToReturn!;
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
}

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return targetToReturn!;
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

DayMealsLog _dayLog() => DayMealsLog.fromJson({
  'day': '2026-07-18',
  'meals': [
    {
      'id': 'meal-breakfast',
      'meal': 'breakfast',
      'time': '2026-07-18T08:00:00.000Z',
      'items': <dynamic>[],
    },
    {
      'id': 'meal-lunch',
      'meal': 'lunch',
      'time': '2026-07-18T12:30:00.000Z',
      'items': <dynamic>[],
    },
  ],
  'totals': {
    'carb_g': 20,
    'protein_g': 4,
    'fat_g': 2,
    'sugar_g': 0,
    'fiber_g': 0,
    'kcal': 120,
    'staple': 9,
    'meat': 3,
    'fruit': 1,
    'veg': 0,
  },
});

DailyTargetWithRemaining _target() => DailyTargetWithRemaining.fromJson({
  'day': '2026-07-18',
  'base': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
  'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
  'effective': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
  'logged': {'staple': 9, 'meat': 3, 'fruit': 1, 'veg': 0},
  'remaining': {'staple': 3, 'meat': 3, 'fruit': 3, 'veg': 3},
});

void main() {
  group('TodayController.load', () {
    test('loads the day meals log and target', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayMeals(mealRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.loaded);
      expect(controller.dayMealsLog!.meals.map((m) => m.meal), ['breakfast', 'lunch']);
      expect(controller.dayMealsLog!.totals.staple, 9);
      expect(controller.target!.effective.staple, 12);
      expect(mealRepository.receivedDay, '2026-07-18');
    });

    test('sets error status on DietFetchFailure', () async {
      final mealRepository = FakeMealRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayMeals(mealRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.fetchFailed);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final mealRepository = FakeMealRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = TodayController(
        GetDayMeals(mealRepository),
        GetDailyTargetWithRemaining(targetRepository),
      );

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.needsReauth);
    });
  });
}
