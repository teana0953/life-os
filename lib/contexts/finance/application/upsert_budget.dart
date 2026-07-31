import '../domain/finance_repository.dart';

/// Use case: upsert the overall budget ([categoryId] `null`) or a category
/// budget.
class UpsertBudget {
  final FinanceRepository _repository;

  UpsertBudget(this._repository);

  Future<void> call(String idToken, {String? categoryId, required int amount}) {
    return _repository.upsertBudget(idToken, categoryId: categoryId, amount: amount);
  }
}
