import 'finance_exceptions.dart';

/// One currency's total of what the caller personally owed on split
/// expenses in a month (design D6) — shown as its own line in the finance
/// overview.
///
/// Lives in finance's `domain`, not split's: `getSplitSpending` is added to
/// [FinanceRepository][../domain/finance_repository.dart], and putting this
/// type under split would make finance/domain depend on split/domain for no
/// reason (design.md).
class SplitSpending {
  final String currency;
  final int amount;

  /// Whether the server already mirrored this currency's shares into the
  /// user's own transactions — so they are inside the month's expense total
  /// and inside the budget. True for the currencies the ledger can hold
  /// (TWD and the rest of the backend's whitelist), false for the ones it
  /// cannot.
  ///
  /// Required, with no default, deliberately (design D1): the natural default
  /// is `false`, and `false` is exactly the answer the app used to give every
  /// currency — the wrong one for TWD, and the reason this field exists. A
  /// default would let any construction site quietly restore that claim.
  final bool countedInTransactions;

  const SplitSpending({
    required this.currency,
    required this.amount,
    required this.countedInTransactions,
  });

  /// Throws [FinanceFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape. That includes
  /// `counted_in_transactions`: read with a `?? false` fallback instead, a
  /// renamed or misspelt key would silently make every currency claim to be
  /// uncounted, and nothing downstream can tell that apart from the truth.
  factory SplitSpending.fromJson(Map<String, dynamic> json) {
    try {
      return SplitSpending(
        currency: json['currency'] as String,
        amount: json['amount'] as int,
        countedInTransactions: json['counted_in_transactions'] as bool,
      );
    } catch (_) {
      throw const FinanceFetchFailure(
        'Unable to load your split spending. Please try again.',
      );
    }
  }
}
