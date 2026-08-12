import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/set_daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
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

  group('DailyTargetController: the in-flight claim registry', () {
    test(
      'a load that finishes first does not clear a slower load\'s claim',
      () async {
        final repository = _GatedDailyTargetRepository(_target());
        final controller = DailyTargetController(
          GetDailyTargetWithRemaining(repository),
          SetDailyTarget(repository),
        );

        final slow = controller.load('token', '2026-07-18');
        final fast = controller.load('token', '2026-07-19');
        expect(controller.isLoadingDay('2026-07-18'), isTrue);
        expect(controller.isLoadingDay('2026-07-19'), isTrue);

        repository.release('2026-07-19');
        await fast;

        // Same invariant as `TodayController`'s, and the same reason it is a
        // per-request registry and not one field: whichever load lands first
        // would otherwise clear the other's signal too, and the health shell
        // reads this to decide whether the diet day below it is already
        // fetching the day.
        expect(controller.isLoadingDay('2026-07-19'), isFalse);
        expect(
          controller.isLoadingDay('2026-07-18'),
          isTrue,
          reason: 'the slower load is still in flight',
        );

        repository.release('2026-07-18');
        await slow;
        expect(controller.isLoadingDay('2026-07-18'), isFalse);
      },
    );

    test('a failed load releases its own claim', () async {
      final repository = _ThrowingDailyTargetRepository();
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );

      await controller.load('token', '2026-07-18');

      expect(controller.status, DailyTargetStatus.error);
      expect(controller.isLoadingDay('2026-07-18'), isFalse);
    });

    test('holdsDay answers for the day HELD, not the day requested', () async {
      // The fake answers with the 18th's target whatever day it is asked for,
      // so the requested day and the held day DISAGREE here on purpose: an
      // implementation that remembered the day it last asked for would pass a
      // test where the two always match, and would tell the shell "I hold the
      // 19th" while the 18th's numbers are on screen.
      final repository = FakeDailyTargetRepository()..targetToReturn = _target();
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );

      expect(controller.holdsDay('2026-07-18'), isFalse);
      await controller.load('token', '2026-07-19');

      expect(controller.holdsDay('2026-07-19'), isFalse);
      expect(controller.holdsDay('2026-07-18'), isTrue);
    });

    test('a FAILED load does not make holdsDay claim the day it asked for', () async {
      final repository = _FailingOnDayDailyTargetRepository('2026-07-19')
        ..targetToReturn = _target();
      final controller = DailyTargetController(
        GetDailyTargetWithRemaining(repository),
        SetDailyTarget(repository),
      );

      await controller.load('token', '2026-07-18');
      await controller.load('token', '2026-07-19');

      expect(controller.status, DailyTargetStatus.error);
      expect(
        controller.holdsDay('2026-07-19'),
        isFalse,
        reason:
            'nothing was fetched — claiming the 19th would make the shell '
            'stand down over the 18th\'s numbers',
      );
      expect(controller.holdsDay('2026-07-18'), isTrue);
    });
  });
}

/// A target repository whose answer for each day is parked until the test
/// releases it — the only way to hold two loads in flight at once and choose
/// which one lands first.
class _GatedDailyTargetRepository extends FakeDailyTargetRepository {
  final DailyTargetWithRemaining _value;
  final _gates = <String, Completer<DailyTargetWithRemaining>>{};

  _GatedDailyTargetRepository(this._value);

  void release(String day) => _gates[day]!.complete(_value);

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) {
    return (_gates[day] = Completer<DailyTargetWithRemaining>()).future;
  }
}

/// Answers normally except for one day, which always fails — so a load can
/// fail with an EARLIER day's target already held.
class _FailingOnDayDailyTargetRepository extends FakeDailyTargetRepository {
  final String failingDay;

  _FailingOnDayDailyTargetRepository(this.failingDay);

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    if (day == failingDay) throw const DietFetchFailure('boom');
    return super.getTarget(idToken, day);
  }
}

class _ThrowingDailyTargetRepository extends FakeDailyTargetRepository {
  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    throw const DietFetchFailure('boom');
  }
}
