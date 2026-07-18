import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';

void main() {
  group('DailyTargetWithRemaining.fromJson', () {
    test('parses nested base/bonus/effective/logged/remaining portions', () {
      final target = DailyTargetWithRemaining.fromJson({
        'day': '2026-07-18',
        'base': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
        'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
        'effective': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
        'logged': {'staple': 9, 'meat': 3, 'fruit': 1, 'veg': 0},
        'remaining': {'staple': 3, 'meat': 3, 'fruit': 3, 'veg': 3},
      });

      expect(target.day, '2026-07-18');
      expect(target.effective.staple, 12);
      expect(target.logged.staple, 9);
      expect(target.remaining.staple, 3);
    });
  });

  group('DailyTarget.fromJson', () {
    test('parses flat base_/bonus_ fields from the PUT response', () {
      final target = DailyTarget.fromJson({
        'id': 'target-1',
        'day': '2026-07-18',
        'base_staple': 12,
        'base_meat': 6,
        'base_fruit': 4,
        'base_veg': 3,
        'bonus_staple': 1,
        'bonus_meat': 0,
        'bonus_fruit': 0,
        'bonus_veg': 0,
      });

      expect(target.id, 'target-1');
      expect(target.baseStaple, 12);
      expect(target.bonusStaple, 1);
    });
  });
}
