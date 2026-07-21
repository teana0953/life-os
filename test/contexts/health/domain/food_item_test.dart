import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';

void main() {
  group('FoodItem.fromJson', () {
    test('parses all fields, base_amount and measure_unit null when absent', () {
      final item = FoodItem.fromJson({
        'id': 'item-1',
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
        'base_amount': null,
        'measure_unit': null,
      });

      expect(item.id, 'item-1');
      expect(item.ownerUserId, isNull);
      expect(item.name, '飯/1碗');
      expect(item.staple, 4);
      expect(item.baseAmount, isNull);
      expect(item.measureUnit, isNull);
    });

    test('parses base_amount + measure_unit "g" when present', () {
      final item = FoodItem.fromJson({
        'id': 'item-2',
        'owner_user_id': 'user-1',
        'name': '飯/50g',
        'carb_g': 15,
        'protein_g': 1,
        'fat_g': 0.1,
        'sugar_g': 0,
        'fiber_g': 0.2,
        'kcal': 70,
        'staple': 1,
        'meat': 0,
        'fruit': 0,
        'veg': 0,
        'base_amount': 50,
        'measure_unit': 'g',
      });

      expect(item.ownerUserId, 'user-1');
      expect(item.baseAmount, 50);
      expect(item.measureUnit, 'g');
    });

    test('parses measure_unit "ml" when present', () {
      final item = FoodItem.fromJson({
        'id': 'item-3',
        'owner_user_id': null,
        'name': '牛奶/240ml',
        'carb_g': 12,
        'protein_g': 8,
        'fat_g': 8,
        'sugar_g': 12,
        'fiber_g': 0,
        'kcal': 150,
        'staple': 0,
        'meat': 1,
        'fruit': 0,
        'veg': 0,
        'base_amount': 240,
        'measure_unit': 'ml',
      });

      expect(item.baseAmount, 240);
      expect(item.measureUnit, 'ml');
    });
  });
}
