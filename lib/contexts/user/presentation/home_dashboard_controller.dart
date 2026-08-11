import 'package:flutter/foundation.dart';

import '../../body_profile/application/get_weight_goal.dart';
import '../../body_profile/domain/weight_goal.dart';
import '../../finance/application/list_finance_budgets.dart';
import '../../finance/application/networth_use_cases.dart';
import '../../finance/domain/finance_budget.dart';
import '../../finance/domain/finance_month.dart';
import '../../finance/domain/networth_snapshot.dart';
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

  const HomeDashboardData({
    required this.weightGoal,
    required this.bloodPressure,
    required this.menstrualStatus,
    required this.overallBudget,
    required this.netWorth,
    required this.splitBalances,
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

  HomeDashboardController(
    this._getWeightGoal,
    this._getVitalsTrends,
    this._getMenstrualOverview,
    this._listFinanceBudgets,
    this._getMonthlyNetWorth,
    this._getBalances,
  );

  HomeDashboardStatus status = HomeDashboardStatus.idle;
  HomeDashboardData? data;

  Future<void> load(String idToken, DateTime now) async {
    status = HomeDashboardStatus.loading;
    notifyListeners();
    final month = monthStringOf(now);
    final to = DateTime(now.year, now.month, now.day);
    final from = to.subtract(const Duration(days: 365));
    try {
      final results = await Future.wait<Object>([
        _getWeightGoal(idToken),
        _getVitalsTrends(idToken, from, to),
        _getMenstrualOverview(idToken),
        _listFinanceBudgets(idToken, month),
        _getMonthlyNetWorth(idToken, month),
        _getBalances(idToken),
      ]);
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
      );
      status = HomeDashboardStatus.loaded;
    } catch (_) {
      status = HomeDashboardStatus.error;
    }
    notifyListeners();
  }

  void reset() {
    data = null;
    status = HomeDashboardStatus.idle;
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
