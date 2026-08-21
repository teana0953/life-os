import '../domain/finance_budget.dart';
import '../domain/finance_category.dart';
import '../domain/finance_exceptions.dart';
import '../domain/finance_month.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/installment_plan.dart';
import '../domain/monthly_summary.dart';

/// Everything a finance month view needs in one bundle.
class FinanceMonthData {
  final List<FinanceCategory> categories;
  final MonthlySummary summary;
  final List<FinanceTransaction> transactions;
  final List<FinanceBudget> budgets;

  /// The instalment plans behind every non-null `planId` in [transactions],
  /// keyed by plan id. A plan the caller does not own answers 404 ([FinanceNotFound])
  /// and is simply absent here — the only ownership signal the API gives a
  /// client, and what the sheet/list rows key their plan-level actions on
  /// (tasks 2.1/2.2).
  final Map<String, InstallmentPlan> installmentPlans;

  const FinanceMonthData({
    required this.categories,
    required this.summary,
    required this.transactions,
    required this.budgets,
    required this.installmentPlans,
  });
}

/// Kept private so the guard in `get_finance_month_test.dart` has to write the
/// bound out itself — a test importing this constant would move with it and a
/// raised cap would stay green.
const _maxConcurrentPlanFetches = 4;

/// Use case: fetch a month's categories, summary, transactions, and budgets
/// together (`from`/`to` span the whole month) — budgets ride the same
/// `Future.wait` batch as the rest so [FinanceController]'s existing
/// month-race guard covers them too (design.md).
class GetFinanceMonth {
  final FinanceRepository _repository;

  GetFinanceMonth(this._repository);

  Future<FinanceMonthData> call(String idToken, String month) async {
    final results = await Future.wait([
      _repository.getCategories(idToken),
      _repository.getSummary(idToken, month),
      _repository.getTransactions(
        idToken,
        from: monthStart(month),
        to: monthEnd(month),
      ),
      _repository.listBudgets(idToken, month),
    ]);
    final transactions = results[2] as List<FinanceTransaction>;
    final planIds = {
      for (final txn in transactions)
        if (txn.planId != null) txn.planId!,
    };
    // Concurrent, and every failure is absorbed — the same isolation
    // `FinanceController._loadSplitSpending` documents for its own figure.
    //
    // Sequentially would add a round trip per distinct plan to every month
    // load, on top of the batch above rather than inside it.
    //
    // And catching only `FinanceNotFound` would mean one flaky call to a
    // secondary endpoint blanks the whole month: the controller's `load` has a
    // catch-all, so transactions, budgets and the summary — all already
    // fetched successfully — would be thrown away and the user shown an error
    // screen over a ledger that was fine. A plan that cannot be read is a
    // period rendered without its "of M", not a month that failed to load.
    //
    // Concurrent but bounded: unbounded, a month is one simultaneous request
    // per distinct plan, and a heavy ledger opens dozens at once against a
    // backend whose real ceiling is per-request subrequests and compute, not
    // wall time. A small pool keeps the round trips overlapping — the whole
    // point above — while capping how wide the burst can get.
    final installmentPlans = <String, InstallmentPlan>{};
    final queue = planIds.iterator;
    await Future.wait([
      for (
        var worker = 0;
        worker < _maxConcurrentPlanFetches && worker < planIds.length;
        worker++
      )
        () async {
          // A worker pool rather than fixed-size batches: a batch runs at the
          // speed of its slowest plan, leaving the rest of the pool idle.
          while (true) {
            if (!queue.moveNext()) return;
            final planId = queue.current;
            try {
              installmentPlans[planId] = await _repository.getInstallmentPlan(
                idToken,
                planId,
              );
            } catch (_) {
              // A 404 is the ownership signal (tasks 2.1/2.2 — the API has no
              // other); anything else is a plan we could not read this time.
              // Neither is worth failing the month over.
            }
          }
        }(),
    ]);
    return FinanceMonthData(
      categories: results[0] as List<FinanceCategory>,
      summary: results[1] as MonthlySummary,
      transactions: transactions,
      budgets: results[3] as List<FinanceBudget>,
      installmentPlans: installmentPlans,
    );
  }
}
