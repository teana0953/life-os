import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_logged_days.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeMealRepository implements MealRepository {
  String? receivedMonth;
  List<String> daysToReturn = const [];

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    throw UnimplementedError();
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
    receivedMonth = month;
    return daysToReturn;
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

void main() {
  group('GetLoggedDays', () {
    test('delegates to the repository with the given month', () async {
      final repository = FakeMealRepository()
        ..daysToReturn = ['2026-07-01', '2026-07-15'];
      final useCase = GetLoggedDays(repository);

      final days = await useCase('token-123', '2026-07');

      expect(repository.receivedMonth, '2026-07');
      expect(days, ['2026-07-01', '2026-07-15']);
    });
  });
}
