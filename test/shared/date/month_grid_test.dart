import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/date/month_grid.dart';

void main() {
  group('monthWeeks', () {
    test('a month starting on Sunday has no leading blanks', () {
      // 2026-02-01 is a Sunday.
      final weeks = monthWeeks(DateTime(2026, 2, 1));
      expect(weeks.first.first, 1);
    });

    test('a month starting on Saturday has six leading blanks', () {
      // 2026-08-01 is a Saturday.
      final weeks = monthWeeks(DateTime(2026, 8, 1));
      expect(weeks.first.take(6), everyElement(isNull));
      expect(weeks.first.last, 1);
    });

    test('February of a leap year covers days 1..29', () {
      final weeks = monthWeeks(DateTime(2024, 2, 1));
      final days = weeks.expand((w) => w).whereType<int>().toList();
      expect(days, [for (var d = 1; d <= 29; d++) d]);
    });

    test('every week has exactly seven cells and trailing blanks pad', () {
      final weeks = monthWeeks(DateTime(2026, 7, 1));
      expect(weeks.every((w) => w.length == 7), isTrue);
      final days = weeks.expand((w) => w).whereType<int>().toList();
      expect(days.length, 31);
      expect(weeks.last.last, isNull);
    });

    test('only the year and month of the argument matter', () {
      expect(monthWeeks(DateTime(2026, 7, 19)), monthWeeks(DateTime(2026, 7)));
    });
  });
}
