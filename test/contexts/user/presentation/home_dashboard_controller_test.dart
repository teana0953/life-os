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
      expect(controller.data!.dailyTarget.value!.effective.staple, 10);
      expect(controller.data!.dailyTarget.value!.effective.veg, 2);
    },
  );

  // ---- ANY one arm may fail on its own, and the tile says so.
  //
  // These two are a pair and have to stay one: the first says one failing arm
  // does not take the dashboard down, the second says a failing *dashboard*
  // still does. They are deliberately on opposite sides of the same seam.
  //
  // The daily-target arm is the fixture here because it is where the bug was:
  // it used to swallow its own error into `dailyTarget: null`, which the tile
  // painted as 無資料 — the identical string an empty record prints. Asserting
  // the failed STATUS, not a null value, is what makes those two
  // distinguishable, and is the assertion that must not be softened back.
  test(
    'one arm failing marks that arm failed and leaves the other six loaded',
    () async {
      final repos = FakeDashboardRepositories();
      repos.failingArms.add('target');
      final controller = controllerFor(repos);

      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

      expect(controller.status, HomeDashboardStatus.loaded);
      expect(controller.data!.dailyTarget.status, ArmStatus.failed);
      // Cold failure: nothing was ever fetched for this arm, so there is no
      // figure to keep — and `hasValue` false is how the tile knows to
      // replace the value rather than annotate it.
      expect(controller.data!.dailyTarget.hasValue, isFalse);
      // The six that must have survived — named individually, and by STATUS
      // as well as by value, so an arm that quietly degraded to a failed slot
      // holding a stale figure cannot hide behind a value assertion.
      expect(controller.data!.weightGoal.status, ArmStatus.loaded);
      expect(controller.data!.weightGoal.value!.currentWeightKg, 62.5);
      expect(controller.data!.bloodPressure.status, ArmStatus.loaded);
      expect(controller.data!.bloodPressure.value, isNull);
      expect(controller.data!.menstrualStatus.status, ArmStatus.loaded);
      expect(controller.data!.overallBudget.status, ArmStatus.loaded);
      expect(controller.data!.netWorth.status, ArmStatus.loaded);
      expect(controller.data!.netWorth.value!.netWorth, 530900);
      expect(controller.data!.splitBalances.status, ArmStatus.loaded);
      expect(controller.data!.splitBalances.value, hasLength(1));
    },
  );

  test(
    'a partially successful round still advances lastLoadedAt — six of the '
    'figures really were refreshed, and the seventh tile says it was not',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

      repos.failingArms.add('networth');
      await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

      expect(controller.status, HomeDashboardStatus.loaded);
      expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 11, 45));
      expect(controller.data!.netWorth.status, ArmStatus.failed);
    },
  );

  test(
    'an arm that failed after a successful fetch keeps the figure it already '
    'had, so the tile can mark it stale instead of blanking it',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

      repos.failingArms.add('networth');
      await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

      final slot = controller.data!.netWorth;
      expect(slot.status, ArmStatus.failed);
      expect(slot.hasValue, isTrue);
      expect(slot.value!.netWorth, 530900);
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

  test('a failed load keeps the figures already on hand', () async {
    final repos = FakeDashboardRepositories();
    final controller = controllerFor(repos);
    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

    repos.fail = true;
    await controller.load('tok', DateTime(2026, 1, 1, 11, 45));

    // Not `same(loaded)` any more, and the difference is the feature: the
    // slots are rebuilt so that every tile now says it wasn't refreshed. What
    // must survive is the FIGURES, which is what "keeps the data on hand"
    // always meant — the object identity was only ever how it was measured.
    expect(controller.data, isNotNull);
    expect(controller.data!.netWorth.value!.netWorth, 530900);
    expect(controller.data!.weightGoal.value!.currentWeightKg, 62.5);
    expect(controller.data!.hasAnyFailure, isTrue);
    expect(controller.status, HomeDashboardStatus.error);
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

  // ------------------------------------------------------------- retryArm
  //
  // Invariant P: a single-tile retry writes that arm's slot and NOTHING else.
  test(
    'retrying one tile issues exactly one request, on that arm, and leaves '
    'the page-level state alone',
    () async {
      final repos = FakeDashboardRepositories();
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
      final before = Map<String, int>.from(repos.calls);

      await controller.retryArm(
        DashboardArm.netWorth,
        'tok',
        DateTime(2026, 1, 1, 11, 45),
      );

      expect(repos.calls['networth'], before['networth']! + 1);
      // Named one by one rather than as a total: a `retryArm` that quietly
      // ran the whole `load` would still add "one request" to a total that
      // was never broken down.
      for (final arm in const [
        'weightGoal',
        'vitals',
        'menstrual',
        'budgets',
        'balances',
        'target',
      ]) {
        expect(repos.calls[arm], before[arm], reason: arm);
      }
      // Invariant P — the tile reloaded, the page did not.
      expect(controller.status, HomeDashboardStatus.loaded);
      expect(controller.lastLoadedAt, DateTime(2026, 1, 1, 9, 30));
    },
  );

  test('retrying a failed arm clears that tile alone', () async {
    final repos = FakeDashboardRepositories();
    repos.failingArms.add('networth');
    final controller = controllerFor(repos);
    await controller.load('tok', DateTime(2026, 1, 1, 9, 30));
    expect(controller.data!.netWorth.status, ArmStatus.failed);

    repos.failingArms.remove('networth');
    await controller.retryArm(
      DashboardArm.netWorth,
      'tok',
      DateTime(2026, 1, 1, 11, 45),
    );

    expect(controller.data!.netWorth.status, ArmStatus.loaded);
    expect(controller.data!.netWorth.value!.netWorth, 530900);
    expect(controller.data!.weightGoal.status, ArmStatus.loaded);
  });

  // ------------------------------------------------- Invariant W (the write rule)
  //
  // Every fetch of an arm takes a ticket at START; only the fetch still
  // holding the arm's latest ticket may write. The property under test is
  // therefore NOT a list of orderings — it is one predicate, asserted in
  // every interleaving below:
  //
  //   the arm's slot holds the value produced by the LAST-STARTED fetch of
  //   that arm, whatever order they complete in, whoever started them,
  //
  // and, separately, that the round's OTHER six arms still land — which is
  // exactly what a whole-controller guard cannot express.
  //
  // The scripted weights are monotonic (1, 2, 3) so that two fetches of the
  // same arm are distinguishable at all; with the fake's constant 62.5 every
  // assertion below would be green whichever write won.
  group('Invariant W: an arm reflects its last-started fetch', () {
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    /// A full round is in flight with its weight-goal arm still open when a
    /// single-tile retry of the same arm starts.
    Future<void> roundThenRetry({required bool retryCompletesFirst}) async {
      final repos = FakeDashboardRepositories()
        ..weightGoalSequence.addAll([1, 2]);
      final first = Completer<void>();
      final second = Completer<void>();
      repos.callGates['weightGoal#1'] = first;
      repos.callGates['weightGoal#2'] = second;
      final controller = controllerFor(repos);

      final round = controller.load('tok', DateTime(2026, 1, 1, 9, 30));
      // The six ungated arms land, so `data` exists and a tile retry is
      // something the screen could actually offer.
      await settle();
      final retry = controller.retryArm(
        DashboardArm.weightGoal,
        'tok',
        DateTime(2026, 1, 1, 9, 31),
      );
      await settle();

      if (retryCompletesFirst) {
        second.complete();
        await settle();
        first.complete();
      } else {
        first.complete();
        await settle();
        second.complete();
      }
      await round;
      await retry;
      await settle();

      expect(
        controller.data!.weightGoal.value!.currentWeightKg,
        2,
        reason: 'the retry started last, so its answer is the arm\'s answer',
      );
      expect(
        controller.data!.netWorth.value!.netWorth,
        530900,
        reason: "the round's other arms land even when its weight arm's "
            'write is dropped',
      );
    }

    test('round then retry, round completes first', () async {
      await roundThenRetry(retryCompletesFirst: false);
    });

    test('round then retry, retry completes first', () async {
      await roundThenRetry(retryCompletesFirst: true);
    });

    /// A single-tile retry is in flight when a whole round starts.
    Future<void> retryThenRound({required bool roundCompletesFirst}) async {
      final repos = FakeDashboardRepositories()
        ..weightGoalSequence.addAll([1, 2, 3]);
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

      final retryGate = Completer<void>();
      final roundGate = Completer<void>();
      repos.callGates['weightGoal#2'] = retryGate;
      repos.callGates['weightGoal#3'] = roundGate;

      final retry = controller.retryArm(
        DashboardArm.weightGoal,
        'tok',
        DateTime(2026, 1, 1, 11, 45),
      );
      await settle();
      final round = controller.load('tok', DateTime(2026, 1, 1, 11, 46));
      await settle();

      if (roundCompletesFirst) {
        roundGate.complete();
        await settle();
        retryGate.complete();
      } else {
        retryGate.complete();
        await settle();
        roundGate.complete();
      }
      await retry;
      await round;
      await settle();

      expect(
        controller.data!.weightGoal.value!.currentWeightKg,
        3,
        reason: "the round started last, so the retry's older answer is "
            'dropped even when it lands afterwards',
      );
    }

    test('retry then round, retry completes first', () async {
      await retryThenRound(roundCompletesFirst: false);
    });

    test('retry then round, round completes first', () async {
      await retryThenRound(roundCompletesFirst: true);
    });

    /// Two presses on the same tile — no dedupe exists, and none is needed.
    Future<void> retryTwice({required bool firstCompletesFirst}) async {
      final repos = FakeDashboardRepositories()
        ..weightGoalSequence.addAll([1, 2, 3]);
      final controller = controllerFor(repos);
      await controller.load('tok', DateTime(2026, 1, 1, 9, 30));

      final firstPress = Completer<void>();
      final secondPress = Completer<void>();
      repos.callGates['weightGoal#2'] = firstPress;
      repos.callGates['weightGoal#3'] = secondPress;

      final one = controller.retryArm(
        DashboardArm.weightGoal,
        'tok',
        DateTime(2026, 1, 1, 11, 45),
      );
      await settle();
      final two = controller.retryArm(
        DashboardArm.weightGoal,
        'tok',
        DateTime(2026, 1, 1, 11, 46),
      );
      await settle();

      if (firstCompletesFirst) {
        firstPress.complete();
        await settle();
        secondPress.complete();
      } else {
        secondPress.complete();
        await settle();
        firstPress.complete();
      }
      await one;
      await two;
      await settle();

      expect(
        controller.data!.weightGoal.value!.currentWeightKg,
        3,
        reason: 'the second press started last',
      );
      expect(
        repos.calls['weightGoal'],
        3,
        reason: 'both presses really did fire — there is no dedupe to hide '
            'behind, so the ordering above was actually exercised',
      );
    }

    test('two presses on one tile, first completes first', () async {
      await retryTwice(firstCompletesFirst: true);
    });

    test('two presses on one tile, second completes first', () async {
      await retryTwice(firstCompletesFirst: false);
    });
  });
}
