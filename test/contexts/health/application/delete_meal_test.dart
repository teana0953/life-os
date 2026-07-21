import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeMealRepository implements MealRepository {
  String? receivedIdToken;
  String? receivedId;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async => throw UnimplementedError();

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) async => throw UnimplementedError();

  @override
  Future<List<String>> loggedDays(String idToken, String month) async => throw UnimplementedError();

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) async => throw UnimplementedError();

  @override
  Future<void> deleteMealItem(String idToken, String id) async => throw UnimplementedError();

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async => throw UnimplementedError();

  @override
  Future<void> deleteMeal(String idToken, String id) async {
    receivedIdToken = idToken;
    receivedId = id;
  }
}

void main() {
  group('DeleteMeal', () {
    test('deletes the meal via the repository', () async {
      final repository = FakeMealRepository();
      final deleteMeal = DeleteMeal(repository);

      await deleteMeal('token-123', 'meal-1');

      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedId, 'meal-1');
    });
  });
}
