import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';

void main() {
  group('CreateMealItem.dictionary', () {
    test('accepts quantity only', () {
      final item = CreateMealItem.dictionary('rice-1', quantity: 1.5);

      expect(item.foodItemId, 'rice-1');
      expect(item.quantity, 1.5);
      expect(item.measure, isNull);
    });

    test('accepts measure only', () {
      final item = CreateMealItem.dictionary('rice-1', measure: 33);

      expect(item.measure, 33);
      expect(item.quantity, isNull);
    });

    test('asserts quantity and measure are mutually exclusive', () {
      expect(
        () => CreateMealItem.dictionary('rice-1', quantity: 1, measure: 33),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('CreateMealItem.manual', () {
    test('carries a name and portions, no food_item_id/quantity/measure', () {
      const portions = Portions(staple: 1, meat: 1, fruit: 0, veg: 0);

      final item = CreateMealItem.manual('自製便當', portions);

      expect(item.name, '自製便當');
      expect(item.portions, portions);
      expect(item.foodItemId, isNull);
      expect(item.quantity, isNull);
      expect(item.measure, isNull);
    });
  });
}
