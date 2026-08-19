import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_history_period.dart';
import 'package:life_os/shared/date/day_format.dart';

void main() {
  group('CareHistoryPeriod.span', () {
    test('resolves to the same range as dayRangeEndingOn', () {
      final now = DateTime(2026, 7, 22, 23, 30);
      for (final days in [7, 30, 90]) {
        expect(
          CareHistoryPeriod.span(days).resolve(now),
          dayRangeEndingOn(days, now),
        );
      }
    });

    test('reports its length and span days', () {
      const period = CareHistoryPeriod.span(30);
      expect(period.spanDays, 30);
      expect(period.lengthInDays, 30);
    });
  });

  group('CareHistoryPeriod.custom', () {
    test('resolves to the picked dates verbatim, ignoring the clock', () {
      const period = CareHistoryPeriod.custom('2026-03-01', '2026-05-20');
      expect(
        period.resolve(DateTime(2026, 7, 22)),
        (from: '2026-03-01', to: '2026-05-20'),
      );
      expect(
        period.resolve(DateTime(2030, 1, 1)),
        (from: '2026-03-01', to: '2026-05-20'),
      );
    });

    test('has no span days and counts both ends of its range', () {
      const period = CareHistoryPeriod.custom('2026-03-01', '2026-03-03');
      expect(period.spanDays, isNull);
      expect(period.lengthInDays, 3);
    });

    // A single-day range is the boundary the inclusive count gets wrong if
    // it is written as a bare difference.
    test('a from == to range is one day long', () {
      expect(
        const CareHistoryPeriod.custom('2026-03-01', '2026-03-01').lengthInDays,
        1,
      );
    });

    // Local-midnight arithmetic across a DST transition is off by an hour and
    // truncates to the wrong day count; this range straddles the US spring
    // forward (2026-03-08).
    test('counts calendar days across a DST transition', () {
      expect(
        const CareHistoryPeriod.custom('2026-03-01', '2026-03-15').lengthInDays,
        15,
      );
    });
  });

  group('CareHistoryPeriod equality', () {
    // The controller compares the period `days` were fetched for against the
    // current one to decide whether an edit failure left the two describing
    // different periods — identity comparison would make that repair fire on
    // every edit (or never).
    test('equal values of the same kind are equal', () {
      expect(
        const CareHistoryPeriod.span(30),
        const CareHistoryPeriod.span(30),
      );
      expect(
        const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
        const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
      );
      expect(
        const CareHistoryPeriod.span(30).hashCode,
        const CareHistoryPeriod.span(30).hashCode,
      );
    });

    test('different values are not equal', () {
      expect(
        const CareHistoryPeriod.span(30),
        isNot(const CareHistoryPeriod.span(90)),
      );
      expect(
        const CareHistoryPeriod.custom('2026-03-01', '2026-05-20'),
        isNot(const CareHistoryPeriod.custom('2026-03-01', '2026-05-21')),
      );
      expect(
        const CareHistoryPeriod.span(30),
        isNot(const CareHistoryPeriod.custom('2026-03-01', '2026-05-20')),
      );
    });
  });

  test('the backend caps a range at 366 days', () {
    expect(careHistoryMaxRangeDays, 366);
  });
}
