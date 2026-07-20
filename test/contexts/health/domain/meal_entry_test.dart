import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';

Map<String, dynamic> _itemJson({
  String id = 'item-1',
  String? name = '飯/1碗',
  double stapleConsumed = 4,
  double meatConsumed = 0,
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
  'quantity': 1,
  'base_grams': null,
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

void main() {
  group('MealItem.fromJson', () {
    test('parses the nested consumed object as Portions', () {
      final item = MealItem.fromJson(_itemJson());

      expect(item.id, 'item-1');
      expect(item.name, '飯/1碗');
      expect(item.consumed.staple, 4);
      expect(item.consumed.meat, 0);
      expect(item.consumed.fruit, 0);
      expect(item.consumed.veg, 0);
    });

    test('a null name (unnamed dictionary item) parses as null', () {
      final item = MealItem.fromJson(_itemJson(name: null));

      expect(item.name, isNull);
    });

    test('an item consuming only meat parses that category', () {
      final item = MealItem.fromJson(
        _itemJson(stapleConsumed: 0, meatConsumed: 1),
      );

      expect(item.consumed.staple, 0);
      expect(item.consumed.meat, 1);
    });
  });

  group('MealEntry.fromJson', () {
    test('parses id, meal, ISO time as UTC, and items', () {
      final meal = MealEntry.fromJson({
        'id': 'meal-1',
        'meal': 'lunch',
        'time': '2026-07-18T12:30:00.000Z',
        'items': [_itemJson()],
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
