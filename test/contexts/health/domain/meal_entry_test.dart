import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';

Map<String, dynamic> _dictItemJson({
  String id = 'item-1',
  String? name = '飯/1碗',
  double stapleConsumed = 4,
  double meatConsumed = 0,
  double quantity = 1,
  double? baseAmount,
  String? measureUnit,
}) => {
  'id': id,
  'food_item_id': 'rice-1',
  'name': name,
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
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
  'quantity': quantity,
  'base_amount': baseAmount,
  'measure_unit': measureUnit,
  'consumed': {
    'carb_g': 60,
    'protein_g': 4,
    'fat_g': 0.5,
    'sugar_g': 0,
    'fiber_g': 1,
    'kcal': 280,
    'staple': stapleConsumed,
    'meat': meatConsumed,
    'fruit': 0,
    'veg': 0,
  },
};

Map<String, dynamic> _manualItemJson({
  String id = 'item-2',
  String? name = '自製便當',
  double staple = 2,
  double meat = 1,
}) => {
  'id': id,
  'food_item_id': null,
  'name': name,
  'photo_ref': null,
  'source': 'manual',
  'unclassified': false,
  'carb_g': 0,
  'protein_g': 0,
  'fat_g': 0,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 0,
  'staple': staple,
  'meat': meat,
  'fruit': 0,
  'veg': 0,
  'quantity': 1,
  'base_amount': null,
  'measure_unit': null,
  'consumed': {
    'carb_g': 0,
    'protein_g': 0,
    'fat_g': 0,
    'sugar_g': 0,
    'fiber_g': 0,
    'kcal': 0,
    'staple': staple,
    'meat': meat,
    'fruit': 0,
    'veg': 0,
  },
};

void main() {
  group('MealItem.fromJson — dictionary item', () {
    test('parses the nested consumed object as Portions', () {
      final item = MealItem.fromJson(_dictItemJson());

      expect(item.id, 'item-1');
      expect(item.name, '飯/1碗');
      expect(item.consumed.staple, 4);
      expect(item.consumed.meat, 0);
      expect(item.consumed.fruit, 0);
      expect(item.consumed.veg, 0);
    });

    test('a null name (unnamed dictionary item) parses as null', () {
      final item = MealItem.fromJson(_dictItemJson(name: null));

      expect(item.name, isNull);
    });

    test('an item consuming only meat parses that category', () {
      final item = MealItem.fromJson(
        _dictItemJson(stapleConsumed: 0, meatConsumed: 1),
      );

      expect(item.consumed.staple, 0);
      expect(item.consumed.meat, 1);
    });

    test('parses food_item_id, source, quantity — and is not manual', () {
      final item = MealItem.fromJson(_dictItemJson(quantity: 2));

      expect(item.foodItemId, 'rice-1');
      expect(item.source, 'dict');
      expect(item.quantity, 2);
      expect(item.isManual, isFalse);
    });

    test('base_amount and measure_unit are null when the item has no base measure', () {
      final item = MealItem.fromJson(_dictItemJson());

      expect(item.baseAmount, isNull);
      expect(item.measureUnit, isNull);
    });

    test('parses base_amount + measure_unit when the item has a base measure', () {
      final item = MealItem.fromJson(
        _dictItemJson(baseAmount: 50, measureUnit: 'g'),
      );

      expect(item.baseAmount, 50);
      expect(item.measureUnit, 'g');
    });
  });

  group('MealItem.fromJson — manual item', () {
    test('a manual item has source manual, null food_item_id, and is manual', () {
      final item = MealItem.fromJson(_manualItemJson());

      expect(item.source, 'manual');
      expect(item.foodItemId, isNull);
      expect(item.isManual, isTrue);
    });

    test('a manual item\'s flat per-unit fields are its entered portions', () {
      final item = MealItem.fromJson(_manualItemJson(staple: 3, meat: 1));

      expect(item.staple, 3);
      expect(item.meat, 1);
      expect(item.fruit, 0);
      expect(item.veg, 0);
    });
  });

  group('MealEntry.fromJson', () {
    test('parses id, meal, ISO time as UTC, and items', () {
      final meal = MealEntry.fromJson({
        'id': 'meal-1',
        'meal': 'lunch',
        'time': '2026-07-18T12:30:00.000Z',
        'items': [_dictItemJson()],
      });

      expect(meal.id, 'meal-1');
      expect(meal.meal, 'lunch');
      expect(meal.time, DateTime.utc(2026, 7, 18, 12, 30));
      expect(meal.time.isUtc, isTrue);
      expect(meal.items, hasLength(1));
      expect(meal.items.single.id, 'item-1');
    });

    test('a snack meal value is kept verbatim', () {
      final meal = MealEntry.fromJson({
        'id': 'meal-2',
        'meal': '點心2',
        'time': '2026-07-18T15:00:00.000Z',
        'items': <dynamic>[],
      });

      expect(meal.meal, '點心2');
      expect(meal.items, isEmpty);
    });

    test('ignores an extra day field from the POST response shape', () {
      final meal = MealEntry.fromJson({
        'id': 'meal-3',
        'day': '2026-07-18',
        'meal': 'breakfast',
        'time': '2026-07-18T08:00:00.000Z',
        'items': <dynamic>[],
      });

      expect(meal.id, 'meal-3');
    });
  });
}
