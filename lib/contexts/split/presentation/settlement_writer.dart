/// Surface `SettleUpSheet` needs for recording a repayment. Mirrors
/// `SplitExpenseWriter`'s shape so `SplitController` (the split tab) and
/// `GroupDetailController` (a group's two-person section, design D8) can
/// both implement it and be handed to the same sheet.
///
/// [mutationError]/[mutationErrorSeq]: after awaiting [createSettlement], a
/// caller compares the sequence number it captured beforehand against the
/// current one to tell "this call failed" from "an unrelated later failure
/// is still showing" — the failed-submission case (design.md) that must
/// leave every typed field exactly as it was.
abstract class SettlementWriter {
  Object? get mutationError;
  int get mutationErrorSeq;

  /// [groupId] is always `null` from this sheet — settling only ever starts
  /// from a two-person balance (design D0), which is the only place a
  /// from/to pair is well-defined.
  Future<void> createSettlement(
    String idToken, {
    String? groupId,
    required String fromUserId,
    required String toUserId,
    required int amount,
    required String currency,
    required String day,
    String? note,
  });
}
