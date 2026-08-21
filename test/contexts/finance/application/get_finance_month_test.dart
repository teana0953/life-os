import 'dart:async';
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
    // at 1. This is NOT the cap guard — its fake completes on its own and it
    // asserts only `> 1`, so it cannot tell 4 in flight from 9. The bound is
    // pinned by 'never more than four plan fetches in flight at once' below.
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

  test('never more than four plan fetches in flight at once', () async {
    // A month with more distinct plans than twice the cap: 9 plans, two
    // periods each, so the fixture also pins that the fan-out is over
    // *distinct* plan ids (18 transactions must still be 9 calls) and forces
    // the "release one, another starts" refill behaviour that a single batch
    // of exactly `cap` would never exercise.
    //
    // The bound is written out as a literal 4 on purpose: importing the
    // implementation's constant would move this guard whenever the constant
    // moves, and a raised cap would silently stay green.
    final repo = FinanceRepositoryGatedPlans()
      ..byMonth['2026-07'] = [
        for (var i = 1; i <= 9; i++) ...[
          _period('t$i-a', 'plan-$i'),
          _period('t$i-b', 'plan-$i'),
        ],
      ];

    var done = false;
    final future = GetFinanceMonth(repo)('tok', '2026-07');
    unawaited(future.then((_) => done = true));

    await pumpEventQueue();
    // Before anything has been allowed to complete: proves the observation
    // window is open while the fan-out is at its peak, so a green
    // `maxInFlight` cannot come from measuring an already-drained batch.
    expect(repo.pending, hasLength(4));
    expect(repo.maxInFlight, 4);

    // Equality, not `lessThanOrEqualTo`: this single assertion has to fail
    // both when the cap is removed (peaks at 9) and when it collapses to a
    // serial loop (peaks at 1).
    for (var i = 0; i < 100 && !done; i++) {
      repo.releaseOne();
      await pumpEventQueue();
      expect(repo.maxInFlight, 4);
    }
    // Bounded loop rather than an unbounded wait: a pool that drops its tail
    // must turn red here, not hang (a hung test is not a failing test).
    expect(done, isTrue, reason: 'the month never finished loading');

    final data = await future;
    expect(repo.maxInFlight, 4);
    // Fetching fewer plans is the cheap way to fake a low peak; these pin that
    // every plan was still fetched exactly once and ended up in the bundle.
    expect(repo.calls, 9);
    expect(data.installmentPlans, hasLength(9));
  });
}
