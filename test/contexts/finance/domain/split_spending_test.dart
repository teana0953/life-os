import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_exceptions.dart';
import 'package:life_os/contexts/finance/domain/split_spending.dart';

void main() {
  group('SplitSpending.fromJson', () {
    test('parses a valid payload', () {
      final spending = SplitSpending.fromJson({'currency': 'TWD', 'amount': 500});

      expect(spending.currency, 'TWD');
      expect(spending.amount, 500);
    });

    test('throws FinanceFetchFailure for a missing required field', () {
      expect(
        () => SplitSpending.fromJson({'amount': 500}),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });

    test('throws FinanceFetchFailure for a wrong-typed required field', () {
      expect(
        () => SplitSpending.fromJson({'currency': 'TWD', 'amount': 'oops'}),
        throwsA(isA<FinanceFetchFailure>()),
      );
    });
  });
}
