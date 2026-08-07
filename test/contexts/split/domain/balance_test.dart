import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/split/domain/balance.dart';
import 'package:life_os/contexts/split/domain/split_exceptions.dart';

void main() {
  group('CurrencyBalance.fromJson — schedules', () {
    test('reads the list, key by key', () {
      // The widget fixtures all construct the model directly, so nothing else
      // in the suite ever runs this parse — a misread key would surface only
      // against the real server.
      final cb = CurrencyBalance.fromJson({
        'currency': 'TWD',
        'amount': 11400,
        'schedules': [
          {'expense_id': 'e1', 'next_period': 3, 'total_periods': 12, 'period_amount': 500},
          {'expense_id': 'e2', 'next_period': 1, 'total_periods': 6, 'period_amount': 900},
        ],
      });

      // Two entries, not one merged figure, and each field from its own key:
      // reading `next_period` where `total_periods` belongs would still give
      // a plausible-looking row.
      expect(cb.schedules, hasLength(2));
      expect(cb.schedules[0].expenseId, 'e1');
      expect(cb.schedules[0].nextPeriod, 3);
      expect(cb.schedules[0].totalPeriods, 12);
      expect(cb.schedules[0].periodAmount, 500);
      expect(cb.schedules[1].totalPeriods, 6);
      expect(cb.schedules[1].periodAmount, 900);
    });

    test('an absent key is no schedules, not a failure', () {
      // The server omits it entirely for an unscheduled balance.
      final cb = CurrencyBalance.fromJson({'currency': 'TWD', 'amount': 500});
      expect(cb.schedules, isEmpty);
    });
  });

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
