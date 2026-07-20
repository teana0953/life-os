import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/presentation/create_meal_controller.dart';

class FakeMealRepository implements MealRepository {
  String? receivedIdToken;
  String? receivedDay;
  String? receivedMeal;
  List<CreateMealItem>? receivedItems;
  Object? errorToThrow;

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
    if (errorToThrow != null) throw errorToThrow!;
    receivedIdToken = idToken;
    receivedDay = day;
    receivedMeal = meal;
    receivedItems = items;
    return MealEntry.fromJson({
      'id': 'meal-1',
      'meal': meal,
      'time': '2026-07-18T12:30:00.000Z',
      'items': <dynamic>[],
    });
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }
}

FoodItem _riceItem({double? baseGrams}) => FoodItem.fromJson({
  'id': 'rice-1',
  'owner_user_id': null,
  'name': '飯/1碗',
  'carb_g': 60,
  'protein_g': 4,
  'fat_g': 0.5,
  'sugar_g': 0,
  'fiber_g': 1,
  'kcal': 280,
  'staple': 4,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'base_grams': baseGrams,
});

void main() {
  group('CreateMealController', () {
    test('start resets the meal and clears the tray', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()));

      controller.start('lunch');

      expect(controller.meal, 'lunch');
      expect(controller.tray, isEmpty);
      expect(controller.status, CreateMealControllerStatus.editing);
    });

    test('add appends a tray item defaulting to quantity 1, not grams', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');

      controller.add(_riceItem());

      expect(controller.tray, hasLength(1));
      expect(controller.tray.single.item.id, 'rice-1');
      expect(controller.tray.single.amount, 1);
      expect(controller.tray.single.grams, isFalse);
    });

    test('remove removes exactly the given tray item', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');
      controller.add(_riceItem());
      controller.add(_riceItem());
      final toRemove = controller.tray.first;

      controller.remove(toRemove);

      expect(controller.tray, hasLength(1));
      expect(controller.tray, isNot(contains(toRemove)));
    });

    test('setAmount updates that row\'s amount only', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');
      controller.add(_riceItem());
      final row = controller.tray.single;

      controller.setAmount(row, 2.5);

      expect(controller.tray.single.amount, 2.5);
    });

    test('toggleGrams to grams mode resets the amount to the item\'s base grams', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');
      controller.add(_riceItem(baseGrams: 50));
      final row = controller.tray.single;

      controller.toggleGrams(row, true);

      expect(controller.tray.single.grams, isTrue);
      expect(controller.tray.single.amount, 50);
    });

    test('toggleGrams back to quantity mode resets the amount to 1', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');
      controller.add(_riceItem(baseGrams: 50));
      controller.toggleGrams(controller.tray.single, true);
      controller.setAmount(controller.tray.single, 33);

      controller.toggleGrams(controller.tray.single, false);

      expect(controller.tray.single.grams, isFalse);
      expect(controller.tray.single.amount, 1);
    });

    test('submit sends quantity for a unit row and grams for a gram-mode row', () async {
      final repository = FakeMealRepository();
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());
      controller.setAmount(controller.tray[0], 1.5);
      controller.add(_riceItem(baseGrams: 50));
      controller.toggleGrams(controller.tray[1], true);
      controller.setAmount(controller.tray[1], 33);

      final result = await controller.submit('token-123', '2026-07-18');

      expect(result, isTrue);
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
      expect(repository.receivedMeal, 'lunch');
      expect(repository.receivedItems, hasLength(2));
      expect(repository.receivedItems![0].quantity, 1.5);
      expect(repository.receivedItems![0].grams, isNull);
      expect(repository.receivedItems![1].grams, 33);
      expect(repository.receivedItems![1].quantity, isNull);
    });

    test('submit skips rows cleared to 0 and only sends the rest', () async {
      final repository = FakeMealRepository();
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());
      controller.setAmount(controller.tray[0], 0);
      controller.add(_riceItem());
      controller.setAmount(controller.tray[1], 1);

      final result = await controller.submit('token-123', '2026-07-18');

      expect(result, isTrue);
      expect(repository.receivedItems, hasLength(1));
      expect(repository.receivedItems!.single.quantity, 1);
    });

    test('submit does not call the repository when every row is 0', () async {
      final repository = FakeMealRepository();
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());
      controller.setAmount(controller.tray[0], 0);

      final result = await controller.submit('token-123', '2026-07-18');

      expect(result, isFalse);
      expect(repository.receivedItems, isNull);
    });

    test('reauth failure sets needsReauth without clearing the tray', () async {
      final repository = FakeMealRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());

      final result = await controller.submit('token-123', '2026-07-18');

      expect(result, isFalse);
      expect(controller.status, CreateMealControllerStatus.needsReauth);
      expect(controller.tray, hasLength(1));
    });

    test('a fetch failure sets an error status without clearing the tray', () async {
      final repository = FakeMealRepository()
        ..errorToThrow = const DietFetchFailure('boom');
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());

      final result = await controller.submit('token-123', '2026-07-18');

      expect(result, isFalse);
      expect(controller.status, CreateMealControllerStatus.error);
      expect(controller.error, CreateMealError.saveFailed);
      expect(controller.tray, hasLength(1));
    });
  });
}
