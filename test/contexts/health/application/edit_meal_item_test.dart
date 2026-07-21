import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

class FakeMealRepository implements MealRepository {
  String? receivedIdToken;
  String? receivedId;
  double? receivedQuantity;
  double? receivedMeasure;
  Portions? receivedPortions;

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
  }) async {
    receivedIdToken = idToken;
    receivedId = id;
    receivedQuantity = quantity;
    receivedMeasure = measure;
    receivedPortions = portions;
  }

  @override
  Future<void> deleteMealItem(String idToken, String id) async => throw UnimplementedError();

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async => throw UnimplementedError();

  @override
  Future<void> deleteMeal(String idToken, String id) async => throw UnimplementedError();
}

void main() {
  group('EditMealItem', () {
    test('forwards quantity to the repository', () async {
      final repository = FakeMealRepository();
      final editMealItem = EditMealItem(repository);

      await editMealItem('token-123', 'item-1', quantity: 2);

      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedId, 'item-1');
      expect(repository.receivedQuantity, 2);
      expect(repository.receivedMeasure, isNull);
      expect(repository.receivedPortions, isNull);
    });

    test('forwards measure to the repository', () async {
      final repository = FakeMealRepository();
      final editMealItem = EditMealItem(repository);

      await editMealItem('token-123', 'item-1', measure: 80);

      expect(repository.receivedMeasure, 80);
      expect(repository.receivedQuantity, isNull);
    });

    test('forwards portions to the repository', () async {
      final repository = FakeMealRepository();
      final editMealItem = EditMealItem(repository);
      const portions = Portions(staple: 3, meat: 1, fruit: 0, veg: 0);

      await editMealItem('token-123', 'item-1', portions: portions);

      expect(repository.receivedPortions, portions);
    });
  });
}
