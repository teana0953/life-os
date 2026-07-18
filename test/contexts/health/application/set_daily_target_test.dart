import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTarget? targetToReturn;
  String? receivedIdToken;
  String? receivedDay;
  double? receivedBaseStaple;
  double? receivedBonusStaple;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    throw UnimplementedError();
  }

  @override
  Future<DailyTarget> setTarget(
    String idToken, {
    required String day,
    required double baseStaple,
    required double baseMeat,
    required double baseFruit,
    required double baseVeg,
    double? bonusStaple,
    double? bonusMeat,
    double? bonusFruit,
    double? bonusVeg,
  }) async {
    receivedIdToken = idToken;
    receivedDay = day;
    receivedBaseStaple = baseStaple;
    receivedBonusStaple = bonusStaple;
    return targetToReturn!;
  }
}

void main() {
  group('SetDailyTarget', () {
    test('sets the target via the repository', () async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = DailyTarget.fromJson({
          'id': 'target-1',
          'day': '2026-07-18',
          'base_staple': 12,
          'base_meat': 6,
          'base_fruit': 4,
          'base_veg': 3,
          'bonus_staple': 0,
          'bonus_meat': 0,
          'bonus_fruit': 0,
          'bonus_veg': 0,
        });
      final setDailyTarget = SetDailyTarget(repository);

      final result = await setDailyTarget(
        'token-123',
        day: '2026-07-18',
        baseStaple: 12,
        baseMeat: 6,
        baseFruit: 4,
        baseVeg: 3,
      );

      expect(result.baseStaple, 12);
      expect(repository.receivedIdToken, 'token-123');
      expect(repository.receivedDay, '2026-07-18');
      expect(repository.receivedBaseStaple, 12);
      expect(repository.receivedBonusStaple, isNull);
    });

    test('passes through optional bonus fields', () async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = DailyTarget.fromJson({
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
      final setDailyTarget = SetDailyTarget(repository);

      await setDailyTarget(
        'token-123',
        day: '2026-07-18',
        baseStaple: 12,
        baseMeat: 6,
        baseFruit: 4,
        baseVeg: 3,
        bonusStaple: 1,
      );

      expect(repository.receivedBonusStaple, 1);
    });
  });
}
