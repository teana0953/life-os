import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';

void main() {
  group('DayMealsLog.fromJson', () {
    test('parses day, meals, and totals as Portions from the flat snake_case object', () {
      final log = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          {
            'id': 'meal-1',
            'meal': 'breakfast',
            'time': '2026-07-18T08:00:00.000Z',
            'items': <dynamic>[],
          },
        ],
        'totals': {
          'carb_g': 60,
          'protein_g': 4,
          'fat_g': 0.5,
          'sugar_g': 0,
          'fiber_g': 1,
          'kcal': 280,
          'staple': 4,
          'meat': 1,
          'fruit': 0,
          'veg': 2,
        },
      });

      expect(log.day, '2026-07-18');
      expect(log.meals, hasLength(1));
      expect(log.meals.single.meal, 'breakfast');
      expect(log.totals.staple, 4);
      expect(log.totals.meat, 1);
      expect(log.totals.fruit, 0);
      expect(log.totals.veg, 2);
    });

    test('parses an empty day with no meals', () {
      final log = DayMealsLog.fromJson({
        'day': '2026-07-18',
        'meals': <dynamic>[],
        'totals': {
          'carb_g': 0,
          'protein_g': 0,
          'fat_g': 0,
          'sugar_g': 0,
          'fiber_g': 0,
          'kcal': 0,
          'staple': 0,
          'meat': 0,
          'fruit': 0,
          'veg': 0,
        },
      });

      expect(log.meals, isEmpty);
      expect(log.totals.staple, 0);
    });
  });
}
