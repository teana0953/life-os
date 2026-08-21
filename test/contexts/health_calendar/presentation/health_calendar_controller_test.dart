import 'dart:async';

import 'package:life_os/shared/screen_batch/section_outcome.dart';
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

  group('HealthCalendarController.applyBatchSection', () {
    const summary = HealthCalendar(
      year: 2026,
      month: 7,
      loggedDays: {'2026-07-03'},
      daysElapsed: 5,
      loggingRate: 20,
      dietAdherenceRate: 0,
    );

    test('ok lands the identical state load() lands for the same payload', () async {
      final viaLoad = _controller(_FakeRepository());
      await viaLoad.load('token');

      final viaBatch = _controller(_FakeRepository());
      viaBatch.claimBatchMonth(2026, 7);
      final applied = viaBatch.applyBatchSection(
        const SectionOk(summary),
        requestedYear: 2026,
        requestedMonth: 7,
      );

      expect(applied, isTrue);
      expect(viaBatch.status, viaLoad.status);
      expect(viaBatch.selectedMonth, viaLoad.selectedMonth);
      expect(viaBatch.calendar!.loggedDays, viaLoad.calendar!.loggedDays);
      expect(viaBatch.calendar!.loggingRate, viaLoad.calendar!.loggingRate);
    });

    test('unavailable reaches the fetch-failed state', () {
      final controller = _controller(_FakeRepository())
        ..claimBatchMonth(2026, 7);

      controller.applyBatchSection(
        const SectionUnavailable<HealthCalendar>(),
        requestedYear: 2026,
        requestedMonth: 7,
      );

      expect(controller.status, HealthCalendarStatus.error);
    });

    test('reauth reaches needsReauth', () {
      final controller = _controller(_FakeRepository())
        ..claimBatchMonth(2026, 7);

      controller.applyBatchSection(
        const SectionReauth<HealthCalendar>(),
        requestedYear: 2026,
        requestedMonth: 7,
      );

      expect(controller.status, HealthCalendarStatus.needsReauth);
    });

    // The section is always the round's own month. A card the user paged to
    // June must not be repainted with July's grid under June's header.
    test('a section for a month the card has left is refused, not applied', () async {
      final repo = _FakeRepository();
      final controller = _controller(repo);
      controller.claimBatchMonth(2026, 7);
      await controller.loadMonth('token', 2026, 6);

      final applied = controller.applyBatchSection(
        const SectionOk(summary),
        requestedYear: 2026,
        requestedMonth: 7,
      );

      expect(applied, isFalse);
      expect(controller.selectedMonth, DateTime(2026, 6));
      expect(controller.calendar!.month, 6);
    });

    // The mirror of the test above: a round claimed July, but by the time its
    // response lands the user has since paged BACK to August — the same
    // month the round's response happens to be a July-shaped… no: this
    // asserts the response is compared against the CLAIM, not only against
    // `selectedMonth`. A card could coincidentally page to the very month a
    // stale, already-superseded claim named; that must still be refused,
    // because it is not the round this particular claim belongs to.
    test(
      'a section matching selectedMonth but not the round that claimed it is refused',
      () async {
        final repo = _FakeRepository();
        final controller = _controller(repo);
        controller.claimBatchMonth(2026, 7);
        await controller.loadMonth('token', 2026, 8);
        // Page back to the exact month this stale claim named — the response
        // must still be refused, because it is not this round's claim.
        controller.claimBatchMonth(2026, 9);

        // loadMonth's own granular fetch already populated `calendar` for
        // August — capture it so the assertion below can tell "still that
        // granular fetch's data" from "overwritten by the stale claim".
        final fromLoadMonth = controller.calendar;

        final applied = controller.applyBatchSection(
          const SectionOk(summary),
          requestedYear: 2026,
          requestedMonth: 8,
        );

        expect(applied, isFalse);
        expect(controller.calendar, same(fromLoadMonth));
      },
    );

    // A sign-out between the round's request and its response. `reset` clears
    // the claim, so the previous user's section is stale — comparing against
    // `selectedMonth` instead would match its clock fallback (the current
    // month, which is exactly the month a round asks for) and land the signed
    // out user's figures in the next user's card.
    test('a section claimed before a reset is refused after it', () {
      final controller = _controller(_FakeRepository());
      controller.claimBatchMonth(2026, 7);

      controller.reset();
      final applied = controller.applyBatchSection(
        const SectionOk(summary),
        requestedYear: 2026,
        requestedMonth: 7,
      );

      expect(applied, isFalse);
      expect(controller.calendar, isNull);
    });
  });


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

  test('reset clears the viewed month back to the current month and drops the '
      "previous user's calendar", () async {
    final repo = _FakeRepository();
    final controller = _controller(repo);
    await controller.loadMonth('token', 2024, 3);
    expect(controller.selectedMonth, DateTime(2024, 3));
    expect(controller.calendar, isNotNull);

    controller.reset();

    expect(controller.selectedMonth, DateTime(2026, 7));
    expect(controller.calendar, isNull);
    expect(controller.status, HealthCalendarStatus.loading);
  });

  test('a response still in flight when reset runs never lands, so the next '
      "user never inherits the previous user's data", () async {
    final repo = _SlowRepository();
    final controller = _controller2(repo);

    // The current month is both what the card loads on entry and what reset
    // returns to — i.e. the month most likely to be in flight at sign-out.
    final pending = controller.loadMonth('token', 2026, 7);
    controller.reset();
    repo.completeWith(2026, 7);
    await pending;

    expect(controller.calendar, isNull);
    expect(controller.status, isNot(HealthCalendarStatus.loaded));
  });

  test('a failure still in flight when reset runs never lands', () async {
    final repo = _SlowRepository();
    final controller = _controller2(repo);

    final pending = controller.loadMonth('token', 2026, 7);
    controller.reset();
    repo.failWith(2026, 7, const HealthCalendarFetchFailure());
    await pending;

    expect(controller.status, HealthCalendarStatus.loading);
  });

  test('load after reset still opens the current month', () async {
    final repo = _FakeRepository();
    final controller = _controller(repo);
    await controller.loadMonth('token', 2024, 3);

    controller.reset();
    await controller.load('token');

    expect(repo.gotYear, 2026);
    expect(repo.gotMonth, 7);
    expect(controller.selectedMonth, DateTime(2026, 7));
    expect(controller.status, HealthCalendarStatus.loaded);
    expect(controller.calendar, isNotNull);
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
