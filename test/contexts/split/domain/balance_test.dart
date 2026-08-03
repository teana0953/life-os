import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

void main() {
  group('Balance.fromJson', () {
    test('parses a valid payload with multiple currencies, never summed', () {
      final balance = Balance.fromJson({
        'user_id': 'u1',
        'display_name': 'Alex',
        'balances': [
          {'currency': 'TWD', 'amount': 500},
          {'currency': 'USD', 'amount': -300},
        ],
      });

      expect(balance.userId, 'u1');
      expect(balance.balances, hasLength(2));
      expect(balance.balances[0].currency, 'TWD');
      expect(balance.balances[0].amount, 500);
      expect(balance.balances[1].amount, -300);
    });

    test('tolerates a missing display_name', () {
      final balance = Balance.fromJson({'user_id': 'u1', 'display_name': null, 'balances': []});

      expect(balance.displayName, isNull);
    });

    test('throws SplitFetchFailure for a missing required field', () {
      expect(
        () => Balance.fromJson({'display_name': 'Alex', 'balances': []}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      expect(
        () => Balance.fromJson({'user_id': 'u1', 'display_name': 'Alex', 'balances': 'oops'}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });
  });

  group('CurrencyBalance.fromJson', () {
    test('parses a negative signed amount', () {
      final balance = CurrencyBalance.fromJson({'currency': 'TWD', 'amount': -150});

      expect(balance.amount, -150);
    });

    test('throws SplitFetchFailure for a wrong-typed required field', () {
      expect(
        () => CurrencyBalance.fromJson({'currency': 'TWD', 'amount': 'oops'}),
        throwsA(isA<SplitFetchFailure>()),
      );
    });
  });
}
