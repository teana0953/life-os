import 'split_exceptions.dart';

/// One participant's share of a [SplitExpense]. `displayName` comes from
/// the server (backend PR #67) — the client does not build a name table.
/// Design D1: the naive "group members + friends" name source is wrong,
/// because the backend only checks the *creator's* friendship, so a share
/// holder can see a co-participant who is neither their friend nor a
/// member of any group they share. Null only in the genuine edge case
/// where the server has no name to give.
class SplitShare {
  final String userId;
  final String? displayName;
  final int amount;

  const SplitShare({required this.userId, required this.displayName, required this.amount});

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. `display_name` is optional.
  factory SplitShare.fromJson(Map<String, dynamic> json) {
    try {
      return SplitShare(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        amount: json['amount'] as int,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}
