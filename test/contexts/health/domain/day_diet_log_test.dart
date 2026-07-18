import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/day_diet_log.dart';

Map<String, dynamic> _entryJson(String meal, String eatenAt) => {
  'id': 'entry-$meal-$eatenAt',
  'day': '2026-07-18',
  'meal': meal,
  'name': 'food',
  'photo_ref': null,
  'source': 'dict',
  'unclassified': false,
  'carb_g': 10,
  'protein_g': 2,
  'fat_g': 1,
  'sugar_g': 0,
  'fiber_g': 0,
  'kcal': 60,
  'staple': 1,
  'meat': 0,
  'fruit': 0,
  'veg': 0,
  'eaten_at': eatenAt,
  'logged_at': eatenAt,
};

void main() {
  group('DayDietLog.fromJson', () {
    test('parses meals grouped by meal name in the given order', () {
      final log = DayDietLog.fromJson({
        'day': '2026-07-18',
        'meals': [
          {
            'meal': 'breakfast',
            'entries': [_entryJson('breakfast', '2026-07-18T08:00:00.000Z')],
          },
          {
            'meal': 'lunch',
            'entries': [_entryJson('lunch', '2026-07-18T12:30:00.000Z')],
          },
        ],
        'totals': {
          'carbG': 20,
          'proteinG': 4,
          'fatG': 2,
          'sugarG': 0,
          'fiberG': 0,
          'kcal': 120,
        },
      });

      expect(log.day, '2026-07-18');
      expect(log.meals.map((m) => m.meal), ['breakfast', 'lunch']);
      expect(log.meals[0].entries.single.meal, 'breakfast');
      expect(log.totals.carbG, 20);
      expect(log.totals.kcal, 120);
    });
  });
}
