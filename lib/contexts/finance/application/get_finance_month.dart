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
    final installmentPlans = <String, InstallmentPlan>{};
    for (final planId in planIds) {
      try {
        installmentPlans[planId] = await _repository.getInstallmentPlan(
          idToken,
          planId,
        );
      } on FinanceNotFound {
        // Not the caller's own plan — no ownership signal beyond "absent
        // here" (tasks 2.1/2.2).
      }
    }
    return FinanceMonthData(
      categories: results[0] as List<FinanceCategory>,
      summary: results[1] as MonthlySummary,
      transactions: transactions,
      budgets: results[3] as List<FinanceBudget>,
      installmentPlans: installmentPlans,
    );
  }
}
