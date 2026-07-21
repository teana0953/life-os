import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/create_meal.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
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

FoodItem _riceItem({double? baseAmount, String? measureUnit}) => FoodItem.fromJson({
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
  'base_amount': baseAmount,
  'measure_unit': measureUnit,
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

    test('add appends a tray item defaulting to quantity 1, not measure mode', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');

      controller.add(_riceItem());

      expect(controller.tray, hasLength(1));
      final entry = controller.tray.single as TrayItem;
      expect(entry.item.id, 'rice-1');
      expect(entry.amount, 1);
      expect(entry.measureMode, isFalse);
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
      final row = controller.tray.single as TrayItem;

      controller.setAmount(row, 2.5);

      expect((controller.tray.single as TrayItem).amount, 2.5);
    });

    test('toggleMeasure to measure mode resets the amount to the item\'s base amount', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');
      controller.add(_riceItem(baseAmount: 50, measureUnit: 'g'));
      final row = controller.tray.single as TrayItem;

      controller.toggleMeasure(row, true);

      final entry = controller.tray.single as TrayItem;
      expect(entry.measureMode, isTrue);
      expect(entry.amount, 50);
    });

    test('toggleMeasure back to quantity mode resets the amount to 1', () {
      final controller = CreateMealController(CreateMeal(FakeMealRepository()))
        ..start('lunch');
      controller.add(_riceItem(baseAmount: 50, measureUnit: 'g'));
      controller.toggleMeasure(controller.tray.single as TrayItem, true);
      controller.setAmount(controller.tray.single as TrayItem, 33);

      controller.toggleMeasure(controller.tray.single as TrayItem, false);

      final entry = controller.tray.single as TrayItem;
      expect(entry.measureMode, isFalse);
      expect(entry.amount, 1);
    });

    test('submit sends quantity for a unit row and measure for a measure-mode row', () async {
      final repository = FakeMealRepository();
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());
      controller.setAmount(controller.tray[0] as TrayItem, 1.5);
      controller.add(_riceItem(baseAmount: 50, measureUnit: 'g'));
      controller.toggleMeasure(controller.tray[1] as TrayItem, true);
      controller.setAmount(controller.tray[1] as TrayItem, 33);

      final result = await controller.submit('token-123', '2026-07-18');

      expect(result, isTrue);
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
      expect(repository.receivedMeal, 'lunch');
      expect(repository.receivedItems, hasLength(2));
      expect(repository.receivedItems![0].quantity, 1.5);
      expect(repository.receivedItems![0].measure, isNull);
      expect(repository.receivedItems![1].measure, 33);
      expect(repository.receivedItems![1].quantity, isNull);
    });

    test('submit skips rows cleared to 0 and only sends the rest', () async {
      final repository = FakeMealRepository();
      final controller = CreateMealController(CreateMeal(repository))
        ..start('lunch');
      controller.add(_riceItem());
      controller.setAmount(controller.tray[0] as TrayItem, 0);
      controller.add(_riceItem());
      controller.setAmount(controller.tray[1] as TrayItem, 1);

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
      controller.setAmount(controller.tray[0] as TrayItem, 0);

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

    group('add signal (addTick / lastAdded)', () {
      test('add bumps addTick and records the added entry as lastAdded', () {
        final controller = CreateMealController(CreateMeal(FakeMealRepository()))
          ..start('lunch');
        expect(controller.addTick, 0);
        expect(controller.lastAdded, isNull);

        controller.add(_riceItem());

        expect(controller.addTick, 1);
        expect(controller.lastAdded, same(controller.tray.last));
      });

      test('addManual bumps addTick and records the added entry as lastAdded', () {
        final controller = CreateMealController(CreateMeal(FakeMealRepository()))
          ..start('lunch');
        controller.add(_riceItem());

        controller.addManual(
          '自製便當',
          const Portions(staple: 1, meat: 0, fruit: 0, veg: 0),
        );

        expect(controller.addTick, 2);
        expect(controller.lastAdded, same(controller.tray.last));
        expect(controller.lastAdded, isA<ManualTrayItem>());
      });

      test('remove, setAmount and toggleMeasure leave addTick/lastAdded unchanged', () {
        final controller = CreateMealController(CreateMeal(FakeMealRepository()))
          ..start('lunch');
        controller.add(_riceItem(baseAmount: 50, measureUnit: 'g'));
        controller.add(_riceItem());
        final tickAfterAdds = controller.addTick;
        final lastAddedAfterAdds = controller.lastAdded;

        controller.setAmount(controller.tray[0] as TrayItem, 2);
        controller.toggleMeasure(controller.tray[0] as TrayItem, true);
        controller.remove(controller.tray.last);

        expect(controller.addTick, tickAfterAdds);
        expect(controller.lastAdded, same(lastAddedAfterAdds));
      });

      test('start resets addTick and lastAdded for a fresh session', () {
        final controller = CreateMealController(CreateMeal(FakeMealRepository()))
          ..start('lunch');
        controller.add(_riceItem());

        controller.start('dinner');

        expect(controller.addTick, 0);
        expect(controller.lastAdded, isNull);
      });
    });

    group('manual tray items', () {
      const portions = Portions(staple: 1, meat: 1, fruit: 0, veg: 0);

      test('addManual appends a ManualTrayItem carrying the name and portions', () {
        final controller = CreateMealController(CreateMeal(FakeMealRepository()))
          ..start('lunch');

        controller.addManual('自製便當', portions);

        expect(controller.tray, hasLength(1));
        final entry = controller.tray.single as ManualTrayItem;
        expect(entry.name, '自製便當');
        expect(entry.portions, portions);
      });

      test('remove removes a manual tray item', () {
        final controller = CreateMealController(CreateMeal(FakeMealRepository()))
          ..start('lunch');
        controller.addManual('自製便當', portions);
        final toRemove = controller.tray.single;

        controller.remove(toRemove);

        expect(controller.tray, isEmpty);
      });

      test('submit sends a manual row as name+portions and a dictionary row as quantity, in one call', () async {
        final repository = FakeMealRepository();
        final controller = CreateMealController(CreateMeal(repository))
          ..start('lunch');
        controller.add(_riceItem());
        controller.addManual('自製便當', portions);

        final result = await controller.submit('token-123', '2026-07-18');

        expect(result, isTrue);
        expect(repository.receivedItems, hasLength(2));
        final dictionaryItem = repository.receivedItems!.firstWhere((i) => i.foodItemId != null);
        expect(dictionaryItem.quantity, 1);
        final manualItem = repository.receivedItems!.firstWhere((i) => i.foodItemId == null);
        expect(manualItem.name, '自製便當');
        expect(manualItem.portions, portions);
      });
    });
  });
}
