import '../domain/finance_repository.dart';

class DeleteTransaction {
  final FinanceRepository _repository;

  DeleteTransaction(this._repository);

  Future<void> call(String idToken, String id) {
    return _repository.deleteTransaction(idToken, id);
  }
}
