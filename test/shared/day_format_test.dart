import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/date/day_format.dart';

import '../support/l10n_test_app.dart';

/// Pumps a localized app and hands back a [BuildContext] under it, for the
/// `BuildContext`-taking formatters below.
Future<BuildContext> _localizedContext(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    l10nTestApp(locale: locale, home: const SizedBox.shrink()),
  );
  return tester.element(find.byType(SizedBox));
}

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

  group('tryParseDayString', () {
    test('parses a well-formed YYYY-MM-DD string', () {
      expect(tryParseDayString('2026-07-27'), DateTime(2026, 7, 27));
    });

    test('round-trips with dayString', () {
      final date = DateTime(2026, 1, 5);
      expect(tryParseDayString(dayString(date)), date);
    });

    test('returns null for a string that is not three dash-separated parts', () {
      expect(tryParseDayString('not-a-date'), isNull);
      expect(tryParseDayString(''), isNull);
      expect(tryParseDayString('2026-07'), isNull);
      expect(tryParseDayString('2026-07-27-01'), isNull);
    });

    test('returns null when a part is not an integer', () {
      expect(tryParseDayString('2026-xx-27'), isNull);
      expect(tryParseDayString('yyyy-07-27'), isNull);
      expect(tryParseDayString('2026-07-dd'), isNull);
    });

    // The dangerous case (design D4): DateTime's constructor silently *rolls
    // over* out-of-range components, so without a range check these parse
    // into perfectly plausible — and completely wrong — dates. A caller then
    // treats the date as known and pins a `done_time` to it, filing the
    // record under the wrong day, which is far harder to notice than a crash.
    test('returns null for out-of-range components instead of rolling over '
        'into a wrong-but-plausible date', () {
      // Would otherwise be DateTime(0, 0, 0) == 1999-11-30.
      expect(tryParseDayString('0000-00-00'), isNull);
      // Would otherwise be DateTime(2026, 13, 45) == 2027-02-14.
      expect(tryParseDayString('2026-13-45'), isNull);
      expect(tryParseDayString('2026-00-15'), isNull);
      expect(tryParseDayString('2026-07-00'), isNull);
      expect(tryParseDayString('2026-07-32'), isNull);
      expect(tryParseDayString('2026--7-27'), isNull);
      expect(tryParseDayString('2026-07--7'), isNull);
    });

    test('accepts the boundary values 01 and 12 / 31', () {
      expect(tryParseDayString('2026-01-01'), DateTime(2026, 1, 1));
      expect(tryParseDayString('2026-12-31'), DateTime(2026, 12, 31));
    });
  });

  group('mediumDateLabelOrDash', () {
    testWidgets('formats a parseable day string per the active locale', (
      tester,
    ) async {
      final context = await _localizedContext(tester);
      expect(
        mediumDateLabelOrDash(context, '2026-07-27'),
        mediumDateLabel(context, DateTime(2026, 7, 27)),
      );
    });

    testWidgets('falls back to "—" for a malformed day string', (tester) async {
      final context = await _localizedContext(tester);
      expect(mediumDateLabelOrDash(context, 'not-a-date'), '—');
      expect(mediumDateLabelOrDash(context, '2026-13-45'), '—');
    });
  });

  group('narrowWeekdayLabel', () {
    testWidgets('returns the locale\'s narrow weekday form', (tester) async {
      final context = await _localizedContext(tester);
      // 2026-07-27 is a Monday; 2026-07-28 a Tuesday.
      expect(narrowWeekdayLabel(context, DateTime(2026, 7, 27)), 'M');
      expect(narrowWeekdayLabel(context, DateTime(2026, 7, 28)), 'T');
    });

    testWidgets('follows the active locale (zh-Hant)', (tester) async {
      final context = await _localizedContext(
        tester,
        locale: const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      );
      expect(narrowWeekdayLabel(context, DateTime(2026, 7, 27)), '一');
      expect(narrowWeekdayLabel(context, DateTime(2026, 7, 28)), '二');
    });
  });

  group('parseInstant', () {
    test('parses a valid ISO-8601 UTC string into a DateTime', () {
      final result = parseInstant('2026-07-27T04:58:00.000Z');
      expect(result, DateTime.utc(2026, 7, 27, 4, 58));
      expect(result!.isUtc, isTrue);
    });

    test('an invalid string returns null', () {
      expect(parseInstant('not-a-date'), isNull);
    });

    test('an empty string returns null', () {
      expect(parseInstant(''), isNull);
    });
  });
}
