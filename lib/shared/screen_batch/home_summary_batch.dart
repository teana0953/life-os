import '../../contexts/body_profile/domain/weight_goal.dart';
import '../../contexts/finance/domain/finance_budget.dart';
import '../../contexts/finance/domain/networth_snapshot.dart';
import '../../contexts/finance/infrastructure/http_finance_repository.dart';
import '../../contexts/health/domain/daily_target.dart';
import '../../contexts/menstrual/domain/menstrual_period.dart';
import '../../contexts/split/domain/balance.dart';
import '../../contexts/split/infrastructure/http_split_repository.dart';
import '../../contexts/vitals/domain/vitals_series.dart';
import 'section_outcome.dart';

/// The seven sections of `GET /api/home-summary`, decoded into the values the
/// home dashboard's arms hold.
///
/// Two of the seven are *reductions* of their section rather than the section
/// itself, matching what the granular arm computed before this existed:
///
///  * [overallBudget] is the one budget in the `budgets` list whose category
///    is null (the month's overall budget), so the tile shows what it always
///    showed;
///  * [vitalsTrend] stays the whole range — the blood-pressure arm reduces it
///    to the most recent systolic/diastolic pair in
///    `HomeDashboardController`, where `BloodPressureSnapshot` lives.
class HomeSummaryBatch {
  final SectionOutcome<WeightGoal> weightGoal;
  final SectionOutcome<VitalsRange> vitalsTrend;
  final SectionOutcome<MenstrualOverview> menstrual;
  final SectionOutcome<FinanceBudget?> overallBudget;
  final SectionOutcome<MonthlyNetWorth> netWorth;
  final SectionOutcome<List<Balance>> splitBalances;
  final SectionOutcome<DailyTargetWithRemaining> dailyTarget;

  const HomeSummaryBatch({
    required this.weightGoal,
    required this.vitalsTrend,
    required this.menstrual,
    required this.overallBudget,
    required this.netWorth,
    required this.splitBalances,
    required this.dailyTarget,
  });

  factory HomeSummaryBatch.fromJson(Map<String, dynamic> json) =>
      HomeSummaryBatch(
        weightGoal: decodeSection(
          json['weight_goal'],
          (data) => WeightGoal.fromJson(data as Map<String, dynamic>),
        ),
        vitalsTrend: decodeSection(
          json['vitals_trend'],
          (data) => VitalsRange.fromJson(data as Map<String, dynamic>),
        ),
        menstrual: decodeSection(
          json['menstrual'],
          (data) => MenstrualOverview.fromJson(data as Map<String, dynamic>),
        ),
        overallBudget: decodeSection(
          json['budgets'],
          (data) => financeBudgetsFromJson(data as Map<String, dynamic>)
              .where((budget) => budget.categoryId == null)
              .firstOrNull,
        ),
        netWorth: decodeSection(
          json['net_worth'],
          (data) => MonthlyNetWorth.fromJson(data as Map<String, dynamic>),
        ),
        splitBalances: decodeSection(
          json['split_balances'],
          (data) => balancesFromJson(data as Map<String, dynamic>),
        ),
        dailyTarget: decodeSection(
          json['daily_target'],
          (data) =>
              DailyTargetWithRemaining.fromJson(data as Map<String, dynamic>),
        ),
      );

  /// Every section carrying the outcome a *request-level* failure produces
  /// (design D5) — see `HealthOverviewBatch.requestFailed`.
  factory HomeSummaryBatch.requestFailed({required bool reauth}) =>
      HomeSummaryBatch(
        weightGoal: requestFailureOutcome(reauth: reauth),
        vitalsTrend: requestFailureOutcome(reauth: reauth),
        menstrual: requestFailureOutcome(reauth: reauth),
        overallBudget: requestFailureOutcome(reauth: reauth),
        netWorth: requestFailureOutcome(reauth: reauth),
        splitBalances: requestFailureOutcome(reauth: reauth),
        dailyTarget: requestFailureOutcome(reauth: reauth),
      );
}
