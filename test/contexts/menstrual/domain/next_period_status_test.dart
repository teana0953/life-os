import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/menstrual/domain/menstrual_period.dart';
import 'package:life_os/contexts/menstrual/domain/next_period_status.dart';

MenstrualPeriod _period(DateTime start, [DateTime? end]) =>
    MenstrualPeriod(id: 'p-${start.toIso8601String()}', startDate: start, endDate: end);

MenstrualOverview _overview({
  List<MenstrualPeriod> periods = const [],
  DateTime? predictedNextStart,
  MenstrualPeriod? lastPeriod,
}) => MenstrualOverview(
  periods: periods,
  stats: MenstrualStats(predictedNextStart: predictedNextStart),
  lastPeriod: lastPeriod ?? (periods.isEmpty ? null : periods.last),
);

void main() {
  group('computeNextPeriodStatus — no prediction', () {
    test('no records at all reads as "nothing recorded", not "one more"', () {
      final status = computeNextPeriodStatus(_overview(), DateTime(2026, 7, 28));

      expect(status.state, NextPeriodState.noRecords);
      expect(status.predictedNextStart, isNull);
      expect(status.days, isNull);
    });

    test('exactly one (finished) recorded period reads as "record one more"', () {
      // The backend needs two periods to derive a cycle, so this is the only
      // state where "record one more" is a promise that can be kept.
      final status = computeNextPeriodStatus(
        _overview(periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))]),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.needsOneMore);
      expect(status.predictedNextStart, isNull);
    });
  });

  group('computeNextPeriodStatus — a prediction outside any period', () {
    test('a prediction in the future counts the days to it, across a month '
        'boundary', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.upcoming);
      expect(status.days, 5);
      expect(status.predictedNextStart, DateTime(2026, 8, 2));
    });

    test('a prediction for today is its own state, not a zero-day countdown', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 28),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.today);
      expect(status.predictedNextStart, DateTime(2026, 7, 28));
    });

    test('a prediction in the past is overdue by that many days, and is not '
        'rolled forward', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 2),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.overdue);
      expect(status.days, 26);
      expect(status.predictedNextStart, DateTime(2026, 7, 2));
    });

    test('an afternoon clock does not eat a day off the countdown', () {
      // The recorded/predicted dates are local midnights (`_parseDate`) but the
      // clock carries the time of day: subtracting them directly would make a
      // 32.5-hour gap read as one day — i.e. every afternoon, "tomorrow" would
      // show as "expected today".
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 6, 1), DateTime(2026, 6, 5))],
          predictedNextStart: DateTime(2026, 7, 29),
        ),
        DateTime(2026, 7, 28, 15, 30),
      );

      expect(status.state, NextPeriodState.upcoming);
      expect(status.days, 1);
    });
  });

  group('computeNextPeriodStatus — ongoing', () {
    test('today inside a finished period is ongoing, counting the start day as '
        'day 1', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 7, 26), DateTime(2026, 7, 30))],
        ),
        DateTime(2026, 7, 26),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 1);
    });

    test('a period with no end date that started on or before today is ongoing', () {
      final status = computeNextPeriodStatus(
        _overview(periods: [_period(DateTime(2026, 7, 26))]),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 3);
    });

    test('an ongoing period still carries the predicted next start', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [
            _period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
            _period(DateTime(2026, 7, 26)),
          ],
          predictedNextStart: DateTime(2026, 8, 20),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 3);
      expect(status.predictedNextStart, DateTime(2026, 8, 20));
    });

    test('an ongoing period with nothing to predict from has a null prediction', () {
      // A brand-new user on the day of their first recording: one open period,
      // no cycle to derive. Nothing here may dereference the prediction.
      final status = computeNextPeriodStatus(
        _overview(periods: [_period(DateTime(2026, 7, 28))]),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 1);
      expect(status.predictedNextStart, isNull);
    });

    test('ongoing wins over an overdue prediction', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [
            _period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
            _period(DateTime(2026, 7, 26)),
          ],
          predictedNextStart: DateTime(2026, 7, 2),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 3);
    });

    test('a period whose end date is today is still ongoing (closed interval)', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 7, 24), DateTime(2026, 7, 28))],
          predictedNextStart: DateTime(2026, 8, 20),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 5);
    });

    test('a period that ended yesterday is not ongoing', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [_period(DateTime(2026, 7, 24), DateTime(2026, 7, 27))],
          predictedNextStart: DateTime(2026, 8, 20),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.upcoming);
      expect(status.days, 23);
    });

    test('the period covering today wins over a later-starting one that does '
        'not cover it', () {
      // `lastPeriod` is the largest *start* date, which after back-filling a
      // longer, earlier-starting period is not the one covering today. The
      // tracker's calendar marks today from all periods, so reading only
      // `lastPeriod` here would make the two screens contradict each other.
      final covering = _period(DateTime(2026, 7, 20), DateTime(2026, 7, 30));
      final laterStart = _period(DateTime(2026, 7, 22), DateTime(2026, 7, 24));
      final status = computeNextPeriodStatus(
        _overview(
          periods: [covering, laterStart],
          predictedNextStart: DateTime(2026, 8, 20),
          lastPeriod: laterStart,
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.ongoing);
      expect(status.days, 9);
    });

    test('a period starting in the future is not ongoing', () {
      final status = computeNextPeriodStatus(
        _overview(
          periods: [
            _period(DateTime(2026, 6, 1), DateTime(2026, 6, 5)),
            _period(DateTime(2026, 8, 5), DateTime(2026, 8, 9)),
          ],
          predictedNextStart: DateTime(2026, 8, 2),
        ),
        DateTime(2026, 7, 28),
      );

      expect(status.state, NextPeriodState.upcoming);
      expect(status.days, 5);
    });
  });
}
