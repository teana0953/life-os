import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';

class FakeMealRepository implements MealRepository {
  MealEntry? mealToReturn;
  String? receivedIdToken;
  String? receivedDay;
  String? receivedMeal;
  DateTime? receivedTime;
  List<CreateMealItem>? receivedItems;

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
    receivedIdToken = idToken;
    receivedDay = day;
    receivedMeal = meal;
    receivedTime = time;
    receivedItems = items;
    return mealToReturn!;
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

void main() {
  group('CreateMeal', () {
    test('creates a meal via the repository, forwarding all fields', () async {
      final repository = FakeMealRepository()
        ..mealToReturn = MealEntry.fromJson({
          'id': 'meal-1',
          'meal': 'lunch',
          'time': '2026-07-18T12:30:00.000Z',
          'items': <dynamic>[],
        });
      final createMeal = CreateMeal(repository);
      final items = [CreateMealItem.dictionary('rice-1', quantity: 1.5)];

      final meal = await createMeal(
        'token-123',
        day: '2026-07-18',
        meal: 'lunch',
        time: DateTime.utc(2026, 7, 18, 12, 30),
        items: items,
      );

      expect(meal.id, 'meal-1');
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
      expect(repository.receivedMeal, 'lunch');
      expect(repository.receivedTime, DateTime.utc(2026, 7, 18, 12, 30));
      expect(repository.receivedItems, items);
    });
  });
}
