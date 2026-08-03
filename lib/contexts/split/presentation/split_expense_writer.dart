import '../domain/split_input.dart';

/// Shared surface both `SplitController` (the split tab) and
/// `GroupDetailController` (a single group's screen) expose for writing
/// expenses, so `SplitExpenseSheet` can be handed either one without caring
/// which — both already need identical create/update/delete methods since
/// they forward straight to the same repository port.
///
/// [mutationError]/[mutationErrorSeq] mirror `FriendsController`: after
/// awaiting a mutation, a caller compares the sequence number it captured
/// beforehand against the current one to tell "this call failed" from "an
/// unrelated later failure is still showing" — the failed-submission case
/// (design.md) that must leave every typed field exactly as it was.
abstract class SplitExpenseWriter {
  Object? get mutationError;
  int get mutationErrorSeq;

  Future<void> createExpense(
    String idToken, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  });

  Future<void> updateExpense(
    String idToken,
    String expenseId, {
    String? groupId,
    required String payerUserId,
    required int amount,
    required String currency,
    required String description,
    required String day,
    required SplitInput split,
  });

  Future<void> deleteExpense(String idToken, String expenseId);
}
