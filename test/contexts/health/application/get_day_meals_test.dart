import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';

class FakeMealRepository implements MealRepository {
  DayMealsLog? logToReturn;
  String? receivedIdToken;
  String? receivedDay;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    receivedIdToken = idToken;
    receivedDay = day;
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

void main() {
  group('GetDayMeals', () {
    test('returns the day meals log via the repository', () async {
      final repository = FakeMealRepository()
        ..logToReturn = DayMealsLog.fromJson({
          'day': '2026-07-18',
          'meals': <dynamic>[],
          'totals': {
            'carb_g': 0,
            'protein_g': 0,
            'fat_g': 0,
            'sugar_g': 0,
            'fiber_g': 0,
            'kcal': 0,
            'staple': 0,
            'meat': 0,
            'fruit': 0,
            'veg': 0,
          },
        });
      final getDayMeals = GetDayMeals(repository);

      final log = await getDayMeals('token-123', '2026-07-18');

      expect(log.day, '2026-07-18');
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
    });
  });
}
