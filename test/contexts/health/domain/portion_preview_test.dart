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
  'base_amount': null,
  'measure_unit': null,
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
  'base_amount': 50,
  'measure_unit': 'g',
});

void main() {
  group('previewPortionsForQuantity', () {
    test('scales portions by quantity — 飯/1碗 x1.5 -> 6 staple', () {
      final preview = previewPortionsForQuantity(_riceBowl(), 1.5);

      expect(preview.staple, 6);
      expect(preview.meat, 0);
    });
  });

  group('quantityFromMeasure', () {
    test('converts a measure amount to quantity via base amount — 33g of 飯/50g -> ~0.66', () {
      final quantity = quantityFromMeasure(33, _rice50g().baseAmount);

      expect(quantity, closeTo(0.66, 0.001));
    });

    test('returns null when base amount is null', () {
      expect(quantityFromMeasure(33, null), isNull);
    });

    test('returns null for non-positive measure', () {
      expect(quantityFromMeasure(0, 50), isNull);
      expect(quantityFromMeasure(-5, 50), isNull);
    });

    test('returns null for non-positive base amount', () {
      expect(quantityFromMeasure(10, 0), isNull);
    });
  });
}
