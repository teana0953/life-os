import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';

void main() {
  test('fromJson parses the summary, logged days as a set, and rates', () {
    final calendar = HealthCalendar.fromJson(const {
      'year': 2026,
      'month': 7,
      'logged_days': ['2026-07-02', '2026-07-08'],
      'days_elapsed': 10,
      'logging_rate': 20,
      'diet_adherence_rate': 40,
    });

    expect(calendar.year, 2026);
    expect(calendar.month, 7);
    expect(calendar.loggedDays, {'2026-07-02', '2026-07-08'});
    expect(calendar.daysElapsed, 10);
    expect(calendar.loggingRate, 20);
    expect(calendar.dietAdherenceRate, 40);
  });

  test('fromJson tolerates null rates and missing logged_days', () {
    final calendar = HealthCalendar.fromJson(const {
      'year': 2026,
      'month': 9,
      'days_elapsed': 0,
      'logging_rate': null,
      'diet_adherence_rate': null,
    });

    expect(calendar.loggedDays, isEmpty);
    expect(calendar.loggingRate, isNull);
    expect(calendar.dietAdherenceRate, isNull);
  });
}
