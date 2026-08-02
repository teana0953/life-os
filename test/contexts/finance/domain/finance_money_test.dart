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

  group('formatMinorUnitsForDisplay', () {
    test('groups thousands in a whole-number currency', () {
      expect(formatMinorUnitsForDisplay(1234567, 'TWD'), '1,234,567');
    });

    test('groups only the integer part of a decimal currency', () {
      expect(formatMinorUnitsForDisplay(123456, 'USD'), '1,234.56');
    });

    test('leaves amounts below a thousand ungrouped', () {
      expect(formatMinorUnitsForDisplay(999, 'TWD'), '999');
      expect(formatMinorUnitsForDisplay(99999, 'USD'), '999.99');
    });

    test('puts a separator every three digits, not just the first', () {
      expect(formatMinorUnitsForDisplay(1234567890, 'TWD'), '1,234,567,890');
    });

    test('handles exact thousand boundaries', () {
      expect(formatMinorUnitsForDisplay(1000, 'TWD'), '1,000');
      expect(formatMinorUnitsForDisplay(100000, 'USD'), '1,000.00');
    });

    test('formats zero without a separator', () {
      expect(formatMinorUnitsForDisplay(0, 'TWD'), '0');
    });
  });

  group('signed display amounts', () {
    test('groups thousands behind the sign', () {
      expect(
        formatSignedMinorUnits(1234567, 'TWD', FinanceType.expense),
        '-1,234,567',
      );
      expect(
        formatSignedMinorUnits(1234567, 'TWD', FinanceType.income),
        '+1,234,567',
      );
    });
  });

  group('the input formatter stays ungrouped', () {
    // Input fields pre-fill with formatMinorUnits and that text is parsed
    // straight back. A grouped "1,234" would parse as null and silently blank
    // the field, so the two formatters must stay separate.
    test('formatMinorUnits never groups', () {
      expect(formatMinorUnits(1234567, 'TWD'), '1234567');
      expect(formatMinorUnits(123456, 'USD'), '1234.56');
    });

    test('its output round-trips through the parser', () {
      for (final amount in [1234567, 1000, 999, 0]) {
        expect(
          parseAmountToMinorUnits(formatMinorUnits(amount, 'TWD'), 'TWD'),
          amount,
        );
      }
      expect(
        parseAmountToMinorUnits(formatMinorUnits(123456, 'USD'), 'USD'),
        123456,
      );
    });

    test('the display form does not round-trip, which is why it is separate', () {
      expect(
        parseAmountToMinorUnits(
          formatMinorUnitsForDisplay(1234567, 'TWD'),
          'TWD',
        ),
        isNull,
      );
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
