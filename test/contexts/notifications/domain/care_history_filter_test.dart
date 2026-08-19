import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history_filter.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';

CareTodaySlot _slot({
  String careItemId = 'care-1',
  String title = 'Metformin',
  CareCategory category = CareCategory.medication,
  CareTodayStatus status = CareTodayStatus.done,
  String timeOfDay = '08:00',
  String localDate = '2026-07-22',
}) => CareTodaySlot(
  careItemId: careItemId,
  careScheduleId: '$careItemId-$timeOfDay',
  category: category,
  title: title,
  timeOfDay: timeOfDay,
  localDate: localDate,
  status: status,
  doseQuantity: 1,
);

void main() {
  group('CareHistoryFilter', () {
    test('a filter with nothing selected is empty and applies nothing', () {
      const filter = CareHistoryFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.appliedCount, 0);
    });

    test('appliedCount counts each selected value, item included', () {
      const filter = CareHistoryFilter(
        categories: {CareCategory.medication, CareCategory.rehab},
        statuses: {CareTodayStatus.done},
        careItemId: 'care-1',
      );
      expect(filter.isEmpty, isFalse);
      expect(filter.appliedCount, 4);
    });

    test('copyWith replaces only what it is given', () {
      const filter = CareHistoryFilter(
        categories: {CareCategory.medication},
        careItemId: 'care-1',
      );
      final withStatus = filter.copyWith(statuses: {CareTodayStatus.missed});
      expect(withStatus.categories, {CareCategory.medication});
      expect(withStatus.careItemId, 'care-1');
      expect(withStatus.statuses, {CareTodayStatus.missed});
    });

    // `copyWith(careItemId: null)` cannot mean "clear it" — that is
    // indistinguishable from the argument being omitted — so clearing needs
    // its own flag. Without this the "all items" choice would silently keep
    // the previously selected item.
    test('clearCareItem clears the item selection', () {
      const filter = CareHistoryFilter(careItemId: 'care-1');
      expect(filter.copyWith(clearCareItem: true).careItemId, isNull);
      expect(filter.copyWith().careItemId, 'care-1');
    });

    test('equal selections are equal regardless of set iteration order', () {
      const a = CareHistoryFilter(
        categories: {CareCategory.medication, CareCategory.rehab},
        statuses: {CareTodayStatus.done, CareTodayStatus.missed},
        careItemId: 'care-1',
      );
      const b = CareHistoryFilter(
        categories: {CareCategory.rehab, CareCategory.medication},
        statuses: {CareTodayStatus.missed, CareTodayStatus.done},
        careItemId: 'care-1',
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(b.copyWith(statuses: const {})));
    });
  });

  group('applyCareHistoryFilter', () {
    final days = [
      const CareHistoryDay(date: '2026-07-20', slots: []),
      CareHistoryDay(
        date: '2026-07-21',
        slots: [
          _slot(localDate: '2026-07-21'),
          _slot(
            careItemId: 'care-2',
            title: 'Walk',
            category: CareCategory.rehab,
            status: CareTodayStatus.missed,
            timeOfDay: '18:00',
            localDate: '2026-07-21',
          ),
        ],
      ),
      CareHistoryDay(
        date: '2026-07-22',
        slots: [
          _slot(status: CareTodayStatus.missed),
          _slot(
            careItemId: 'care-2',
            title: 'Walk',
            category: CareCategory.rehab,
            status: CareTodayStatus.done,
            timeOfDay: '18:00',
          ),
        ],
      ),
    ];

    test('an empty filter returns the very same list', () {
      expect(
        identical(applyCareHistoryFilter(days, const CareHistoryFilter()), days),
        isTrue,
      );
    });

    test('filters by category', () {
      final filtered = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(categories: {CareCategory.rehab}),
      );
      expect(
        filtered.expand((d) => d.slots).map((s) => s.careItemId).toSet(),
        {'care-2'},
      );
    });

    test('filters by status, several statuses meaning either', () {
      final filtered = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(
          statuses: {CareTodayStatus.missed, CareTodayStatus.done},
        ),
      );
      expect(filtered.expand((d) => d.slots).length, 4);

      final missedOnly = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(statuses: {CareTodayStatus.missed}),
      );
      expect(
        missedOnly.expand((d) => d.slots).map((s) => s.status).toSet(),
        {CareTodayStatus.missed},
      );
      expect(missedOnly.expand((d) => d.slots).length, 2);
    });

    test('filters by care item', () {
      final filtered = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(careItemId: 'care-1'),
      );
      expect(filtered.expand((d) => d.slots).length, 2);
      expect(
        filtered.expand((d) => d.slots).map((s) => s.careItemId).toSet(),
        {'care-1'},
      );
    });

    // The three dimensions narrow together (AND), not widen (OR) — an OR
    // would return every rehab slot *plus* every done slot.
    test('the three dimensions combine as AND', () {
      final filtered = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(
          categories: {CareCategory.rehab},
          statuses: {CareTodayStatus.done},
          careItemId: 'care-2',
        ),
      );
      expect(filtered.expand((d) => d.slots).length, 1);
      expect(filtered.expand((d) => d.slots).single.localDate, '2026-07-22');
    });

    // LINCHPIN. `careHistoryIsEmpty`, `careDayStateCounts` and
    // `careDayState` are all built on the backend's dense-days invariant
    // (one entry per calendar date, empty slots when nothing was scheduled).
    // Dropping filtered-out days instead of emptying them would erase the
    // `noSchedule` count and make the empty-state check read the wrong
    // thing.
    test('keeps one entry per day, emptying rather than dropping days', () {
      final filtered = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(careItemId: 'nobody'),
      );
      expect(filtered.length, days.length);
      expect(filtered.map((d) => d.date), days.map((d) => d.date));
      expect(careHistoryIsEmpty(filtered), isTrue);
      final counts = careDayStateCounts(filtered);
      expect(counts.keys.toSet(), CareDayState.values.toSet());
      expect(counts[CareDayState.noSchedule], days.length);
    });

    test('the summary of a filtered range describes only the kept slots', () {
      final filtered = applyCareHistoryFilter(
        days,
        const CareHistoryFilter(categories: {CareCategory.rehab}),
      );
      final summary = careHistorySummary(filtered);
      expect(summary.adherenceRate, 0.5);
      expect(summary.daysWithDose, 1);
      expect(summary.missedCount, 1);
    });

    test('does not mutate the days it was given', () {
      final before = days.map((d) => d.slots.length).toList();
      applyCareHistoryFilter(
        days,
        const CareHistoryFilter(categories: {CareCategory.rehab}),
      );
      expect(days.map((d) => d.slots.length).toList(), before);
    });
  });

  group('careHistoryItemOptions', () {
    test('lists each care item once, sorted by title', () {
      final options = careHistoryItemOptions([
        CareHistoryDay(
          date: '2026-07-21',
          slots: [
            _slot(careItemId: 'care-2', title: 'Walk'),
            _slot(careItemId: 'care-1', title: 'Metformin'),
          ],
        ),
        CareHistoryDay(
          date: '2026-07-22',
          slots: [
            _slot(careItemId: 'care-1', title: 'Metformin', timeOfDay: '20:00'),
            _slot(careItemId: 'care-3', title: 'Aspirin'),
          ],
        ),
      ]);
      expect(
        options,
        [
          (id: 'care-3', title: 'Aspirin'),
          (id: 'care-1', title: 'Metformin'),
          (id: 'care-2', title: 'Walk'),
        ],
      );
    });

    test('is empty for a range with no slots', () {
      expect(
        careHistoryItemOptions([
          const CareHistoryDay(date: '2026-07-22', slots: []),
        ]),
        isEmpty,
      );
    });
  });
}
