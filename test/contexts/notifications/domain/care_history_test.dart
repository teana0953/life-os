import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  CareTodayStatus status = CareTodayStatus.done,
  String timeOfDay = '08:00',
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: 'Metformin',
  timeOfDay: timeOfDay,
  localDate: '2026-07-22',
  status: status,
  doseQuantity: 1,
);

CareHistoryDay _day({
  String date = '2026-07-22',
  List<CareTodaySlot> slots = const [],
}) => CareHistoryDay(date: date, slots: slots);

void main() {
  group('careDayState', () {
    test('noSchedule when the day has no slots', () {
      expect(careDayState(_day(slots: const [])), CareDayState.noSchedule);
    });

    test('full when every slot is done', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.done),
          _slot(careScheduleId: 'b', status: CareTodayStatus.done),
        ],
      );
      expect(careDayState(day), CareDayState.full);
    });

    test('partial when some but not all slots are done', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.done),
          _slot(careScheduleId: 'b', status: CareTodayStatus.skipped),
        ],
      );
      expect(careDayState(day), CareDayState.partial);
    });

    test('missed when the day has slots but none are done', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.skipped),
          _slot(careScheduleId: 'b', status: CareTodayStatus.missed),
        ],
      );
      expect(careDayState(day), CareDayState.missed);
    });

    test('missed counts an all-skipped day (not only all-missed)', () {
      final day = _day(
        slots: [_slot(status: CareTodayStatus.skipped)],
      );
      expect(careDayState(day), CareDayState.missed);
    });

    test('done only counts CareTodayStatus.done, not pending/overdue — an '
        'overdue slot is due (genuinely late), so a pending+overdue day '
        'reads missed, not upcoming', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.pending),
          _slot(careScheduleId: 'b', status: CareTodayStatus.overdue),
        ],
      );
      expect(careDayState(day), CareDayState.missed);
    });

    test('upcoming (not missed) when every slot is pending — nothing has '
        'been done, but nothing is due yet either (this is what today\'s '
        'cell looks like before anything is logged)', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.pending),
          _slot(careScheduleId: 'b', status: CareTodayStatus.pending),
        ],
      );
      expect(careDayState(day), CareDayState.upcoming);
    });

    test('an overdue-only day reads missed, not upcoming — overdue is past '
        'due with no record, i.e. genuinely late', () {
      final day = _day(
        slots: [_slot(status: CareTodayStatus.overdue)],
      );
      expect(careDayState(day), CareDayState.missed);
    });

    test('missed still applies when a missed slot is mixed with a pending '
        'slot (a genuinely failed slot outweighs the not-yet-due one)', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.missed),
          _slot(careScheduleId: 'b', status: CareTodayStatus.pending),
        ],
      );
      expect(careDayState(day), CareDayState.missed);
    });

    test('a day with one done slot and one still-pending slot reads full, '
        'not partial — every *due* slot is done, so the day state agrees '
        "with careHistorySummary's rate (100%), not a shortfall", () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.done),
          _slot(careScheduleId: 'b', status: CareTodayStatus.pending),
        ],
      );
      expect(careDayState(day), CareDayState.full);
    });

    test('a done slot alongside an overdue slot reads partial — overdue is '
        'due, so it is a real shortfall against the rate', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.done),
          _slot(careScheduleId: 'b', status: CareTodayStatus.overdue),
        ],
      );
      expect(careDayState(day), CareDayState.partial);
    });
  });

  group('careHistorySummary', () {
    test('adherenceRate is the sum of done over the sum of slots', () {
      final days = [
        _day(
          date: '2026-07-21',
          slots: [
            _slot(careScheduleId: 'a', status: CareTodayStatus.done),
            _slot(careScheduleId: 'b', status: CareTodayStatus.skipped),
            _slot(careScheduleId: 'c', status: CareTodayStatus.done),
          ],
        ),
      ];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, closeTo(2 / 3, 1e-9));
    });

    test('adherenceRate is null when there is nothing scheduled', () {
      final days = [_day(slots: const [])];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, isNull);
    });

    test('daysWithDose counts days with at least one done slot', () {
      final days = [
        _day(
          date: '2026-07-20',
          slots: [_slot(status: CareTodayStatus.done)],
        ),
        _day(
          date: '2026-07-21',
          slots: [_slot(status: CareTodayStatus.skipped)],
        ),
        _day(date: '2026-07-22', slots: const []),
      ];

      final summary = careHistorySummary(days);

      expect(summary.daysWithDose, 1);
    });

    test('missedCount sums slots with status==missed across days, distinct '
        'from the day-state missed', () {
      final days = [
        _day(
          date: '2026-07-20',
          slots: [
            _slot(careScheduleId: 'a', status: CareTodayStatus.missed),
            _slot(careScheduleId: 'b', status: CareTodayStatus.skipped),
          ],
        ),
        _day(
          date: '2026-07-21',
          slots: [_slot(careScheduleId: 'c', status: CareTodayStatus.missed)],
        ),
      ];

      final summary = careHistorySummary(days);

      // Two slot-level missed statuses, even though both days are
      // day-state "missed" (one has an extra skipped slot).
      expect(summary.missedCount, 2);
    });

    test('a fully-done day yields an unclamped rate of exactly 1.0 (done is '
        'a subset of slots, never exceeds it)', () {
      final days = [
        _day(
          slots: [
            _slot(careScheduleId: 'a', status: CareTodayStatus.done),
            _slot(careScheduleId: 'b', status: CareTodayStatus.done),
          ],
        ),
      ];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, 1.0);
    });

    test('adherenceRate excludes not-yet-due (pending) slots from the '
        "denominator, so today's not-yet-due slots don't drag the rate "
        'toward 0%', () {
      final days = [
        _day(
          slots: [
            _slot(careScheduleId: 'a', status: CareTodayStatus.pending),
            _slot(careScheduleId: 'b', status: CareTodayStatus.pending),
          ],
        ),
      ];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, isNull);
    });

    test('adherenceRate counts overdue slots in the denominator as a real '
        'miss — overdue is past due with no record, not "not yet due"', () {
      final days = [
        _day(
          slots: [_slot(status: CareTodayStatus.overdue)],
        ),
      ];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, 0.0);
    });

    test('a done slot alongside a not-yet-due slot rates 100%, not 50% — '
        'the pending slot is excluded from the denominator entirely', () {
      final days = [
        _day(
          slots: [
            _slot(careScheduleId: 'a', status: CareTodayStatus.done),
            _slot(careScheduleId: 'b', status: CareTodayStatus.pending),
          ],
        ),
      ];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, 1.0);
    });
  });

  group('careDayStateCounts', () {
    test('counts each day into its CareDayState bucket, all five states '
        'present', () {
      final days = [
        _day(
          date: '2026-07-18',
          slots: [_slot(status: CareTodayStatus.done)],
        ),
        _day(
          date: '2026-07-19',
          slots: [
            _slot(careScheduleId: 'a', status: CareTodayStatus.done),
            _slot(careScheduleId: 'b', status: CareTodayStatus.skipped),
          ],
        ),
        _day(
          date: '2026-07-20',
          slots: [_slot(status: CareTodayStatus.missed)],
        ),
        _day(
          date: '2026-07-21',
          slots: [_slot(status: CareTodayStatus.pending)],
        ),
        _day(date: '2026-07-22', slots: const []),
      ];

      final counts = careDayStateCounts(days);

      expect(counts[CareDayState.full], 1);
      expect(counts[CareDayState.partial], 1);
      expect(counts[CareDayState.missed], 1);
      expect(counts[CareDayState.upcoming], 1);
      expect(counts[CareDayState.noSchedule], 1);
    });

    test('empty days list — every state counts 0', () {
      final counts = careDayStateCounts(const []);

      for (final state in CareDayState.values) {
        expect(counts[state], 0);
      }
    });

    test('all noSchedule days — only that bucket is non-zero', () {
      final days = [
        _day(date: '2026-07-20', slots: const []),
        _day(date: '2026-07-21', slots: const []),
      ];

      final counts = careDayStateCounts(days);

      expect(counts[CareDayState.noSchedule], 2);
      expect(counts[CareDayState.full], 0);
      expect(counts[CareDayState.partial], 0);
      expect(counts[CareDayState.missed], 0);
      expect(counts[CareDayState.upcoming], 0);
    });
  });

  group('careHistoryIsEmpty', () {
    test('true when every day has no slots (the dense-array empty state)', () {
      final days = [
        _day(date: '2026-07-20', slots: const []),
        _day(date: '2026-07-21', slots: const []),
      ];

      expect(careHistoryIsEmpty(days), isTrue);
    });

    test('false when at least one day has a slot', () {
      final days = [
        _day(date: '2026-07-20', slots: const []),
        _day(date: '2026-07-21', slots: [_slot()]),
      ];

      expect(careHistoryIsEmpty(days), isFalse);
    });
  });
}
