import 'package:flutter/foundation.dart';

import '../../../shared/date/day_format.dart';
import '../../body_profile/application/get_weight_goal.dart';
import '../../body_profile/domain/weight_goal.dart';
import '../../finance/application/list_finance_budgets.dart';
import '../../finance/application/networth_use_cases.dart';
import '../../finance/domain/finance_budget.dart';
import '../../finance/domain/finance_month.dart';
import '../../finance/domain/networth_snapshot.dart';
import '../../health/application/get_daily_target_with_remaining.dart';
import '../../health/domain/daily_target.dart';
import '../../menstrual/application/get_menstrual_overview.dart';
import '../../menstrual/domain/menstrual_period.dart';
import '../../menstrual/domain/next_period_status.dart';
import '../../split/application/balance_use_cases.dart';
import '../../split/domain/balance.dart';
import '../../vitals/application/get_vitals_trends.dart';
import '../../vitals/domain/vitals_series.dart';

enum HomeDashboardStatus { idle, loading, loaded, error }

class BloodPressureSnapshot {
  final double systolic;
  final double diastolic;
  final DateTime day;
  final String time;

  const BloodPressureSnapshot({
    required this.systolic,
    required this.diastolic,
    required this.day,
    required this.time,
  });
}

class HomeDashboardData {
  final WeightGoal weightGoal;
  final BloodPressureSnapshot? bloodPressure;
  final NextPeriodStatus menstrualStatus;
  final FinanceBudget? overallBudget;
  final MonthlyNetWorth netWorth;
  final List<Balance> splitBalances;

  /// Today's effective portion target (and what is left of it), or `null`
  /// when **that one request** failed.
  ///
  /// Nullable, unlike every sibling above, and the asymmetry is the point.
  /// "The backend always answers with a default target" only rules out an
  /// *empty* answer; it says nothing about a 4xx/5xx/timeout, and under a
  /// plain `Future.wait` one such failure takes the whole dashboard to the
  /// error state — six healthy snapshots lost to the least important arm. So
  /// this arm alone swallows its own error and degrades to `null` here (the
  /// tile then prints 無資料, exactly like the placeholder branch); the other
  /// six stay all-or-nothing, because they *are* the screen and quietly
  /// blanking them would be worse than an error the user can retry.
  final DailyTargetWithRemaining? dailyTarget;

  const HomeDashboardData({
    required this.weightGoal,
    required this.bloodPressure,
    required this.menstrualStatus,
    required this.overallBudget,
    required this.netWorth,
    required this.splitBalances,
    required this.dailyTarget,
  });
}

/// Loads the lightweight cross-context snapshots shown by the home hub.
class HomeDashboardController extends ChangeNotifier {
  final GetWeightGoal _getWeightGoal;
  final GetVitalsTrends _getVitalsTrends;
  final GetMenstrualOverview _getMenstrualOverview;
  final ListFinanceBudgets _listFinanceBudgets;
  final GetMonthlyNetWorth _getMonthlyNetWorth;
  final GetBalances _getBalances;
  final GetDailyTargetWithRemaining _getDailyTarget;

  HomeDashboardController(
    this._getWeightGoal,
    this._getVitalsTrends,
    this._getMenstrualOverview,
    this._listFinanceBudgets,
    this._getMonthlyNetWorth,
    this._getBalances,
    this._getDailyTarget,
  );

  HomeDashboardStatus status = HomeDashboardStatus.idle;
  HomeDashboardData? data;

  /// When the fan-out last produced data, or `null` before the first success —
  /// what the home screen's "updated HH:mm" line reads. It advances only in
  /// [_load]'s success branch: a failed reload leaves the figures on screen
  /// untouched, so claiming they were just refreshed would be a lie.
  DateTime? lastLoadedAt;

  /// The round currently running, or `null` when nothing is in flight.
  Future<void>? _inFlight;

  /// Bumped by [reset]. A round captures the generation it started under and
  /// refuses to write `data`/`status`/`lastLoadedAt` if the generation has
  /// moved on by the time it finishes — otherwise an outgoing user's
  /// already-in-flight round can land its response on the controller after
  /// `reset()` supposedly cleared it for the next user.
  int _generation = 0;

  /// Loads the dashboard, or — if a round is already running — returns that
  /// round's future rather than starting a second fan-out. The retry button
  /// and a pull-to-refresh can otherwise overlap into fourteen concurrent
  /// requests whose two writes land in an unknown order.
  Future<void> load(String idToken, DateTime now) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    final generation = _generation;
    late final Future<void> round;
    round = _load(idToken, now, generation).whenComplete(() {
      // Only clear the slot if it's still *this* round's — an older round
      // finishing after `reset()` started a newer one must not clobber the
      // newer round's registration.
      if (identical(_inFlight, round)) _inFlight = null;
    });
    _inFlight = round;
    return round;
  }

  Future<void> _load(String idToken, DateTime now, int generation) async {
    status = HomeDashboardStatus.loading;
    notifyListeners();
    final month = monthStringOf(now);
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: 365));
    try {
      // `Object?`, not `Object`: the daily-target arm below resolves to
      // `null` when it fails.
      final results = await Future.wait<Object?>([
        _getWeightGoal(idToken),
        _getVitalsTrends(idToken, from, to),
        _getMenstrualOverview(idToken),
        _listFinanceBudgets(idToken, month),
        _getMonthlyNetWorth(idToken, month),
        _getBalances(idToken),
        // The one arm allowed to fail alone — see `HomeDashboardData
        // .dailyTarget` for why this one and not the others.
        _getDailyTarget(idToken, dayString(now))
            .then<DailyTargetWithRemaining?>((target) => target)
            .onError((_, __) => null),
      ]);
      if (generation != _generation) return;
      final vitals = results[1] as VitalsRange;
      final menstrual = results[2] as MenstrualOverview;
      final budgets = results[3] as List<FinanceBudget>;
      data = HomeDashboardData(
        weightGoal: results[0] as WeightGoal,
        bloodPressure: _latestBloodPressure(vitals.series),
        menstrualStatus: computeNextPeriodStatus(menstrual, now),
        overallBudget: budgets.where((budget) => budget.categoryId == null).firstOrNull,
        netWorth: results[4] as MonthlyNetWorth,
        splitBalances: results[5] as List<Balance>,
        dailyTarget: results[6] as DailyTargetWithRemaining?,
      );
      status = HomeDashboardStatus.loaded;
      lastLoadedAt = now;
    } catch (_) {
      if (generation != _generation) return;
      status = HomeDashboardStatus.error;
    }
    notifyListeners();
  }

  void reset() {
    data = null;
    status = HomeDashboardStatus.idle;
    // Per-user state, so it goes when the user does (sign-out calls this):
    // otherwise the next account's home opens claiming a load time that
    // belongs to the previous one.
    lastLoadedAt = null;
    // Also per-user: if a round for the outgoing user is still in flight when
    // they sign out, `load` for the incoming user must start a fresh fan-out
    // rather than riding the old round's future to completion — otherwise the
    // new user's screen quietly fills in with the old user's data and no
    // request is ever made with the new token.
    _inFlight = null;
    // Bumping the generation stops the outgoing round from writing its
    // result onto this controller once it finishes — see `_generation`.
    _generation++;
  }
}

BloodPressureSnapshot? _latestBloodPressure(VitalsSeries series) {
  final diastolicByReading = <String, SeriesPoint>{
    for (final point in series.diastolic) _readingKey(point): point,
  };
  for (final systolic in series.systolic.reversed) {
    final diastolic = diastolicByReading[_readingKey(systolic)];
    if (diastolic == null) continue;
    return BloodPressureSnapshot(
      systolic: systolic.value,
      diastolic: diastolic.value,
      day: systolic.day,
      time: systolic.time,
    );
  }
  return null;
}

String _readingKey(SeriesPoint point) =>
    '${point.day.year}-${point.day.month}-${point.day.day}|${point.time}';
