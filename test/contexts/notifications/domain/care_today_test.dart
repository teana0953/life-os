import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';

CareTodaySlot _slot({
  String? careItemId = 'care-1',
  String? careScheduleId = 'sch-1',
  bool itemDeleted = false,
  CareTodayStatus status = CareTodayStatus.pending,
  String timeOfDay = '08:00',
  String? doneTime,
  double doseQuantity = 1,
}) => CareTodaySlot(
  careItemId: careItemId,
  careScheduleId: careScheduleId,
  itemDeleted: itemDeleted,
  category: CareCategory.medication,
  title: 'Metformin',
  note: 'take with food',
  dose: '500mg',
  timeOfDay: timeOfDay,
  localDate: '2026-07-22',
  status: status,
  doneTime: doneTime,
  doseQuantity: doseQuantity,
);

void main() {
  group('CareTodayStatus wire mapping', () {
    test('round-trips every status through its wire enum string', () {
      const wireValues = {
        CareTodayStatus.pending: 'pending',
        CareTodayStatus.overdue: 'overdue',
        CareTodayStatus.done: 'done',
        CareTodayStatus.skipped: 'skipped',
        CareTodayStatus.missed: 'missed',
      };
      for (final entry in wireValues.entries) {
        expect(careTodayStatusFromWire(entry.value), entry.key);
      }
    });

    test('an unrecognized wire value throws', () {
      expect(() => careTodayStatusFromWire('unknown'), throwsFormatException);
    });
  });

  group('CareLogStatus wire mapping', () {
    test('wire values match the confirmed backend enum strings', () {
      expect(CareLogStatus.done.wireValue, 'done');
      expect(CareLogStatus.skipped.wireValue, 'skipped');
    });
  });

  group('CareTodaySlot value equality', () {
    test('two instances with the same fields are equal', () {
      expect(_slot(), _slot());
      expect(_slot().hashCode, _slot().hashCode);
    });

    test('a different status makes them unequal', () {
      expect(
        _slot(status: CareTodayStatus.pending),
        isNot(_slot(status: CareTodayStatus.overdue)),
      );
    });

    test('a different doneTime makes them unequal', () {
      expect(_slot(doneTime: null), isNot(_slot(doneTime: '09:05')));
    });

    test('nullable ids and itemDeleted participate in value equality', () {
      expect(
        _slot(careItemId: null, careScheduleId: null, itemDeleted: true),
        _slot(careItemId: null, careScheduleId: null, itemDeleted: true),
      );
      expect(_slot(), isNot(_slot(itemDeleted: true)));
    });
  });
}
