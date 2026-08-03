import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/application/get_split_spending.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/split_spending.dart';

import '../finance_test_support.dart';

void main() {
  test('GetSplitSpending delegates to the repository', () async {
    final repository = FakeFinanceRepository()
      ..splitSpendingByMonth['2026-08'] = const [SplitSpending(currency: 'TWD', amount: 500)];

    final totals = await GetSplitSpending(repository)('token-1', '2026-08');

    expect(totals, [const SplitSpending(currency: 'TWD', amount: 500)]);
  });

  test('an empty month returns an empty list rather than a zero row', () async {
    final repository = FakeFinanceRepository();

    final totals = await GetSplitSpending(repository)('token-1', '2026-08');

    expect(totals, isEmpty);
  });

  test('lets the repository error propagate', () async {
    // `splitSpendingFailNext`, not the shared `failNext`: `getSplitSpending`
    // now runs concurrently with the main finance fetch inside
    // `FinanceController.load` (design D9, task 6), so the fake keeps a
    // dedicated flag for it — sharing one would let whichever call runs
    // first consume it.
    final repository = FakeFinanceRepository()
      ..splitSpendingFailNext = const FinanceFetchFailure('boom');

    expect(
      () => GetSplitSpending(repository)('token-1', '2026-08'),
      throwsA(isA<FinanceFetchFailure>()),
    );
  });
}
