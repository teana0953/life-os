import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';

/// Use case: record a new transaction.
class AddTransaction {
  final FinanceRepository _repository;

  AddTransaction(this._repository);

  Future<FinanceTransaction> call(
    String idToken, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) {
    return _repository.addTransaction(
      idToken,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
  }
}
