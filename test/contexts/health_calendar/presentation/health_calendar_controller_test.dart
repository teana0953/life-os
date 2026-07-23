import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/health_calendar/application/get_health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_exceptions.dart';
import 'package:life_os/contexts/health_calendar/domain/health_calendar_repository.dart';
import 'package:life_os/contexts/health_calendar/presentation/health_calendar_controller.dart';

class _FakeRepository implements HealthCalendarRepository {
  Object? error;
  int? gotYear;
  int? gotMonth;
  String? gotToday;

  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) async {
    gotYear = year;
    gotMonth = month;
    gotToday = today;
    if (error != null) throw error!;
    return HealthCalendar(
      year: year,
      month: month,
      loggedDays: const {'2026-07-03'},
      daysElapsed: 5,
      loggingRate: 20,
      dietAdherenceRate: 0,
    );
  }
}

HealthCalendarController _controller(_FakeRepository repo) =>
    HealthCalendarController(
      GetHealthCalendar(repo),
      clock: () => DateTime(2026, 7, 5, 9, 30),
    );

void main() {
  test('load requests the current local month + today and loads the summary',
      () async {
    final repo = _FakeRepository();
    final controller = _controller(repo);

    await controller.load('token');

    expect(repo.gotYear, 2026);
    expect(repo.gotMonth, 7);
    expect(repo.gotToday, '2026-07-05'); // the clock's local date
    expect(controller.status, HealthCalendarStatus.loaded);
    expect(controller.calendar!.loggingRate, 20);
  });

  test('a 401 surfaces needsReauth', () async {
    final repo = _FakeRepository()
      ..error = const HealthCalendarReauthenticationRequired();
    final controller = _controller(repo);

    await controller.load('token');

    expect(controller.status, HealthCalendarStatus.needsReauth);
  });

  test('a fetch failure surfaces an error state', () async {
    final repo = _FakeRepository()..error = const HealthCalendarFetchFailure();
    final controller = _controller(repo);

    await controller.load('token');

    expect(controller.status, HealthCalendarStatus.error);
  });
}
