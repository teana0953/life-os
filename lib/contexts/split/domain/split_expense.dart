import 'split_exceptions.dart';
import 'split_share.dart';

/// A split expense. `day` is kept as the raw `YYYY-MM-DD` calendar-date
/// string the backend sends, never parsed as an instant — it must be fed
/// straight to `mediumDateLabelOrDash` (design.md, task 9.5); running it
/// through `parseInstant`/`toLocalTime` would shift it by a day.
/// `createdAt`/`updatedAt` are kept as raw ISO-8601 instant strings for the
/// same reason `FriendInvite` does — turning them into local time is a
/// presentation concern.
///
/// `payerDisplayName` comes from the server (backend PR #68): a payer may
/// have purely fronted the money and hold no share, so their name cannot
/// be recovered from [shares]. Null only in the genuine edge case where
/// the server has no name to give.
class SplitExpense {
  final String id;
  final String? groupId;
  final String payerUserId;
  final String? payerDisplayName;
  final String createdByUserId;
  final int amount;
  final String currency;
  final String description;
  final String day;
  final String splitMode;
  final List<SplitShare> shares;
  final String createdAt;
  final String updatedAt;

  /// The finance category the recorder picked, as a **name** — not an id.
  /// Categories are per-user, so the payer's id would mean nothing to the
  /// other participants; each participant's mirrored transaction resolves this
  /// name against their own list. `null` means the mirrors land in the
  /// fallback category, which is what happened before the picker existed.
  final String? categoryName;

  const SplitExpense({
    required this.id,
    required this.groupId,
    required this.payerUserId,
    required this.payerDisplayName,
    required this.createdByUserId,
    required this.amount,
    required this.currency,
    required this.description,
    required this.day,
    required this.splitMode,
    required this.shares,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
  });

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. `payer_display_name` is
  /// optional; `group_id` is nullable (a group-less, one-off expense).
  factory SplitExpense.fromJson(Map<String, dynamic> json) {
    try {
      return SplitExpense(
        id: json['id'] as String,
        groupId: json['group_id'] as String?,
        payerUserId: json['payer_user_id'] as String,
        payerDisplayName: json['payer_display_name'] as String?,
        createdByUserId: json['created_by_user_id'] as String,
        amount: json['amount'] as int,
        currency: json['currency'] as String,
        description: json['description'] as String,
        day: json['day'] as String,
        splitMode: json['split_mode'] as String,
        shares: (json['shares'] as List<dynamic>)
            .map((e) => SplitShare.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] as String,
        updatedAt: json['updated_at'] as String,
        categoryName: json['category_name'] as String?,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}
