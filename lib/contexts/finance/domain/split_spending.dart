import 'finance_exceptions.dart';

/// One currency's total of what the caller personally owed on split
/// expenses in a month (design D6) — shown as its own line in the finance
/// overview, never folded into the expense total or the budget card.
///
/// Lives in finance's `domain`, not split's: `getSplitSpending` is added to
/// [FinanceRepository][../domain/finance_repository.dart], and putting this
/// type under split would make finance/domain depend on split/domain for no
/// reason (design.md).
class SplitSpending {
  final String currency;
  final int amount;

  const SplitSpending({required this.currency, required this.amount});

  /// Throws [FinanceFetchFailure] for a missing/wrong-typed required field
  /// rather than letting a cast error escape.
  factory SplitSpending.fromJson(Map<String, dynamic> json) {
    try {
      return SplitSpending(
        currency: json['currency'] as String,
        amount: json['amount'] as int,
      );
    } catch (_) {
      throw const FinanceFetchFailure(
        'Unable to load your split spending. Please try again.',
      );
    }
  }
}
