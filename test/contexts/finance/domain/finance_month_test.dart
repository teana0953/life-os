import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/finance/domain/finance_month.dart';

void main() {
  group('monthOf', () {
    test('extracts the YYYY-MM prefix from a date', () {
      expect(monthOf('2026-07-31'), '2026-07');
    });
  });

  group('monthStart / monthEnd', () {
    test('monthStart is the 1st', () {
      expect(monthStart('2026-07'), '2026-07-01');
    });

    test('monthEnd is the 31st for a 31-day month', () {
      expect(monthEnd('2026-07'), '2026-07-31');
    });

    test('monthEnd is the 30th for a 30-day month', () {
      expect(monthEnd('2026-04'), '2026-04-30');
    });

    test('monthEnd is the 29th for February in a leap year', () {
      expect(monthEnd('2024-02'), '2024-02-29');
    });

    test('monthEnd is the 28th for February in a non-leap year', () {
      expect(monthEnd('2026-02'), '2026-02-28');
    });

    test('monthEnd is the 28th for a century non-leap year (2100)', () {
      expect(monthEnd('2100-02'), '2100-02-28');
    });
  });

  group('nextMonth / previousMonth', () {
    test('nextMonth rolls within a year', () {
      expect(nextMonth('2026-07'), '2026-08');
    });

    test('nextMonth rolls over into the next year at December', () {
      expect(nextMonth('2026-12'), '2027-01');
    });

    test('previousMonth rolls within a year', () {
      expect(previousMonth('2026-07'), '2026-06');
    });

    test('previousMonth rolls back into the previous year at January', () {
      expect(previousMonth('2026-01'), '2025-12');
    });
  });

  group('monthStringOf', () {
    test('reads the year and month fields as YYYY-MM', () {
      expect(monthStringOf(DateTime(2026, 7, 15)), '2026-07');
    });

    test('pads a single-digit month', () {
      expect(monthStringOf(DateTime(2024, 3, 1)), '2024-03');
    });

    test('is unaffected by a time-of-day at either end of the day', () {
      expect(monthStringOf(DateTime(2026, 1, 1, 0, 0)), '2026-01');
      expect(monthStringOf(DateTime(2026, 1, 31, 23, 59)), '2026-01');
    });

    test('round-trips with monthDateTime', () {
      expect(monthStringOf(monthDateTime('2019-11')), '2019-11');
    });
  });
}
