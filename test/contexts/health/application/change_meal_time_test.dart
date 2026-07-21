import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeMealRepository implements MealRepository {
  String? receivedIdToken;
  String? receivedId;
  DateTime? receivedTime;

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
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {
    receivedIdToken = idToken;
    receivedId = id;
    receivedTime = time;
  }

  @override
  Future<void> deleteMeal(String idToken, String id) async => throw UnimplementedError();
}

void main() {
  group('ChangeMealTime', () {
    test('changes the meal time via the repository', () async {
      final repository = FakeMealRepository();
      final changeMealTime = ChangeMealTime(repository);
      final time = DateTime.utc(2026, 7, 18, 9);

      await changeMealTime('token-123', 'meal-1', time);

      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedId, 'meal-1');
      expect(repository.receivedTime, time);
    });
  });
}
