import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';

class FakeMealRepository implements MealRepository {
  DayMealsLog? logToReturn;
  Object? errorToThrow;
  Object? mutationErrorToThrow;
  String? receivedDay;

  String? patchedItemId;
  double? patchedQuantity;
  double? patchedMeasure;
  Portions? patchedPortions;
  String? deletedItemId;
  String? patchedMealId;
  DateTime? patchedTime;
  String? deletedMealId;

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

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    patchedItemId = id;
    patchedQuantity = quantity;
    patchedMeasure = measure;
    patchedPortions = portions;
  }

  @override
  Future<void> deleteMealItem(String idToken, String id) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    deletedItemId = id;
  }

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    patchedMealId = id;
    patchedTime = time;
  }

  @override
  Future<void> deleteMeal(String idToken, String id) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    deletedMealId = id;
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

TodayController _controller(
  FakeMealRepository mealRepository,
  FakeDailyTargetRepository targetRepository,
) {
  return TodayController(
    GetDayMeals(mealRepository),
    GetDailyTargetWithRemaining(targetRepository),
    EditMealItem(mealRepository),
    DeleteMealItem(mealRepository),
    ChangeMealTime(mealRepository),
    DeleteMeal(mealRepository),
  );
}

void main() {
  group('TodayController.load', () {
    test('loads the day meals log and target', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

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
      final controller = _controller(mealRepository, targetRepository);

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.fetchFailed);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final mealRepository = FakeMealRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.needsReauth);
    });
  });

  group('TodayController mutations', () {
    test('editItem sends quantity and reloads the day', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.editItem('token-123', '2026-07-18', 'item-1', quantity: 2);

      expect(mealRepository.patchedItemId, 'item-1');
      expect(mealRepository.patchedQuantity, 2);
      expect(mealRepository.patchedMeasure, isNull);
      expect(mealRepository.receivedDay, '2026-07-18');
      expect(controller.status, TodayStatus.loaded);
    });

    test('editItem sends measure (no quantity)', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.editItem('token-123', '2026-07-18', 'item-1', measure: 80);

      expect(mealRepository.patchedMeasure, 80);
      expect(mealRepository.patchedQuantity, isNull);
    });

    test('editItem sends portions', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);
      const portions = Portions(staple: 3, meat: 1, fruit: 0, veg: 0);

      await controller.editItem('token-123', '2026-07-18', 'item-1', portions: portions);

      expect(mealRepository.patchedPortions, portions);
    });

    test('deleteItem deletes and reloads the day', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteItem('token-123', '2026-07-18', 'item-1');

      expect(mealRepository.deletedItemId, 'item-1');
      expect(controller.status, TodayStatus.loaded);
    });

    test('changeMealTime patches the meal\'s time and reloads', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);
      final time = DateTime.utc(2026, 7, 18, 9);

      await controller.changeMealTime('token-123', '2026-07-18', 'meal-lunch', time);

      expect(mealRepository.patchedMealId, 'meal-lunch');
      expect(mealRepository.patchedTime, time);
      expect(controller.status, TodayStatus.loaded);
    });

    test('deleteMeal deletes and reloads the day', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteMeal('token-123', '2026-07-18', 'meal-lunch');

      expect(mealRepository.deletedMealId, 'meal-lunch');
      expect(controller.status, TodayStatus.loaded);
    });

    test('a reauth failure sets needsReauth', () async {
      final mealRepository = FakeMealRepository()
        ..logToReturn = _dayLog()
        ..mutationErrorToThrow = const DietReauthenticationRequired();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteItem('token-123', '2026-07-18', 'item-1');

      expect(controller.status, TodayStatus.needsReauth);
    });

    test('a not-found failure sets an error status with TodayError.notFound', () async {
      final mealRepository = FakeMealRepository()
        ..logToReturn = _dayLog()
        ..mutationErrorToThrow = const DietNotFound();
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteItem('token-123', '2026-07-18', 'not-mine');

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.notFound);
    });

    test('a fetch failure sets an error status with TodayError.fetchFailed', () async {
      final mealRepository = FakeMealRepository()
        ..logToReturn = _dayLog()
        ..mutationErrorToThrow = const DietFetchFailure('boom');
      final targetRepository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteMeal('token-123', '2026-07-18', 'meal-lunch');

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.fetchFailed);
    });
  });
}
