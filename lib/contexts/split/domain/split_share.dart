import 'split_exceptions.dart';

/// One participant's share of a [SplitExpense]. `displayName` comes from
/// the server (backend PR #67) — the client does not build a name table.
/// Design D1: the naive "group members + friends" name source is wrong,
/// because the backend only checks the *caller's* friendship, so a share
/// holder can see a co-participant who is neither their friend nor a
/// member of any group they share. Null only in the genuine edge case
/// where the server has no name to give.
class SplitShare {
  final String userId;
  final String? displayName;
  final int amount;

  /// The monthly repayment schedule this share is on, or null when it is
  /// owed in one go. Read so that an edit can send it back: the update sends
  /// the whole share list, so a schedule the client never saw is one the
  /// next save deletes — and deleting it charges the holder the whole amount
  /// again alongside the periods already in their ledger.
  final ShareSchedule? schedule;

  const SplitShare({required this.userId, required this.displayName, required this.amount, this.schedule});

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. `display_name` is optional.
  factory SplitShare.fromJson(Map<String, dynamic> json) {
    try {
      return SplitShare(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        amount: json['amount'] as int,
        schedule: json['schedule'] == null
            ? null
            : ShareSchedule.fromJson(json['schedule'] as Map<String, dynamic>),
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}

/// A share repaid in [periods] monthly instalments of [perPeriodAmount].
/// The two always multiply back to the share's amount — the server rejects
/// anything else — so no screen has to reconcile figures that disagree.
class ShareSchedule {
  final int periods;
  final int perPeriodAmount;

  const ShareSchedule({required this.periods, required this.perPeriodAmount});

  factory ShareSchedule.fromJson(Map<String, dynamic> json) {
    try {
      return ShareSchedule(
        periods: json['periods'] as int,
        perPeriodAmount: json['per_period_amount'] as int,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }

  Map<String, dynamic> toJson() => {'periods': periods, 'per_period_amount': perPeriodAmount};

  /// Compared by value: the form has to tell "the user changed the schedule"
  /// from "the user reopened the same expense", and identity would call every
  /// reload a change.
  @override
  bool operator ==(Object other) =>
      other is ShareSchedule && other.periods == periods && other.perPeriodAmount == perPeriodAmount;

  @override
  int get hashCode => Object.hash(periods, perPeriodAmount);
}
