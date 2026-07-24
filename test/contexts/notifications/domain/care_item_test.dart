import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';

CareSchedule _schedule({
  String? id = 'sch-1',
  List<int> repeatDays = const [1, 3, 5],
  int weekInterval = 1,
  double doseQuantity = 1,
}) => CareSchedule(
  id: id,
  timeOfDay: '08:00',
  repeatDays: repeatDays,
  weekInterval: weekInterval,
  startDate: DateTime(2026, 7, 20),
  doseQuantity: doseQuantity,
  nagIntervalMinutes: 0,
  enabled: true,
);

CareItem _item({
  CareCategory category = CareCategory.medication,
  String title = 'Metformin',
  List<CareSchedule>? schedules,
}) => CareItem(
  id: 'care-1',
  category: category,
  title: title,
  note: 'take with food',
  dose: '500mg',
  stock: 30,
  stockAlert: 5,
  schedules: schedules ?? [_schedule()],
);

void main() {
  group('CareCategory wire mapping', () {
    test('round-trips every category through its wire enum string', () {
      for (final category in CareCategory.values) {
        expect(careCategoryFromWire(category.wireValue), category);
      }
    });

    test('wire values match the confirmed backend enum strings', () {
      expect(CareCategory.medication.wireValue, 'medication');
      expect(CareCategory.rehab.wireValue, 'rehab');
      expect(CareCategory.radiotherapyCare.wireValue, 'radiotherapy_care');
      expect(CareCategory.custom.wireValue, 'custom');
    });

    test('an unrecognized wire value throws', () {
      expect(() => careCategoryFromWire('unknown'), throwsFormatException);
    });
  });

  group('CareSchedule value equality', () {
    test('two instances with the same fields are equal', () {
      expect(_schedule(), _schedule());
      expect(_schedule().hashCode, _schedule().hashCode);
    });

    test('a different id makes them unequal', () {
      expect(_schedule(id: 'sch-1'), isNot(_schedule(id: 'sch-2')));
    });

    test('a different repeatDays list makes them unequal', () {
      expect(
        _schedule(repeatDays: const [1, 3, 5]),
        isNot(_schedule(repeatDays: const [2, 4])),
      );
    });

    test('a different doseQuantity makes them unequal', () {
      expect(_schedule(doseQuantity: 1), isNot(_schedule(doseQuantity: 2)));
    });
  });

  group('CareItem value equality', () {
    test('two instances with the same fields are equal', () {
      expect(_item(), _item());
      expect(_item().hashCode, _item().hashCode);
    });

    test('a different category makes them unequal', () {
      expect(
        _item(category: CareCategory.medication),
        isNot(_item(category: CareCategory.rehab)),
      );
    });

    test('a different schedules list makes them unequal', () {
      expect(
        _item(schedules: [_schedule()]),
        isNot(_item(schedules: [_schedule(id: 'sch-2')])),
      );
    });
  });
}
