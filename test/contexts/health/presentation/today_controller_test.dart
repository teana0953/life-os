import 'dart:async';
import 'package:life_os/shared/screen_batch/section_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health/application/change_meal_time.dart';
import 'package:life_os/contexts/health/application/delete_meal.dart';
import 'package:life_os/contexts/health/application/delete_meal_item.dart';
import 'package:life_os/contexts/health/application/edit_meal_item.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/health/application/get_day_meals.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/day_meals_log.dart';
import 'package:life_os/contexts/health/domain/diet_exceptions.dart';
import 'package:life_os/contexts/health/domain/meal_entry.dart';
import 'package:life_os/contexts/health/domain/meal_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/health/presentation/today_controller.dart';

class FakeMealRepository implements MealRepository {
  DayMealsLog? logToReturn;
  Object? errorToThrow;
  Object? mutationErrorToThrow;
  String? receivedDay;

  String? patchedItemId;
  double? patchedQuantity;
  double? patchedMeasure;
  Portions? patchedPortions;
  String? deletedItemId;
  String? patchedMealId;
  DateTime? patchedTime;
  String? deletedMealId;

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) async {
    receivedDay = day;
    if (errorToThrow != null) throw errorToThrow!;
    return logToReturn!;
  }

  @override
  Future<MealEntry> createMeal(
    String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<String>> loggedDays(String idToken, String month) async {
    throw UnimplementedError();
  }

  @override
  Future<void> patchMealItem(
    String idToken,
    String id, {
    double? quantity,
    double? measure,
    Portions? portions,
  }) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    patchedItemId = id;
    patchedQuantity = quantity;
    patchedMeasure = measure;
    patchedPortions = portions;
  }

  @override
  Future<void> deleteMealItem(String idToken, String id) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    deletedItemId = id;
  }

  @override
  Future<void> patchMealTime(String idToken, String id, DateTime time) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    patchedMealId = id;
    patchedTime = time;
  }

  @override
  Future<void> deleteMeal(String idToken, String id) async {
    if (mutationErrorToThrow != null) throw mutationErrorToThrow!;
    deletedMealId = id;
  }
}

class FakeDailyTargetRepository implements DailyTargetRepository {
  DailyTargetWithRemaining? targetToReturn;

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    return targetToReturn!;
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
    throw UnimplementedError();
  }
}

DayMealsLog _dayLog() => DayMealsLog.fromJson({
  'day': '2026-07-18',
  'meals': [
    {
      'id': 'meal-breakfast',
      'meal': 'breakfast',
      'time': '2026-07-18T08:00:00.000Z',
      'items': <dynamic>[],
    },
    {
      'id': 'meal-lunch',
      'meal': 'lunch',
      'time': '2026-07-18T12:30:00.000Z',
      'items': <dynamic>[],
    },
  ],
  'totals': {
    'carb_g': 20,
    'protein_g': 4,
    'fat_g': 2,
    'sugar_g': 0,
    'fiber_g': 0,
    'kcal': 120,
    'staple': 9,
    'meat': 3,
    'fruit': 1,
    'veg': 0,
  },
});

DailyTargetWithRemaining _target() => DailyTargetWithRemaining.fromJson({
  'day': '2026-07-18',
  'base': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
  'bonus': {'staple': 0, 'meat': 0, 'fruit': 0, 'veg': 0},
  'effective': {'staple': 12, 'meat': 6, 'fruit': 4, 'veg': 3},
  'logged': {'staple': 9, 'meat': 3, 'fruit': 1, 'veg': 0},
  'remaining': {'staple': 3, 'meat': 3, 'fruit': 3, 'veg': 3},
});

TodayController _controller(
  FakeMealRepository mealRepository,
  FakeDailyTargetRepository targetRepository,
) {
  return TodayController(
    GetDayMeals(mealRepository),
    GetDailyTargetWithRemaining(targetRepository),
    EditMealItem(mealRepository),
    DeleteMealItem(mealRepository),
    ChangeMealTime(mealRepository),
    DeleteMeal(mealRepository),
  );
}

void main() {
  group('TodayController.applyBatchSection', () {
    TodayController fresh() => _controller(
      FakeMealRepository()..logToReturn = _dayLog(),
      FakeDailyTargetRepository()..targetToReturn = _target(),
    );

    test(
      'ok lands the identical state load() lands for the same payload',
      () async {
        final viaLoad = fresh();
        await viaLoad.load('token-123', '2026-07-18');

        final viaBatch = fresh();
        viaBatch.claimBatchRound();
        viaBatch.applyBatchSection(
          meals: SectionOk(_dayLog()),
          dailyTarget: SectionOk(_target()),
        );

        expect(viaBatch.status, viaLoad.status);
        expect(viaBatch.error, viaLoad.error);
        expect(
          viaBatch.dayMealsLog!.meals.map((m) => m.meal),
          viaLoad.dayMealsLog!.meals.map((m) => m.meal),
        );
        expect(
          viaBatch.dayMealsLog!.totals.staple,
          viaLoad.dayMealsLog!.totals.staple,
        );
        expect(
          viaBatch.target!.effective.staple,
          viaLoad.target!.effective.staple,
        );
      },
    );

    test('an unavailable meals section reaches the fetch-failed state', () {
      final controller = fresh();

      controller.claimBatchRound();
      controller.applyBatchSection(
        meals: const SectionUnavailable<DayMealsLog>(),
        dailyTarget: SectionOk(_target()),
      );

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.fetchFailed);
      expect(controller.dayMealsLog, isNull);
    });

    // load() assigns dayMealsLog BEFORE fetching the target, so a run whose
    // target read failed ends on error WITH the log already held. The batch
    // path has to reproduce that, not tidy it up.
    test('meals ok + target unavailable keeps the log and still errors', () {
      final controller = fresh();

      controller.claimBatchRound();
      controller.applyBatchSection(
        meals: SectionOk(_dayLog()),
        dailyTarget: const SectionUnavailable<DailyTargetWithRemaining>(),
      );

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.fetchFailed);
      expect(controller.dayMealsLog, isNotNull);
      expect(controller.target, isNull);
    });

    test('reauth on either section reaches needsReauth', () {
      final controller = fresh();

      controller.claimBatchRound();
      controller.applyBatchSection(
        meals: SectionOk(_dayLog()),
        dailyTarget: const SectionReauth<DailyTargetWithRemaining>(),
      );

      expect(controller.status, TodayStatus.needsReauth);
    });

    // A section with no claim at all (nobody called `claimBatchRound`) must
    // never apply by accident.
    test('a section nobody claimed a round for is dropped', () {
      final controller = fresh();

      controller.applyBatchSection(
        meals: SectionOk(_dayLog()),
        dailyTarget: SectionOk(_target()),
      );

      expect(controller.dayMealsLog, isNull);
    });

    // The diet day's own navigation moved this shared controller to another
    // day while the batch was out; writing the round's day now would show one
    // day's meals under another day's header.
    test(
      'a section is dropped when a load starts after the round was claimed',
      () async {
        final controller = fresh();
        controller.claimBatchRound();
        // Started but NOT awaited: `load` bumps the generation synchronously,
        // before its first await, so the claim is stale at exactly the moment
        // the batch response would land. Awaiting anything here would let the
        // fake settle and close the window this guard is about.
        final other = controller.load('token-123', '2026-07-19');

        controller.applyBatchSection(
          meals: SectionOk(_dayLog()),
          dailyTarget: SectionOk(_target()),
        );
        expect(controller.status, TodayStatus.loading);
        expect(controller.target, isNull);

        await other;
        expect(controller.dayMealsLog!.day, '2026-07-18');
      },
    );

    // Same shape, but the diet day's load has already COMPLETED by the time
    // the stale batch section arrives.
    test(
      'a section is dropped when a load already landed after the round was claimed',
      () async {
        final controller = fresh();
        controller.claimBatchRound();
        await controller.load('token-123', '2026-07-19');
        final heldStatus = controller.status;
        final heldLog = controller.dayMealsLog;

        controller.applyBatchSection(
          meals: SectionOk(_dayLog()),
          dailyTarget: const SectionUnavailable<DailyTargetWithRemaining>(),
        );

        expect(controller.status, heldStatus);
        expect(controller.dayMealsLog, heldLog);
      },
    );

    // The over-correction a day comparison would cause: a round whose day
    // simply differs from whatever day the controller already holds must
    // still apply, as long as nothing navigated since the round was claimed
    // (e.g. the round catching a stale controller up to a fresher day once
    // the diet day screen showing it is gone).
    test(
      'a section applies even when its day differs from the day already held, '
      'as long as nothing navigated since the round was claimed',
      () async {
        final controller = fresh();
        await controller.load('token-123', '2026-07-17');
        expect(controller.dayMealsLog, isNotNull);

        controller.claimBatchRound();
        controller.applyBatchSection(
          meals: SectionOk(_dayLog()),
          dailyTarget: SectionOk(_target()),
        );

        expect(controller.status, TodayStatus.loaded);
        expect(controller.dayMealsLog!.day, '2026-07-18');
      },
    );
  });

  group('TodayController.load', () {
    test('loads the day meals log and target', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.loaded);
      expect(controller.dayMealsLog!.meals.map((m) => m.meal), [
        'breakfast',
        'lunch',
      ]);
      expect(controller.dayMealsLog!.totals.staple, 9);
      expect(controller.target!.effective.staple, 12);
      expect(mealRepository.receivedDay, '2026-07-18');
    });

    test('sets error status on DietFetchFailure', () async {
      final mealRepository = FakeMealRepository()
        ..errorToThrow = const DietFetchFailure('server error');
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.error);
      expect(controller.error, TodayError.fetchFailed);
    });

    test('sets needsReauth status on DietReauthenticationRequired', () async {
      final mealRepository = FakeMealRepository()
        ..errorToThrow = const DietReauthenticationRequired();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.load('token-123', '2026-07-18');

      expect(controller.status, TodayStatus.needsReauth);
    });
  });

  group('TodayController mutations', () {
    test('editItem sends quantity and reloads the day', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.editItem(
        'token-123',
        '2026-07-18',
        'item-1',
        quantity: 2,
      );

      expect(mealRepository.patchedItemId, 'item-1');
      expect(mealRepository.patchedQuantity, 2);
      expect(mealRepository.patchedMeasure, isNull);
      expect(mealRepository.receivedDay, '2026-07-18');
      expect(controller.status, TodayStatus.loaded);
    });

    test('editItem sends measure (no quantity)', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.editItem(
        'token-123',
        '2026-07-18',
        'item-1',
        measure: 80,
      );

      expect(mealRepository.patchedMeasure, 80);
      expect(mealRepository.patchedQuantity, isNull);
    });

    test('editItem sends portions', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);
      const portions = Portions(staple: 3, meat: 1, fruit: 0, veg: 0);

      await controller.editItem(
        'token-123',
        '2026-07-18',
        'item-1',
        portions: portions,
      );

      expect(mealRepository.patchedPortions, portions);
    });

    test('deleteItem deletes and reloads the day', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteItem('token-123', '2026-07-18', 'item-1');

      expect(mealRepository.deletedItemId, 'item-1');
      expect(controller.status, TodayStatus.loaded);
    });

    test('changeMealTime patches the meal\'s time and reloads', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);
      final time = DateTime.utc(2026, 7, 18, 9);

      await controller.changeMealTime(
        'token-123',
        '2026-07-18',
        'meal-lunch',
        time,
      );

      expect(mealRepository.patchedMealId, 'meal-lunch');
      expect(mealRepository.patchedTime, time);
      expect(controller.status, TodayStatus.loaded);
    });

    test('deleteMeal deletes and reloads the day', () async {
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteMeal('token-123', '2026-07-18', 'meal-lunch');

      expect(mealRepository.deletedMealId, 'meal-lunch');
      expect(controller.status, TodayStatus.loaded);
    });

    test('a reauth failure sets needsReauth', () async {
      final mealRepository = FakeMealRepository()
        ..logToReturn = _dayLog()
        ..mutationErrorToThrow = const DietReauthenticationRequired();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.deleteItem('token-123', '2026-07-18', 'item-1');

      expect(controller.status, TodayStatus.needsReauth);
    });

    test(
      'a not-found failure sets an error status with TodayError.notFound',
      () async {
        final mealRepository = FakeMealRepository()
          ..logToReturn = _dayLog()
          ..mutationErrorToThrow = const DietNotFound();
        final targetRepository = FakeDailyTargetRepository()
          ..targetToReturn = _target();
        final controller = _controller(mealRepository, targetRepository);

        await controller.deleteItem('token-123', '2026-07-18', 'not-mine');

        expect(controller.status, TodayStatus.error);
        expect(controller.error, TodayError.notFound);
      },
    );

    test(
      'a fetch failure sets an error status with TodayError.fetchFailed',
      () async {
        final mealRepository = FakeMealRepository()
          ..logToReturn = _dayLog()
          ..mutationErrorToThrow = const DietFetchFailure('boom');
        final targetRepository = FakeDailyTargetRepository()
          ..targetToReturn = _target();
        final controller = _controller(mealRepository, targetRepository);

        await controller.deleteMeal('token-123', '2026-07-18', 'meal-lunch');

        expect(controller.status, TodayStatus.error);
        expect(controller.error, TodayError.fetchFailed);
      },
    );
  });

  group('TodayController: the in-flight claim registry', () {
    test(
      'a load that finishes first does not clear a slower load\'s claim',
      () async {
        final mealRepository = _GatedMealRepository(_dayLog());
        final targetRepository = FakeDailyTargetRepository()
          ..targetToReturn = _target();
        final controller = _controller(mealRepository, targetRepository);

        // Two loads in flight at once — the shape a URL-driven entry produces
        // (the health shell and the diet day both loading) and the shape a
        // day-nav tap produces while a previous day is still coming back.
        final slow = controller.load('token', '2026-07-18');
        final fast = controller.load('token', '2026-07-19');
        expect(controller.isLoadingDay('2026-07-18'), isTrue);
        expect(controller.isLoadingDay('2026-07-19'), isTrue);

        mealRepository.release('2026-07-19');
        await fast;

        // THE invariant. A single `String? loadingDay` field cannot hold it:
        // both loads write the one slot, so the load that lands FIRST clears
        // it for the other too and every reader is told "nothing is in
        // flight" while the 18th is still being fetched. Keyed by request id,
        // an entry exists iff that specific call is unsettled.
        expect(controller.isLoadingDay('2026-07-19'), isFalse);
        expect(
          controller.isLoadingDay('2026-07-18'),
          isTrue,
          reason: 'the slower load is still in flight',
        );
        // The derived getter the dictionary screen reads ("is anyone
        // loading?") must answer the same way.
        expect(controller.loadingDay, '2026-07-18');

        mealRepository.release('2026-07-18');
        await slow;
        expect(controller.loadingDay, isNull);
        expect(controller.isLoadingDay('2026-07-18'), isFalse);
      },
    );

    test('a failed load releases its own claim', () async {
      final mealRepository = FakeMealRepository()
        ..errorToThrow = const DietFetchFailure('boom');
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      await controller.load('token', '2026-07-18');

      // Via `finally`: a claim left behind by a throwing load would tell every
      // later reader that a fetch is in flight forever.
      expect(controller.status, TodayStatus.error);
      expect(controller.isLoadingDay('2026-07-18'), isFalse);
      expect(controller.loadingDay, isNull);
    });

    test('holdsDay answers for the day HELD, not the day requested', () async {
      // The fake answers with the 18th's log whatever day it is asked for, so
      // the requested day and the held day DISAGREE here on purpose. An
      // implementation that remembered the day it last asked for (instead of
      // reading the log it actually holds) would pass a test where the two
      // always match — and would tell the shell "I hold the 19th" while the
      // 18th is on screen, which is the exact wrong-day bug this getter
      // exists to prevent.
      final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
      final targetRepository = FakeDailyTargetRepository()
        ..targetToReturn = _target();
      final controller = _controller(mealRepository, targetRepository);

      expect(controller.holdsDay('2026-07-18'), isFalse);
      await controller.load('token', '2026-07-19');

      expect(controller.holdsDay('2026-07-19'), isFalse);
      expect(controller.holdsDay('2026-07-18'), isTrue);
    });

    test(
      'a FAILED load does not make holdsDay claim the day it asked for',
      () async {
        final mealRepository = FakeMealRepository()..logToReturn = _dayLog();
        final targetRepository = FakeDailyTargetRepository()
          ..targetToReturn = _target();
        final controller = _controller(mealRepository, targetRepository);

        await controller.load('token', '2026-07-18');
        // The MEALS read itself is what fails here, so `load` never reaches the
        // assignment and the previous day's log stays in place — the controller
        // still holds the 18th. Note this is the only failure shape with that
        // property: `dayMealsLog` is assigned BEFORE the target read, so a run
        // whose meals landed and whose TARGET read failed ends on
        // `TodayStatus.error` already holding the new day. That is why
        // `health_scaffold.dart` pairs `holdsDay` with `status == loaded`
        // instead of trusting `holdsDay` alone.
        mealRepository.errorToThrow = const DietFetchFailure('boom');
        await controller.load('token', '2026-07-19');

        expect(controller.status, TodayStatus.error);
        expect(
          controller.holdsDay('2026-07-19'),
          isFalse,
          reason:
              'nothing was fetched — claiming the 19th would make the shell '
              'stand down and leave the 18th on screen under the 19th\'s header',
        );
        expect(controller.holdsDay('2026-07-18'), isTrue);
      },
    );
  });
}

/// A meals repository whose answer for each day is parked until the test
/// releases it — the only way to hold two loads in flight at the same time
/// and choose which one lands first.
class _GatedMealRepository extends FakeMealRepository {
  final DayMealsLog _log;
  final _gates = <String, Completer<DayMealsLog>>{};

  _GatedMealRepository(this._log);

  void release(String day) => _gates[day]!.complete(_log);

  @override
  Future<DayMealsLog> getDayMeals(String idToken, String day) {
    return (_gates[day] = Completer<DayMealsLog>()).future;
  }
}
