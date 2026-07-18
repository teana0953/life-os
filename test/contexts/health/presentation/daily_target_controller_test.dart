import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/presentation/daily_target_controller.dart';

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;
  DailyTargetWithRemaining? afterSetTarget;
  double? receivedBaseStaple;
  double? receivedBonusStaple;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return afterSetTarget ?? targetToReturn!;
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
    receivedBaseStaple = baseStaple;
    receivedBonusStaple = bonusStaple;
    return DailyTarget.fromJson({
      'id': 'target-1',
      'day': day,
      'base_staple': baseStaple,
      'base_meat': baseMeat,
      'base_fruit': baseFruit,
      'base_veg': baseVeg,
      'bonus_staple': bonusStaple ?? 0,
      'bonus_meat': bonusMeat ?? 0,
      'bonus_fruit': bonusFruit ?? 0,
      'bonus_veg': bonusVeg ?? 0,
    });
  }
}

DailyTargetWithRemaining _target({double baseStaple = 0, double loggedStaple = 9}) =>
    DailyTargetWithRemaining.fromJson({
      'day': '2026-07-18',
      'base': {'staple': baseStaple, 'meat': 6, 'fruit': 4, 'veg': 3},
      'bonus': {'staple': 1, 'meat': 0, 'fruit': 0, 'veg': 0},
      'effective': {'staple': baseStaple + 1, 'meat': 6, 'fruit': 4, 'veg': 3},
      'logged': {'staple': loggedStaple, 'meat': 3, 'fruit': 1, 'veg': 0},
      'remaining': {
        'staple': baseStaple + 1 - loggedStaple,
        'meat': 3,
        'fruit': 3,
        'veg': 3,
      },
    });

void main() {
  group('DailyTargetController.load', () {
    test('loads the target and seeds draft base values', () async {
      final repository = FakeDailyTargetRepository()
        ..targetToReturn = _target(baseStaple: 10);
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, DailyTargetStatus.loaded);
      expect(controller.draftBaseStaple, 10);
    });
  });

  group('DailyTargetController.save', () {
    test(
      'sets the staple target to 12 and reloads remaining reflecting logged',
      () async {
        final repository = FakeDailyTargetRepository()
          ..targetToReturn = _target(baseStaple: 10, loggedStaple: 9);
        final controller = DailyTargetController(
          GetDailyTargetWithRemaining(repository),
          SetDailyTarget(repository),
        );
        await controller.load('token-123', '2026-07-18');
        repository.afterSetTarget = _target(baseStaple: 12, loggedStaple: 9);

        controller.setDraftBaseStaple(12);
        final result = await controller.save('token-123', '2026-07-18');

        expect(result, isTrue);
        expect(repository.receivedBaseStaple, 12);
        // Preserves the previously fetched bonus rather than resetting it.
        expect(repository.receivedBonusStaple, 1);
        expect(controller.target!.remaining.staple, 4);
      },
    );
  });
}
