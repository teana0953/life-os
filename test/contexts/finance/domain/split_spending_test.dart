import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/split_spending.dart';

void main() {
  group('SplitSpending.fromJson', () {
    test('parses a valid payload', () {
      final spending = SplitSpending.fromJson({
        'currency': 'TWD',
        'amount': 500,
        'counted_in_transactions': true,
      });

      expect(spending.currency, 'TWD');
      expect(spending.amount, 500);
      expect(spending.countedInTransactions, isTrue);
    });

    // The only place this parser runs: every widget and controller fixture
    // builds `SplitSpending` through its constructor, so a misread key is
    // invisible to all of them. And a misread key does not fail loudly — it
    // reads as "not counted" for every currency, which is precisely the claim
    // this change exists to stop the app from making about TWD.
    test('reads counted_in_transactions rather than defaulting it', () {
      final counted = SplitSpending.fromJson({
        'currency': 'TWD',
        'amount': 500,
        'counted_in_transactions': true,
      });
      final uncounted = SplitSpending.fromJson({
        'currency': 'THB',
        'amount': 500,
        'counted_in_transactions': false,
      });

      // Both directions: a parser that hard-codes either answer passes the
      // half that agrees with it.
      expect(counted.countedInTransactions, isTrue);
      expect(uncounted.countedInTransactions, isFalse);
    });

    test('throws FinanceFetchFailure when counted_in_transactions is missing', () {
      expect(
        () => SplitSpending.fromJson({'currency': 'TWD', 'amount': 500}),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });

    test('throws FinanceFetchFailure for a missing required field', () {
      expect(
        () => SplitSpending.fromJson({'amount': 500, 'counted_in_transactions': true}),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });

    test('throws FinanceFetchFailure for a wrong-typed required field', () {
      expect(
        () => SplitSpending.fromJson({
          'currency': 'TWD',
          'amount': 'oops',
          'counted_in_transactions': true,
        }),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });
  });
}
