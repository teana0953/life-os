import 'split_exceptions.dart';

/// A recorded repayment between two people (design.md D0–D5). Unlike
/// [SplitExpense], a settlement always has a well-defined direction:
/// [fromUserId] paid, [toUserId] received. `groupId` is `null` for every
/// settlement this UI creates (design D0 — settling only ever starts from a
/// two-person balance), but is read here as-is since the backend allows it.
///
/// `fromDisplayName`/`toDisplayName` come from the server, same as
/// `SplitExpense.payerDisplayName` — never guessed client-side.
class Settlement {
  final String id;
  final String? groupId;
  final String fromUserId;
  final String? fromDisplayName;
  final String toUserId;
  final String? toDisplayName;
  final int amount;
  final String currency;
  final String day;
  final String? note;
  final String createdByUserId;

  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromUserId,
    required this.fromDisplayName,
    required this.toUserId,
    required this.toDisplayName,
    required this.amount,
    required this.currency,
    required this.day,
    required this.note,
    required this.createdByUserId,
  });

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. `group_id`/`note` are
  /// nullable; `from_display_name`/`to_display_name` are optional.
  factory Settlement.fromJson(Map<String, dynamic> json) {
    try {
      return Settlement(
        id: json['id'] as String,
        groupId: json['group_id'] as String?,
        fromUserId: json['from_user_id'] as String,
        fromDisplayName: json['from_display_name'] as String?,
        toUserId: json['to_user_id'] as String,
        toDisplayName: json['to_display_name'] as String?,
        amount: json['amount'] as int,
        currency: json['currency'] as String,
        day: json['day'] as String,
        note: json['note'] as String?,
        createdByUserId: json['created_by_user_id'] as String,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}
