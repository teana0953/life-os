import '../domain/finance_budget.dart';
import '../domain/finance_repository.dart';

/// Lists the selected month's recurring budgets without loading its ledger.
class ListFinanceBudgets {
  final FinanceRepository _repository;

  ListFinanceBudgets(this._repository);

  Future<List<FinanceBudget>> call(String idToken, String month) =>
      _repository.listBudgets(idToken, month);
}
