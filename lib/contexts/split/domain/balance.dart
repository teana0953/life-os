import 'split_exceptions.dart';

/// One person's balance. The same JSON shape is returned by two endpoints
/// with **different meaning** (design D2) — this type does not encode
/// which, because the reading is call-site-specific:
/// - `GET /api/split/balances`: a signed two-person net. Positive means
///   this person owes the caller.
/// - `GET /api/split/groups/:id/balances`: this member's net against the
///   whole group, including the caller themselves. Reusing the "positive
///   = they owe me" reading here prints the direction of money backwards.
///
/// Presentation must use call-site-specific copy ("owed to me" vs. a
/// group member's "should collect/should pay"), never a shared sentence.
/// `displayName` is only ever null in the genuine edge case where the
/// server has no name to give.
class Balance {
  final String userId;
  final String? displayName;
  final List<CurrencyBalance> balances;

  const Balance({required this.userId, required this.displayName, required this.balances});

  /// Throws [SplitFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. `display_name` is optional.
  factory Balance.fromJson(Map<String, dynamic> json) {
    try {
      return Balance(
        userId: json['user_id'] as String,
        displayName: json['display_name'] as String?,
        balances: (json['balances'] as List<dynamic>)
            .map((e) => CurrencyBalance.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}

/// A signed net amount in one currency's minor units. Never summed across
/// currencies (design.md).
class CurrencyBalance {
  final String currency;
  final int amount;

  const CurrencyBalance({required this.currency, required this.amount});

  factory CurrencyBalance.fromJson(Map<String, dynamic> json) {
    try {
      return CurrencyBalance(
        currency: json['currency'] as String,
        amount: json['amount'] as int,
      );
    } catch (_) {
      throw const SplitFetchFailure();
    }
  }
}
