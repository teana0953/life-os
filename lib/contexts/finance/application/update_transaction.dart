import '../domain/finance_repository.dart';
import '../domain/finance_transaction.dart';
import '../domain/finance_type.dart';

/// Use case: full-replace update of an existing transaction (`currency` is
/// required — the backend rejects an omitted currency to avoid silently
/// rewriting a foreign-currency transaction).
class UpdateTransaction {
  final FinanceRepository _repository;

  UpdateTransaction(this._repository);

  Future<FinanceTransaction> call(
    String idToken,
    String id, {
    required FinanceType type,
    required int amount,
    required String currency,
    required String categoryId,
    required String date,
    String? note,
  }) {
    return _repository.updateTransaction(
      idToken,
      id,
      type: type,
      amount: amount,
      currency: currency,
      categoryId: categoryId,
      date: date,
      note: note,
    );
  }
}
