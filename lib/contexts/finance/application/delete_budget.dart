import '../domain/finance_repository.dart';

/// Use case: delete a budget.
class DeleteBudget {
  final FinanceRepository _repository;

  DeleteBudget(this._repository);

  Future<void> call(String idToken, String id) => _repository.deleteBudget(idToken, id);
}
