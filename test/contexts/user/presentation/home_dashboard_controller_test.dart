import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/body_profile/application/get_weight_goal.dart';
import 'package:life_os/contexts/finance/application/list_finance_budgets.dart';
import 'package:life_os/contexts/finance/application/networth_use_cases.dart';
import 'package:life_os/contexts/health/application/get_daily_target_with_remaining.dart';
import 'package:life_os/contexts/menstrual/application/get_menstrual_overview.dart';
import 'package:life_os/contexts/split/application/balance_use_cases.dart';
import 'package:life_os/contexts/user/presentation/home_dashboard_controller.dart';
import 'package:life_os/contexts/vitals/application/get_vitals_trends.dart';

import 'dashboard_repositories_fake.dart';

void main() {
  HomeDashboardController controllerFor(FakeDashboardRepositories repos) =>
      HomeDashboardController(
        GetWeightGoal(repos),
        GetVitalsTrends(repos),
        GetMenstrualOverview(repos),
        ListFinanceBudgets(repos),
        GetMonthlyNetWorth(repos),
        GetBalances(repos),
        GetDailyTargetWithRemaining(repos),
      );

  test('a successful load stamps lastLoadedAt with the `now` it was given', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);

    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

    expect(controller.status, HomeDashboardStatus.loaded);
    expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 9, 30));
  });

  test(
    'the fan-out asks the daily-target arm for the calendar day of the `now` '
    'it was handed, and keeps the answer',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);

      // Just after local midnight, so that in a UTC+n zone `now.toUtc()`
      // falls on the PREVIOUS calendar day: the arm must be asked for the
      // day the screen is showing, which is the local date.
      //
      // Honest caveat: that half of it is only observable where local time
      // is not UTC. Measured — replacing `dayString(now)` with
      // `dayString(now.toUtc())` fails this test at the machine's UTC+8 but
      // survives under `TZ=UTC`, where the two are the same string. What
      // fails in BOTH is asking for any other day at all (measured with
      // `now.subtract(const Duration(days: 1))`).
      await controller.load('tok', DateTime(2026, 3, 1, 0, 30));

      expect(repos.targetDays, ['2026-03-01']);
      expect(controller.data!.dailyTarget!.effective.staple, 10);
      expect(controller.data!.dailyTarget!.effective.veg, 2);
    },
  );

  // ---- the daily-target arm is the ONLY one allowed to fail on its own.
  //
  // These two are a pair and have to stay one: the first says a failing
  // target arm does not take the dashboard down, the second says a failing
  // *dashboard* still does. They are deliberately on opposite sides of the
  // same seam.
  //
  // Measured by mutation, and one result is an honest caveat:
  //
  // | mutation | result |
  // | --- | --- |
  // | drop the target arm's `onError` | RED — `Expected: loaded / Actual: error` |
  // | catch block sets `loaded` instead of `error` | RED — `Expected: error / Actual: loaded` |
  // | give the other six arms an `onError => null` too | **GREEN** |
  //
  // That last one survives, and not because the second test is vacuous: with
  // the six arms nulled, `results[0] as WeightGoal` throws on the null and
  // the catch below still reports `error`. So the mutant is not the
  // regression it looks like, and the assertion this file *can* make about
  // "only one arm degrades" is the field-by-field check in the first test —
  // not a claim that the other six could never be given their own fallback.
  test(
    'the daily-target arm failing alone degrades that one field to null and '
    'leaves the other six loaded',
    () async {
      final repos = FakeDashboardRepositories();
      repos.failingArms.add('target');
      final controller = controllerFor(repos);

      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

      expect(controller.status, HomeDashboardStatus.loaded);
      expect(controller.data!.dailyTarget, isNull);
      // The six that must have survived — named individually, so a future
      // blanket `onError` on another arm cannot hide behind this one.
      expect(controller.data!.weightGoal.currentWeightKg, 62.5);
      expect(controller.data!.bloodPressure, isNull);
      expect(controller.data!.menstrualStatus, isNotNull);
      expect(controller.data!.overallBudget, isNotNull);
      expect(controller.data!.netWorth.netWorth, 530900);
      expect(controller.data!.splitBalances, hasLength(1));
    },
  );

  test('a whole-fan-out failure is still the error state, not a blank load', () async {
    final repos = FakeDashboardRepositories();
    repos.fail = true;
    final controller = controllerFor(repos);

    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

    expect(controller.status, HomeDashboardStatus.error);
    expect(controller.data, isNull);
  });

  test('a failed load leaves lastLoadedAt exactly where it was', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);
    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

    repos.fail = true;
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    expect(controller.status, HomeDashboardStatus.error);
    expect(
      controller.lastLoadedAt,
      DateTime(2026, 1, 1, 9, 30),
      reason: 'a failed round must not claim the data was just refreshed',
    );
  });

  test('a failed load keeps the data already on hand', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);
    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
    final loaded = controller.data;

    repos.fail = true;
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    expect(controller.data, same(loaded));
  });

  test(
    'reset() clears lastLoadedAt along with the data (sign-out leaves no '
    'per-user state behind)',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
      expect(controller.lastLoadedAt, isNotNull);

      controller.reset();

      expect(controller.data, isNull);
      expect(controller.status, HomeDashboardStatus.idle);
      expect(controller.lastLoadedAt, isNull);
    },
  );

  test(
    'a load started while one is already in flight rides the same round '
    'instead of firing a second fan-out',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      final gate = Completer<void>();
      repos.gate = gate;

      var firstSettled = false;
      var secondSettled = false;
      unawaited(
        controller.load('tok', DateTime(2026, 1, 1, 9, 30)).then((_) {
          firstSettled = true;
        }),
      );
      // Let the fan-out reach the gate.
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1);

      unawaited(
        controller.load('tok', DateTime(2026, 1, 1, 9, 31)).then((_) {
          secondSettled = true;
        }),
      );
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1, reason: 'the second call must not start a round');
      expect(firstSettled, isFalse);
      expect(secondSettled, isFalse);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(firstSettled, isTrue);
      expect(secondSettled, isTrue);
      expect(repos.rounds, 1);
      // The round that ran is the first one — its `now`, not the second call's.
      expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 9, 30));
    },
  );

  test(
    'reset() while a round is in flight lets the next load start a fresh '
    "round for the new user, instead of riding the old user's future",
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      final gate = Completer<void>();
      repos.gate = gate;

      // User A's fan-out starts and parks on the gate.
      unawaited(controller.load('tokenA', DateTime(2026, 1, 1, 9, 30)));
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1);

      // User A signs out while that round is still in flight.
      controller.reset();

      // User B signs in and loads.
      final loadB = controller.load('tokenB', DateTime(2026, 1, 1, 10, 0));
      await Future<void>.delayed(Duration.zero);

      expect(
        repos.rounds,
        2,
        reason:
            "a fresh round must start for user B, not reuse user A's in-flight future",
      );
      expect(repos.goalTokens, contains('tokenB'));

      // Let both rounds finish so the gated arms don't leak into other tests.
      gate.complete();
      await loadB;
      await Future<void>.delayed(Duration.zero);

      expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 10, 0));
    },
  );

  test(
    'a round that was in flight at reset() must not write its result onto the '
    'controller afterwards',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      final gate = Completer<void>();
      repos.gate = gate;

      // User A's fan-out starts and parks on the gate.
      final roundA = controller.load('tokenA', DateTime(2026, 1, 1, 9, 30));
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1);

      // User A signs out while that round is still in flight.
      controller.reset();

      // The outgoing round now completes successfully.
      gate.complete();
      await roundA;
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.data,
        isNull,
        reason: "the outgoing user's round must not land data on a reset controller",
      );
      expect(controller.status, HomeDashboardStatus.idle);
      expect(controller.lastLoadedAt, isNull);
    },
  );

  test(
    'a round that was in flight at reset() must not write an error status '
    'afterwards either',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      final gate = Completer<void>();
      repos.gate = gate;
      repos.fail = true;

      final roundA = controller.load('tokenA', DateTime(2026, 1, 1, 9, 30));
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1);

      controller.reset();

      // The outgoing round now fails.
      gate.complete();
      await roundA;
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.status,
        HomeDashboardStatus.idle,
        reason:
            "the outgoing user's failure must not paint an error on the next user's screen",
      );
      expect(controller.data, isNull);
      expect(controller.lastLoadedAt, isNull);
    },
  );

  test(
    'an old round finishing after reset() must not clear the newer round\'s '
    'in-flight slot',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      final gateA = Completer<void>();
      repos.gate = gateA;

      // User A's round starts and parks on gate A.
      final roundA = controller.load('tokenA', DateTime(2026, 1, 1, 9, 30));
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 1);

      controller.reset();

      // User B's round starts and parks on its own gate.
      final gateB = Completer<void>();
      repos.gate = gateB;
      final roundB = controller.load('tokenB', DateTime(2026, 1, 1, 10, 0));
      await Future<void>.delayed(Duration.zero);
      expect(repos.rounds, 2);

      // Round A finishes while B is still in flight.
      gateA.complete();
      await roundA;
      await Future<void>.delayed(Duration.zero);

      // A refresh now must ride round B, not start a third fan-out.
      final rideAlong = controller.load('tokenB', DateTime(2026, 1, 1, 10, 5));
      await Future<void>.delayed(Duration.zero);

      expect(
        repos.rounds,
        2,
        reason:
            "round A's completion must not free the slot round B is still holding",
      );

      gateB.complete();
      await roundB;
      await rideAlong;
      await Future<void>.delayed(Duration.zero);

      expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 10, 0));
    },
  );

  test('a later load runs normally once the in-flight one has finished', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);

    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    expect(repos.rounds, 2);
    expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 11, 45));
  });
}
