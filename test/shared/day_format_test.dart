import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/date/day_format.dart';

void main() {
  group('dayRangeEndingOn', () {
    test('span 7 is today-6..today', () {
      final range = dayRangeEndingOn(7, DateTime(2026, 7, 22));
      expect(range.from, '2026-07-16');
      expect(range.to, '2026-07-22');
    });

    test('span 30 is today-29..today', () {
      final range = dayRangeEndingOn(30, DateTime(2026, 7, 22));
      expect(range.from, '2026-06-23');
      expect(range.to, '2026-07-22');
    });

    test('span 90 is today-89..today', () {
      final range = dayRangeEndingOn(90, DateTime(2026, 7, 22));
      expect(range.from, '2026-04-24');
      expect(range.to, '2026-07-22');
    });

    test('crosses a month boundary', () {
      final range = dayRangeEndingOn(7, DateTime(2026, 8, 2));
      expect(range.from, '2026-07-27');
      expect(range.to, '2026-08-02');
    });

    test('crosses a year boundary', () {
      final range = dayRangeEndingOn(7, DateTime(2026, 1, 3));
      expect(range.from, '2025-12-28');
      expect(range.to, '2026-01-03');
    });

    test('is anchored in UTC, so a local DST transition cannot shift the '
        'span by a day', () {
      // A local (non-UTC) DateTime straddling a DST transition; UTC-anchored
      // arithmetic must still count exactly spanDays-1 calendar days back.
      final range = dayRangeEndingOn(7, DateTime(2026, 3, 10));
      expect(range.from, '2026-03-04');
      expect(range.to, '2026-03-10');
    });
  });

  group('parseDayString', () {
    test('parses a YYYY-MM-DD string into a local date-only DateTime', () {
      final date = parseDayString('2026-07-27');
      expect(date, DateTime(2026, 7, 27));
    });

    test('round-trips with dayString', () {
      final date = DateTime(2026, 1, 5);
      expect(parseDayString(dayString(date)), date);
    });
  });
}
