import '../domain/split_expense.dart';
import '../domain/split_input.dart';
import '../domain/split_repository.dart';

/// Use case: list expenses, optionally filtered by group or counterparty.
class ListExpenses {
  final SplitRepository _repository;

  ListExpenses(this._repository);

  Future<List<SplitExpense>> call(String idToken, {String? groupId, String? withUserId}) =>
      _repository.listExpenses(idToken, groupId: groupId, withUserId: withUserId);
}

class CreateExpense {
  final SplitRepository _repository;

  CreateExpense(this._repository);

  Future<SplitExpense> call(
    String idToken, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
    String? categoryName,
  }) => _repository.createExpense(
    idToken,
    groupId: groupId,
    payerUserId: payerUserId,
    amount: amount,
    currency: currency,
    description: description,
    day: day,
    split: split,
    categoryName: categoryName,
  );
}

/// Use case: fetch a single expense (visible only to a participant).
class GetExpense {
  final SplitRepository _repository;

  GetExpense(this._repository);

  Future<SplitExpense> call(String idToken, String expenseId) =>
      _repository.getExpense(idToken, expenseId);
}

/// Use case: replace an expense's fields (only the creator or payer may).
/// `PATCH` is a full replace server-side — callers must pass every field.
class UpdateExpense {
  final SplitRepository _repository;

  UpdateExpense(this._repository);

  Future<SplitExpense> call(
    String idToken,
    String expenseId, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
    String? categoryName,
  }) => _repository.updateExpense(
    idToken,
    expenseId,
    groupId: groupId,
    payerUserId: payerUserId,
    amount: amount,
    currency: currency,
    description: description,
    day: day,
    split: split,
    categoryName: categoryName,
  );
}

/// Use case: delete an expense (only the creator or payer may).
class DeleteExpense {
  final SplitRepository _repository;

  DeleteExpense(this._repository);

  Future<void> call(String idToken, String expenseId) => _repository.deleteExpense(idToken, expenseId);
}
