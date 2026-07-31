import '../domain/finance_budget.dart';
import '../domain/finance_category.dart';
import '../domain/finance_month.dart';
import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/monthly_summary.dart';

/// Everything a finance month view needs in one bundle.
class FinanceMonthData {
  final List<FinanceCategory> categories;
  final MonthlySummary summary;
  final List<FinanceTransaction> transactions;
  final List<FinanceBudget> budgets;

  const FinanceMonthData({
    required this.categories,
    required this.summary,
    required this.transactions,
    required this.budgets,
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
    return FinanceMonthData(
      categories: results[0] as List<FinanceCategory>,
      summary: results[1] as MonthlySummary,
      transactions: results[2] as List<FinanceTransaction>,
      budgets: results[3] as List<FinanceBudget>,
    );
  }
}
