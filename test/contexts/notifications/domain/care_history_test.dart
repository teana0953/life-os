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

    test('done only counts CareTodayStatus.done, not pending/overdue', () {
      final day = _day(
        slots: [
          _slot(careScheduleId: 'a', status: CareTodayStatus.pending),
          _slot(careScheduleId: 'b', status: CareTodayStatus.overdue),
        ],
      );
      expect(careDayState(day), CareDayState.missed);
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
      expect(summary.totalScheduled, 3);
    });

    test('adherenceRate is null when there is nothing scheduled', () {
      final days = [_day(slots: const [])];

      final summary = careHistorySummary(days);

      expect(summary.adherenceRate, isNull);
      expect(summary.totalScheduled, 0);
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
