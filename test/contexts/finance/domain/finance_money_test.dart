import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_money.dart';
import 'package:life_os/contexts/finance/domain/finance_type.dart';

void main() {
  group('decimalDigitsFor', () {
    test('TWD/JPY/KRW have zero decimal digits', () {
      expect(decimalDigitsFor('TWD'), 0);
      expect(decimalDigitsFor('JPY'), 0);
      expect(decimalDigitsFor('KRW'), 0);
    });

    test('every other supported currency has two decimal digits', () {
      for (final currency in ['USD', 'EUR', 'CNY', 'GBP', 'HKD', 'AUD', 'CAD']) {
        expect(decimalDigitsFor(currency), 2, reason: currency);
      }
    });
  });

  group('formatMinorUnits', () {
    test('zero-decimal currency shows the raw integer', () {
      expect(formatMinorUnits(1234, 'TWD'), '1234');
    });

    test('two-decimal currency inserts the decimal point', () {
      expect(formatMinorUnits(1234, 'USD'), '12.34');
    });

    test('two-decimal currency pads a single-digit fraction', () {
      expect(formatMinorUnits(1205, 'USD'), '12.05');
    });

    test('zero amount formats as 0', () {
      expect(formatMinorUnits(0, 'TWD'), '0');
      expect(formatMinorUnits(0, 'USD'), '0.00');
    });
  });

  group('formatSignedMinorUnits', () {
    test('expense is prefixed with a minus sign', () {
      expect(
        formatSignedMinorUnits(1234, 'USD', FinanceType.expense),
        '-12.34',
      );
    });

    test('income is prefixed with a plus sign', () {
      expect(
        formatSignedMinorUnits(1234, 'USD', FinanceType.income),
        '+12.34',
      );
    });
  });

  group('parseAmountToMinorUnits', () {
    test('parses a whole number for a zero-decimal currency', () {
      expect(parseAmountToMinorUnits('120', 'TWD'), 120);
    });

    test('parses a decimal input for a two-decimal currency', () {
      expect(parseAmountToMinorUnits('12.5', 'USD'), 1250);
    });

    test('rounds a third decimal digit', () {
      expect(parseAmountToMinorUnits('12.345', 'USD'), 1235);
    });

    test('truncates a decimal typed for a zero-decimal currency by rounding', () {
      expect(parseAmountToMinorUnits('120.6', 'TWD'), 121);
    });

    test('empty input is invalid', () {
      expect(parseAmountToMinorUnits('', 'TWD'), isNull);
      expect(parseAmountToMinorUnits('   ', 'TWD'), isNull);
    });

    test('non-numeric input is invalid', () {
      expect(parseAmountToMinorUnits('abc', 'TWD'), isNull);
    });

    test('negative input is invalid', () {
      expect(parseAmountToMinorUnits('-5', 'TWD'), isNull);
    });

    test('zero is valid input (the caller\'s save gate treats 0 separately)', () {
      expect(parseAmountToMinorUnits('0', 'TWD'), 0);
    });
  });
}
