import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:life_os/contexts/finance/domain/finance_budget.dart';
import 'package:life_os/contexts/finance/infrastructure/http_finance_repository.dart';
import 'package:life_os/contexts/health/infrastructure/http_daily_target_repository.dart';
import 'package:life_os/contexts/split/infrastructure/http_split_repository.dart';
import 'package:life_os/shared/screen_batch/home_summary_batch.dart';
import 'package:life_os/shared/screen_batch/section_outcome.dart';

import 'batch_fixtures.dart';

/// Same contract as `health_overview_batch_test.dart`: one fixture, both
/// paths, compared — plus the two arms the home dashboard *reduces* rather
/// than displays whole.
void main() {
  const day = '2026-08-20';
  const month = '2026-08';
  final batch = HomeSummaryBatch.fromJson(homeSummaryBody());

  T okValue<T>(SectionOutcome<T> outcome) => (outcome as SectionOk<T>).value;

  http.Client serving(Object payload) =>
      MockClient((_) async => http.Response(jsonEncode(payload), 200));

  test('budgets reduces to the null-category (overall) budget', () async {
    final granular = await HttpFinanceRepository(
      baseUrl: 'https://api.test',
      client: serving(budgetsPayload(month)),
    ).listBudgets('t', month);
    final expected = granular.where((b) => b.categoryId == null).single;
    final section = okValue(batch.overallBudget);

    expect(section!.id, expected.id);
    expect(section.categoryId, isNull);
    expect(section.amount, expected.amount);
    expect(section.percent, expected.percent);
  });

  test('a budgets list with no overall budget reduces to null, not a failure', () {
    final body = homeSummaryBody()
      ..['budgets'] = okSection({
        'month': month,
        'budgets': [
          {
            'id': 'b-cat',
            'category_id': 'cat-1',
            'amount': 5000,
            'spent': 1000,
            'remaining': 4000,
            'percent': 20,
          },
        ],
      });

    final outcome = HomeSummaryBatch.fromJson(body).overallBudget;

    expect(outcome, isA<SectionOk<FinanceBudget?>>());
    expect((outcome as SectionOk<FinanceBudget?>).value, isNull);
  });

  test('net_worth matches the granular monthly net-worth decode', () async {
    final granular = await HttpFinanceRepository(
      baseUrl: 'https://api.test',
      client: serving(netWorthPayload(month)),
    ).getMonthlyNetWorth('t', month);
    final section = okValue(batch.netWorth);

    expect(section.month, granular.month);
    expect(section.totalAsset, granular.totalAsset);
    expect(section.totalLiability, granular.totalLiability);
    expect(section.netWorth, granular.netWorth);
    expect(section.prevNetWorth, granular.prevNetWorth);
    expect(section.growthRate, granular.growthRate);
  });

  test('split_balances matches the granular /api/split/balances decode', () async {
    final granular = await HttpSplitRepository(
      baseUrl: 'https://api.test',
      client: serving(splitBalancesPayload),
    ).getBalances('t');
    final section = okValue(batch.splitBalances);

    expect(
      section.map((b) => b.userId).toList(),
      granular.map((b) => b.userId).toList(),
    );
    expect(section.single.displayName, granular.single.displayName);
    expect(
      section.single.balances.single.amount,
      granular.single.balances.single.amount,
    );
  });

  test('daily_target matches the granular /api/daily-target decode', () async {
    final granular = await HttpDailyTargetRepository(
      baseUrl: 'https://api.test',
      client: serving(dailyTargetPayload(day)),
    ).getTarget('t', day);
    final section = okValue(batch.dailyTarget);

    expect(section.day, granular.day);
    expect(section.effective.staple, granular.effective.staple);
    expect(section.remaining.veg, granular.remaining.veg);
  });

  test('vitals_trend carries the whole series the BP arm reduces', () {
    final section = okValue(batch.vitalsTrend);

    expect(section.series.systolic.length, 2);
    expect(section.series.systolic.last.value, 124);
    expect(section.series.diastolic.last.value, 81);
  });

  test('weight_goal and menstrual decode into their domain types', () {
    expect(okValue(batch.weightGoal).currentWeightKg, 68.4);
    expect(okValue(batch.menstrual).stats.averageCycleDays, 29);
  });
}
