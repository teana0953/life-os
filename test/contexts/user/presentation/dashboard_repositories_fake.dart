import 'dart:async';

import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/health/domain/daily_target.dart';
import 'package:life_os/contexts/health/domain/daily_target_repository.dart';
import 'package:life_os/contexts/health/domain/portions.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/split_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';

/// The seven sources behind `HomeDashboardController.load`, faked so a test can
/// drive a *real* fan-out: hold it open ([gate]), make it fail ([fail], or one arm at a time with [failingArms]), count
/// the rounds it ran ([rounds]), and read back the token each round was
/// actually handed ([goalTokens] — asserting on the token the use case
/// RECEIVED, not on the provider having been called).
///
/// Deliberately unlike `loadedDashboardFixture()` in `home_screen_test.dart`,
/// which assigns the loaded state directly and throws if anything fetches:
/// that one cannot drive a refresh at all.
class FakeDashboardRepositories
    implements
        BodyProfileRepository,
        VitalsRepository,
        MenstrualRepository,
        FinanceRepository,
        SplitRepository,
        DailyTargetRepository {
  /// The id token each fan-out round handed to the weight-goal arm, in order.
  final List<String> goalTokens = <String>[];

  /// How many fan-out rounds started (one per `load`, counted on the arm that
  /// records the token).
  ///
  /// Caveat now that single arms can be refetched on their own: a
  /// `retryArm(DashboardArm.weightGoal, …)` runs this same arm and so bumps
  /// this too. Assert on [calls] when the question is which arm ran; `rounds`
  /// only means "a whole fan-out started" while no weight-goal retry is in
  /// play.
  int rounds = 0;

  /// Every arm throws while set — the "the whole refresh failed" case.
  bool fail = false;

  /// Only the *named* arms throw — the "one source is down, the rest are
  /// fine" case that [fail] cannot express. Names: `weightGoal`, `vitals`,
  /// `menstrual`, `budgets`, `networth`, `balances`, `target`.
  final Set<String> failingArms = <String>{};

  /// Every arm parks on this until it completes — the "reload still in
  /// flight" case.
  Completer<void>? gate;

  /// How many times each arm has been called, by the same names as
  /// [failingArms]. A per-tile retry's whole claim is "ONE request, on THAT
  /// arm", and that is only observable as a per-arm count — a total, or a
  /// spy on the controller, would pass a `retryArm` that quietly ran `load`.
  final Map<String, int> calls = <String, int>{};

  /// Parks the *n*th call of one arm until completed, keyed `'weightGoal#2'`
  /// (1-based). Unlike [gate], which holds every arm of every round at once,
  /// this lets a test hold one fetch of one arm open while a second fetch of
  /// the SAME arm completes — the interleaving the write rule is about.
  final Map<String, Completer<void>> callGates = <String, Completer<void>>{};

  /// The weight successive `getWeightGoal` calls resolve to, in call order;
  /// past the end of the list (and by default) every call answers 62.5.
  ///
  /// Distinct values on purpose: "the slot holds the result of the
  /// last-STARTED fetch" is unfalsifiable while two fetches of the same arm
  /// return the same number.
  final List<double> weightGoalSequence = <double>[];

  /// Returns this call's 1-based index for the arm, so a caller can pick its
  /// scripted answer from the same numbering [callGates] uses.
  Future<int> _arm(String name) async {
    final n = (calls[name] ?? 0) + 1;
    calls[name] = n;
    final gate = this.gate;
    if (gate != null) await gate.future;
    final callGate = callGates['$name#$n'];
    if (callGate != null) await callGate.future;
    if (fail || failingArms.contains(name)) {
      throw StateError('dashboard fetch failed: $name');
    }
    return n;
  }

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    goalTokens.add(idToken);
    rounds++;
    final n = await _arm('weightGoal');
    return WeightGoal(
      currentWeightKg: n <= weightGoalSequence.length
          ? weightGoalSequence[n - 1]
          : 62.5,
    );
  }

  @override
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async {
    await _arm('vitals');
    return VitalsRange(
      from: from,
      to: to,
      series: const VitalsSeries(
        weight: [],
        bodyFat: [],
        waist: [],
        systolic: [],
        diastolic: [],
        pulse: [],
        glucose: [],
        spo2: [],
      ),
    );
  }

  @override
  Future<MenstrualOverview> getOverview(String idToken) async {
    await _arm('menstrual');
    return const MenstrualOverview(periods: [], stats: MenstrualStats());
  }

  @override
  Future<List<FinanceBudget>> listBudgets(String idToken, String month) async {
    await _arm('budgets');
    return const [
      FinanceBudget(
        id: 'b1',
        categoryId: null,
        amount: 500000,
        spent: 377600,
        remaining: 123400,
        percent: 76,
      ),
    ];
  }

  @override
  Future<MonthlyNetWorth> getMonthlyNetWorth(String idToken, String month) async {
    await _arm('networth');
    return const MonthlyNetWorth(
      month: '2026-01',
      accounts: [],
      totalAsset: 987600,
      totalLiability: 456700,
      netWorth: 530900,
      prevNetWorth: null,
      growthRate: null,
    );
  }

  @override
  Future<List<Balance>> getBalances(String idToken) async {
    await _arm('balances');
    return const [
      Balance(
        userId: 'friend-1',
        displayName: 'Friend',
        balances: [CurrencyBalance(currency: 'TWD', amount: 55500)],
      ),
    ];
  }

  /// The `day` string each fan-out round handed the daily-target arm, in
  /// order — asserted on directly, because "the fan-out asks for TODAY" is
  /// only observable in the argument the use case RECEIVED.
  final List<String> targetDays = <String>[];

  @override
  Future<DailyTargetWithRemaining> getTarget(String idToken, String day) async {
    targetDays.add(day);
    await _arm('target');
    return DailyTargetWithRemaining(
      day: day,
      // base/bonus/logged/remaining are deliberately NOT all equal to
      // effective: a fixture where every Portions field carries the same
      // numbers can't tell `target.effective` from `target.base` or
      // `target.remaining` apart, which is exactly the distinction a past
      // regression got wrong (the tile must print effective, not
      // remaining).
      base: const Portions(staple: 8, meat: 6, fruit: 2, veg: 2),
      bonus: const Portions(staple: 2, meat: 1, fruit: 0, veg: 0),
      effective: const Portions(staple: 10, meat: 7, fruit: 2, veg: 2),
      logged: const Portions(staple: 3, meat: 2, fruit: 1, veg: 0),
      remaining: const Portions(staple: 7, meat: 5, fruit: 1, veg: 2),
    );
  }

  /// Anything the dashboard fan-out does not call is a mistake, not an empty.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected repository call: ${invocation.memberName}');
}
