import 'package:life_os/shared/screen_batch/section_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/hydration/application/add_water.dart';
import 'package:life_os/contexts/hydration/application/get_water_day.dart';
import 'package:life_os/contexts/hydration/application/set_water_target.dart';
import 'package:life_os/contexts/hydration/domain/water_day.dart';
import 'package:life_os/contexts/hydration/domain/water_exceptions.dart';
import 'package:life_os/contexts/hydration/domain/water_repository.dart';
import 'package:life_os/contexts/hydration/presentation/water_controller.dart';

class FakeWaterRepository implements WaterRepository {
  WaterDay dayToReturn = const WaterDay(
    day: '2026-07-18',
    totalMl: 0,
    targetMl: 2000,
    remainingMl: 2000,
  );

  /// The state to return from [getDay] after a mutation, if set.
  WaterDay? afterMutation;

  Object? getError;
  Object? mutationError;

  int? receivedAddMl;
  int? receivedTargetMl;
  int getDayCallCount = 0;

  @override
  Future<WaterDay> getDay(String idToken, String day) async {
    getDayCallCount++;
    if (getError != null) throw getError!;
    return afterMutation ?? dayToReturn;
  }

  @override
  Future<int> addWater(
    String idToken, {
    required String day,
    required int addMl,
  }) async {
    if (mutationError != null) throw mutationError!;
    receivedAddMl = addMl;
    return 0;
  }

  @override
  Future<int> setTarget(
    String idToken, {
    required String day,
    required int targetMl,
  }) async {
    if (mutationError != null) throw mutationError!;
    receivedTargetMl = targetMl;
    return targetMl;
  }
}

WaterController _controller(FakeWaterRepository repository) => WaterController(
  GetWaterDay(repository),
  AddWater(repository),
  SetWaterTarget(repository),
);

void main() {
  group('WaterController.applyBatchSection', () {
    const record = WaterDay(
      day: '2026-07-18',
      totalMl: 900,
      targetMl: 2000,
      remainingMl: 1100,
    );

    test(
      'ok lands the identical state load() lands for the same payload',
      () async {
        final at = DateTime(2026, 7, 18, 9, 30);
        final repository = FakeWaterRepository()..dayToReturn = record;
        final viaLoad = WaterController(
          GetWaterDay(repository),
          AddWater(repository),
          SetWaterTarget(repository),
          clock: () => at,
        );
        await viaLoad.load('token', '2026-07-18');

        final viaBatch = WaterController(
          GetWaterDay(FakeWaterRepository()),
          AddWater(FakeWaterRepository()),
          SetWaterTarget(FakeWaterRepository()),
          clock: () => at,
        );
        viaBatch.claimBatchRound();
        viaBatch.applyBatchSection(const SectionOk(record));

        expect(viaBatch.status, viaLoad.status);
        expect(viaBatch.error, viaLoad.error);
        expect(viaBatch.lastLoadedAt, viaLoad.lastLoadedAt);
        expect(viaBatch.day!.totalMl, viaLoad.day!.totalMl);
        expect(viaBatch.day!.remainingMl, viaLoad.day!.remainingMl);
      },
    );

    test('unavailable reaches the fetch-failed state, not an empty day', () {
      final controller = _controller(FakeWaterRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(const SectionUnavailable<WaterDay>());

      expect(controller.status, WaterStatus.error);
      expect(controller.error, WaterError.fetchFailed);
      expect(controller.day, isNull);
      expect(controller.lastLoadedAt, isNull);
    });

    test('reauth reaches needsReauth', () {
      final controller = _controller(FakeWaterRepository());

      controller.claimBatchRound();
      controller.applyBatchSection(const SectionReauth<WaterDay>());

      expect(controller.status, WaterStatus.needsReauth);
    });

    // A section with no claim at all (nobody called `claimBatchRound`) must
    // never apply by accident — `_claimedGeneration` defaults to `null`,
    // which cannot equal `_generation`'s starting `0`.
    test('a section nobody claimed a round for is dropped', () {
      final controller = _controller(FakeWaterRepository());

      controller.applyBatchSection(const SectionOk(record));

      expect(controller.day, isNull);
    });

    // The round claimed its generation, then the day-nav header moved this
    // shared controller to another day WHILE the batch was in flight; writing
    // the round's answer now would show one day's total under another day's
    // date.
    test(
      'a section is dropped when a load starts after the round was claimed',
      () async {
        final controller = _controller(FakeWaterRepository());
        controller.claimBatchRound();
        // Started but NOT awaited: `load` bumps the generation synchronously,
        // before its first await, which is the window this guard is about.
        final other = controller.load('token', '2026-07-19');

        controller.applyBatchSection(const SectionOk(record));
        expect(controller.day, isNull);

        await other;
      },
    );

    // Same shape, but the day-nav load has already COMPLETED by the time the
    // stale batch section for the round's original day arrives — no request
    // is "in flight" to catch, so the guard has to compare generations, not
    // just look for a live in-flight load.
    test(
      'a section is dropped when a load already landed after the round was claimed',
      () async {
        final repository = FakeWaterRepository()
          ..dayToReturn = const WaterDay(
            day: '2026-07-19',
            totalMl: 300,
            targetMl: 2000,
            remainingMl: 1700,
          );
        final controller = _controller(repository);
        controller.claimBatchRound();
        await controller.load('token', '2026-07-19');
        expect(controller.day!.day, '2026-07-19');

        controller.applyBatchSection(const SectionOk(record));

        expect(controller.day!.day, '2026-07-19');
      },
    );

    // The over-correction this guard replaced: comparing days instead of
    // generations refused a round whose day simply differed from whatever
    // day the controller already happened to hold, even with NOTHING having
    // navigated since the round was claimed — e.g. the round catching a
    // controller that has sat on a stale day (nobody touched it since) back
    // up to a fresher one. That must still apply.
    test(
      'a section applies even when its day differs from the day already held, '
      'as long as nothing navigated since the round was claimed',
      () async {
        final repository = FakeWaterRepository()
          ..dayToReturn = const WaterDay(
            day: '2026-07-17',
            totalMl: 300,
            targetMl: 2000,
            remainingMl: 1700,
          );
        final controller = _controller(repository);
        await controller.load('token', '2026-07-17');
        expect(controller.day!.day, '2026-07-17');

        controller.claimBatchRound();
        controller.applyBatchSection(const SectionOk(record));

        expect(controller.day!.day, record.day);
        expect(controller.day!.totalMl, record.totalMl);
      },
    );
  });

  group('WaterController.load', () {
    test('loads the day and exposes total/target/remaining', () async {
      final repository = FakeWaterRepository()
        ..dayToReturn = const WaterDay(
          day: '2026-07-18',
          totalMl: 500,
          targetMl: 2000,
          remainingMl: 1500,
        );
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, WaterStatus.loaded);
      expect(controller.day!.totalMl, 500);
      expect(controller.day!.remainingMl, 1500);
    });

    test('a 401 surfaces needsReauth rather than crashing', () async {
      final repository = FakeWaterRepository()
        ..getError = const WaterReauthenticationRequired();
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, WaterStatus.needsReauth);
    });

    test('a fetch failure surfaces an error state', () async {
      final repository = FakeWaterRepository()
        ..getError = const WaterFetchFailure('boom');
      final controller = _controller(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, WaterStatus.error);
      expect(controller.error, WaterError.fetchFailed);
    });
  });

  group('WaterController.addWater', () {
    test('adds water and reloads the day from the backend', () async {
      final repository = FakeWaterRepository();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      repository.afterMutation = const WaterDay(
        day: '2026-07-18',
        totalMl: 250,
        targetMl: 2000,
        remainingMl: 1750,
      );

      await controller.addWater('token', '2026-07-18', 250);

      expect(repository.receivedAddMl, 250);
      // Displayed total comes from the reloaded backend state, not local math.
      expect(controller.day!.totalMl, 250);
      expect(controller.day!.remainingMl, 1750);
    });
  });

  group('WaterController.correct', () {
    test('sends a negative add_ml and reloads (backend clamps ≥0)', () async {
      final repository = FakeWaterRepository()
        ..dayToReturn = const WaterDay(
          day: '2026-07-18',
          totalMl: 200,
          targetMl: 2000,
          remainingMl: 1800,
        );
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');
      repository.afterMutation = const WaterDay(
        day: '2026-07-18',
        totalMl: 0,
        targetMl: 2000,
        remainingMl: 2000,
      );

      await controller.correct('token', '2026-07-18', -250);

      expect(repository.receivedAddMl, -250);
      expect(controller.day!.totalMl, 0);
    });
  });

  group('WaterController.setTarget', () {
    test(
      'sets the target and reloads so progress reflects the new basis',
      () async {
        final repository = FakeWaterRepository()
          ..dayToReturn = const WaterDay(
            day: '2026-07-18',
            totalMl: 500,
            targetMl: 0,
            remainingMl: 0,
          );
        final controller = _controller(repository);
        await controller.load('token', '2026-07-18');
        repository.afterMutation = const WaterDay(
          day: '2026-07-18',
          totalMl: 500,
          targetMl: 2000,
          remainingMl: 1500,
        );

        await controller.setTarget('token', '2026-07-18', 2000);

        expect(repository.receivedTargetMl, 2000);
        expect(controller.day!.targetMl, 2000);
      },
    );

    test('a mutation 401 surfaces needsReauth', () async {
      final repository = FakeWaterRepository()
        ..mutationError = const WaterReauthenticationRequired();
      final controller = _controller(repository);
      await controller.load('token', '2026-07-18');

      await controller.setTarget('token', '2026-07-18', 2000);

      expect(controller.status, WaterStatus.needsReauth);
    });
  });

  group('WaterController.lastLoadedAt', () {
    final at = DateTime(2026, 7, 18, 9, 41);

    WaterController controllerWithClock(FakeWaterRepository repository) =>
        WaterController(
          GetWaterDay(repository),
          AddWater(repository),
          SetWaterTarget(repository),
          clock: () => at,
        );

    test('is null before the first successful load', () {
      final controller = controllerWithClock(FakeWaterRepository());
      expect(controller.lastLoadedAt, isNull);
    });

    test('is set to the clock value on a successful load', () async {
      final controller = controllerWithClock(FakeWaterRepository());

      await controller.load('token', '2026-07-18');

      expect(controller.lastLoadedAt, at);
    });

    test('is left unchanged when a load fails (needsReauth)', () async {
      final repository = FakeWaterRepository();
      final controller = controllerWithClock(repository);
      await controller.load('token', '2026-07-18');
      final firstLoad = controller.lastLoadedAt;

      repository.getError = const WaterReauthenticationRequired();
      await controller.load('token', '2026-07-18');

      expect(controller.status, WaterStatus.needsReauth);
      expect(controller.lastLoadedAt, firstLoad);
    });

    test('stays null after a failed load with no prior success', () async {
      final repository = FakeWaterRepository()
        ..getError = const WaterFetchFailure('boom');
      final controller = controllerWithClock(repository);

      await controller.load('token', '2026-07-18');

      expect(controller.status, WaterStatus.error);
      expect(controller.lastLoadedAt, isNull);
    });
  });
}
