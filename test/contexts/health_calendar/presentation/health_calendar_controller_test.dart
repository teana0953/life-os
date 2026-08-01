import 'dart:async';

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

  test('selectedMonth defaults to the clock month before any load', () {
    final controller = _controller(_FakeRepository());

    expect(controller.selectedMonth, DateTime(2026, 7));
  });

  test('loadMonth switches to that month and requests it', () async {
    final repo = _FakeRepository();
    final controller = _controller(repo);
    await controller.load('token');

    await controller.loadMonth('token', 2025, 3);

    expect(controller.selectedMonth, DateTime(2025, 3));
    expect(repo.gotYear, 2025);
    expect(repo.gotMonth, 3);
    // `today` stays the real local today — it is what days-elapsed is judged
    // against, not the month being viewed.
    expect(repo.gotToday, '2026-07-05');
    expect(controller.calendar!.year, 2025);
    expect(controller.calendar!.month, 3);
  });

  test('switching month drops the previous month\'s calendar immediately, so '
      'no month is ever drawn under another month\'s label', () async {
    final repo = _SlowRepository();
    final controller = _controller2(repo);
    final first = controller.loadMonth('token', 2026, 7);
    repo.completeWith(2026, 7);
    await first;
    expect(controller.calendar, isNotNull);

    final pending = controller.loadMonth('token', 2026, 5);
    expect(controller.calendar, isNull);
    repo.completeWith(2026, 5);
    await pending;
    expect(controller.calendar!.month, 5);
  });

  test('a slow response for a month the user left never lands', () async {
    final repo = _SlowRepository();
    final controller = _controller2(repo);

    // March is requested first and answered last.
    final march = controller.loadMonth('token', 2025, 3);
    final may = controller.loadMonth('token', 2025, 5);
    repo.completeWith(2025, 5);
    await may;
    expect(controller.calendar!.month, 5);

    repo.completeWith(2025, 3);
    await march;

    expect(controller.selectedMonth, DateTime(2025, 5));
    expect(controller.calendar!.month, 5, reason: 'the stale March response overwrote May');
    expect(controller.status, HealthCalendarStatus.loaded);
  });

  test('a stale failure does not put the current month into an error state',
      () async {
    final repo = _SlowRepository();
    final controller = _controller2(repo);

    final march = controller.loadMonth('token', 2025, 3);
    final may = controller.loadMonth('token', 2025, 5);
    repo.completeWith(2025, 5);
    await may;

    repo.failWith(2025, 3, const HealthCalendarFetchFailure());
    await march;

    expect(controller.status, HealthCalendarStatus.loaded);
    expect(controller.calendar!.month, 5);
  });
}

/// A repository whose responses are completed by the test, per month, so two
/// month switches can be resolved out of order.
class _SlowRepository implements HealthCalendarRepository {
  final _pending = <String, Completer<HealthCalendar>>{};

  static String _key(int year, int month) => '$year-$month';

  @override
  Future<HealthCalendar> getCalendar(
    String idToken, {
    required int year,
    required int month,
    required String today,
  }) {
    final completer = Completer<HealthCalendar>();
    _pending[_key(year, month)] = completer;
    return completer.future;
  }

  void completeWith(int year, int month) =>
      _pending.remove(_key(year, month))!.complete(
        HealthCalendar(
          year: year,
          month: month,
          loggedDays: const {},
          daysElapsed: 1,
          loggingRate: 10,
          dietAdherenceRate: 10,
        ),
      );

  void failWith(int year, int month, Object error) =>
      _pending.remove(_key(year, month))!.completeError(error);
}

HealthCalendarController _controller2(_SlowRepository repo) =>
    HealthCalendarController(
      GetHealthCalendar(repo),
      clock: () => DateTime(2026, 7, 5, 9, 30),
    );
