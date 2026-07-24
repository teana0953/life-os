import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/domain/medication_reminder.dart';

MedicationReminder _reminder({
  List<String> times = const ['08:00'],
  List<int> daysOfWeek = const [1, 3, 5],
  bool enabled = true,
}) => MedicationReminder(
  id: 'rem-1',
  label: 'Metformin',
  times: times,
  daysOfWeek: daysOfWeek,
  weekInterval: 1,
  anchorDate: DateTime(2026, 7, 20),
  enabled: enabled,
);

void main() {
  group('MedicationReminder value equality', () {
    test('two instances with the same fields are equal', () {
      expect(_reminder(), _reminder());
      expect(_reminder().hashCode, _reminder().hashCode);
    });

    test('a different scalar field makes them unequal', () {
      expect(_reminder(enabled: true), isNot(_reminder(enabled: false)));
    });

    test('a different times list makes them unequal', () {
      expect(_reminder(times: const ['08:00']), isNot(_reminder(times: const ['09:00'])));
    });

    test('a different daysOfWeek list makes them unequal', () {
      expect(
        _reminder(daysOfWeek: const [1, 3, 5]),
        isNot(_reminder(daysOfWeek: const [2, 4])),
      );
    });
  });
}
