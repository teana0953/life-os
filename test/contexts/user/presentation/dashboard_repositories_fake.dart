import 'dart:async';

import 'package:life_os/contexts/body_profile/domain/body_profile_repository.dart';
import 'package:life_os/contexts/body_profile/domain/weight_goal.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/domain/finance_repository.dart';
import 'package:life_os/contexts/finance/domain/networth_snapshot.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_repository.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/split_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_repository.dart';
import 'package:life_os/contexts/vitals/domain/vitals_series.dart';

/// The six sources behind `HomeDashboardController.load`, faked so a test can
/// drive a *real* fan-out: hold it open ([gate]), make it fail ([fail]), count
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
        SplitRepository {
  /// The id token each fan-out round handed to the weight-goal arm, in order.
  final List<String> goalTokens = <String>[];

  /// How many fan-out rounds started (one per `load`, counted on the arm that
  /// records the token).
  int rounds = 0;

  /// Every arm throws while set — the "the whole refresh failed" case.
  bool fail = false;

  /// Every arm parks on this until it completes — the "reload still in
  /// flight" case.
  Completer<void>? gate;

  Future<void> _arm() async {
    final gate = this.gate;
    if (gate != null) await gate.future;
    if (fail) throw StateError('dashboard fetch failed');
  }

  @override
  Future<WeightGoal> getWeightGoal(String idToken) async {
    goalTokens.add(idToken);
    rounds++;
    await _arm();
    return const WeightGoal(currentWeightKg: 62.5);
  }

  @override
  Future<VitalsRange> getRange(String idToken, DateTime from, DateTime to) async {
    await _arm();
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
    await _arm();
    return const MenstrualOverview(periods: [], stats: MenstrualStats());
  }

  @override
  Future<List<FinanceBudget>> listBudgets(String idToken, String month) async {
    await _arm();
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
    await _arm();
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
    await _arm();
    return const [
      Balance(
        userId: 'friend-1',
        displayName: 'Friend',
        balances: [CurrencyBalance(currency: 'TWD', amount: 55500)],
      ),
    ];
  }

  /// Anything the dashboard fan-out does not call is a mistake, not an empty.
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('unexpected repository call: ${invocation.memberName}');
}
