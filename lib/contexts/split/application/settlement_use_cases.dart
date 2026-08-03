import '../domain/settlement.dart';
import '../domain/split_repository.dart';

/// Use case: record a repayment.
class CreateSettlement {
  final SplitRepository _repository;

  CreateSettlement(this._repository);

  Future<Settlement> call(
    String idToken, {
    String? groupId,
    required String fromUserId,
    required String toUserId,
    required int amount,
    required String currency,
    required String day,
    String? note,
  }) => _repository.createSettlement(
    idToken,
    groupId: groupId,
    fromUserId: fromUserId,
    toUserId: toUserId,
    amount: amount,
    currency: currency,
    day: day,
    note: note,
  );
}

/// Use case: list settlements, optionally filtered by group or counterparty.
class ListSettlements {
  final SplitRepository _repository;

  ListSettlements(this._repository);

  Future<List<Settlement>> call(String idToken, {String? groupId, String? withUserId}) =>
      _repository.listSettlements(idToken, groupId: groupId, withUserId: withUserId);
}

/// Use case: delete a settlement (only the creator or payer may).
class DeleteSettlement {
  final SplitRepository _repository;

  DeleteSettlement(this._repository);

  Future<void> call(String idToken, String settlementId) =>
      _repository.deleteSettlement(idToken, settlementId);
}
