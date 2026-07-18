import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';

void main() {
  group('FoodItem.fromJson', () {
    test('parses all fields including base_grams', () {
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
        'base_grams': null,
      });

      expect(item.id, 'item-1');
      expect(item.ownerUserId, isNull);
      expect(item.name, '飯/1碗');
      expect(item.staple, 4);
      expect(item.baseGrams, isNull);
    });

    test('parses base_grams when present', () {
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
        'base_grams': 50,
      });

      expect(item.ownerUserId, 'user-1');
      expect(item.baseGrams, 50);
    });
  });
}
