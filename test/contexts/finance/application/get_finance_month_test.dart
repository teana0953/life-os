import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/application/get_finance_month.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/finance_transaction.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';
import 'package:life_os/contexts/finance/domain/installment_plan.dart';

import '../finance_test_support.dart';

const _plan = InstallmentPlan(
  id: 'plan-9',
  mode: InstallmentMode.total,
  periods: 12,
  startDay: '2026-05-15',
  amount: 60000,
  currency: 'TWD',
  categoryId: 'cat-food',
);

FinanceTransaction _period(String id, String? planId) => FinanceTransaction(
  id: id,
  type: FinanceType.expense,
  amount: 5000,
  currency: 'TWD',
  categoryId: 'cat-food',
  date: '2026-07-15',
  planId: planId,
  installmentNo: planId == null ? null : 3,
);

void main() {
  test('fetches the plan behind an instalment period', () async {
    final repo = FakeFinanceRepository()
      ..byMonth['2026-07'] = [_period('t1', 'plan-9')]
      ..plansById['plan-9'] = _plan;

    final data = await GetFinanceMonth(repo)('tok', '2026-07');

    expect(data.installmentPlans['plan-9'], _plan);
  });

  test("a plan the caller does not own is simply absent", () async {
    // 404 is the API's only ownership signal, so it cannot be a failure.
    final repo = FinanceRepositoryFailingPlans(const FinanceNotFound())
      ..byMonth['2026-07'] = [_period('t1', 'plan-other')];

    final data = await GetFinanceMonth(repo)('tok', '2026-07');

    expect(data.installmentPlans, isEmpty);
    expect(data.transactions, hasLength(1));
  });

  test('a plan that fails for any other reason does not fail the month', () async {
    // The whole point. Everything else in the month has already been fetched
    // successfully by the time the plans are read, and `FinanceController.load`
    // has a catch-all — so letting a 5xx or a network blip out of here throws
    // away working transactions, budgets and summary and shows an error screen
    // over a ledger that was fine. Same isolation `_loadSplitSpending`
    // documents for its own figure.
    final repo = FinanceRepositoryFailingPlans(const FinanceFetchFailure('boom'))
      ..byMonth['2026-07'] = [_period('t1', 'plan-9')];

    final data = await GetFinanceMonth(repo)('tok', '2026-07');

    expect(data.installmentPlans, isEmpty);
    expect(data.transactions, hasLength(1), reason: '月份的其餘資料必須留下來');
  });

  test('plans are fetched concurrently, not one round trip each', () async {
    // Sequentially, load time grows with the number of distinct plans. The
    // fake records the maximum overlap; with three plans a serial loop peaks
    // at 1.
    final repo = FinanceRepositoryCountingPlans()
      ..byMonth['2026-07'] = [
        _period('t1', 'plan-1'),
        _period('t2', 'plan-2'),
        _period('t3', 'plan-3'),
      ];

    await GetFinanceMonth(repo)('tok', '2026-07');

    expect(repo.calls, 3);
    expect(repo.maxInFlight, greaterThan(1));
  });
}
