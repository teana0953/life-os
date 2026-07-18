import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/food_item.dart';
import 'package:life_os/contexts/health/domain/portion_preview.dart';

FoodItem _riceBowl() => FoodItem.fromJson({
  'id': 'rice-bowl',
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

FoodItem _rice50g() => FoodItem.fromJson({
  'id': 'rice-50g',
  'owner_user_id': null,
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

void main() {
  group('previewPortionsForQuantity', () {
    test('scales portions by quantity — 飯/1碗 x1.5 -> 6 staple', () {
      final preview = previewPortionsForQuantity(_riceBowl(), 1.5);

      expect(preview.staple, 6);
      expect(preview.meat, 0);
    });
  });

  group('quantityFromGrams', () {
    test('converts grams to quantity via base grams — 33g of 飯/50g -> ~0.66', () {
      final quantity = quantityFromGrams(33, _rice50g().baseGrams);

      expect(quantity, closeTo(0.66, 0.001));
    });

    test('returns null when base grams is null', () {
      expect(quantityFromGrams(33, null), isNull);
    });

    test('returns null for non-positive grams', () {
      expect(quantityFromGrams(0, 50), isNull);
      expect(quantityFromGrams(-5, 50), isNull);
    });

    test('returns null for non-positive base grams', () {
      expect(quantityFromGrams(10, 0), isNull);
    });
  });
}
