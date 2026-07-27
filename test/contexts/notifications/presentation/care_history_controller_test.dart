import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';
import 'package:life_os/shared/data_revision.dart';

class _FakeCareHistoryRepository implements CareHistoryRepository {
  List<CareHistoryDay> days;
  Object? getError;
  Object? editError;
  Completer<void>? editCompleter;
  int editCalls = 0;
  CareLogStatus? lastStatus;
  String? lastCareScheduleId;
  final List<({String from, String to})> getRangeCalls = [];

  /// Consumed in call order: each queued entry replaces one [getRange]
  /// call's [days]/[getError] result — used to hold one (or several) loads in
  /// flight so a test can assert on the controller's state mid-fetch, or
  /// resolve two concurrent loads out of order.
  final List<Future<List<CareHistoryDay>> Function()> getRangeOverrides = [];

  _FakeCareHistoryRepository({required this.days});

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async {
    getRangeCalls.add((from: from, to: to));
    if (getRangeOverrides.isNotEmpty) return getRangeOverrides.removeAt(0)();
    if (getError != null) throw getError!;
    return days;
  }

  @override
  Future<void> editSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
    DateTime? doneTime,
  }) async {
    editCalls++;
    lastStatus = status;
    lastCareScheduleId = careScheduleId;
    if (editCompleter != null) await editCompleter!.future;
    if (editError != null) throw editError!;
  }
}

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  CareTodayStatus status = CareTodayStatus.pending,
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

CareHistoryController _controller({
  CareHistoryRepository? repository,
  int spanDays = 7,
  DateTime Function() clock = DateTime.now,
  DataRevision? dataRevision,
}) {
  final repo = repository ?? _FakeCareHistoryRepository(days: const []);
  return CareHistoryController(
    GetCareHistory(repo),
    EditCareSlot(repo),
    dataRevision ?? DataRevision(),
    spanDays: spanDays,
    clock: clock,
  );
}

void main() {
  group('CareHistoryController.load', () {
    test('uses the self-held spanDays and injected clock to compute the '
        'range (not a caller-supplied from/to)', () async {
      final repository = _FakeCareHistoryRepository(days: const []);
      final controller = _controller(
        repository: repository,
        spanDays: 30,
        clock: () => DateTime(2026, 7, 22),
      );

      await controller.load('token-123');

      expect(
        repository.getRangeCalls,
        [(from: '2026-06-23', to: '2026-07-22')],
      );
    });

    test('populates days and sets loaded on success', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        clock: () => DateTime(2026, 7, 22),
      );

      await controller.load('token-123');

      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days, hasLength(1));
      expect(controller.days.single.slots, [_slot()]);
    });

    test('a CareReauthRequired routes to reauth', () async {
      final repository = _FakeCareHistoryRepository(days: const [])
        ..getError = const CareReauthRequired();
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareHistoryLoadStatus.reauth);
    });

    test('a CareRequestFailed routes to error and holds it', () async {
      final repository = _FakeCareHistoryRepository(days: const [])
        ..getError = const CareRequestFailed();
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareHistoryLoadStatus.error);
      expect(controller.error, isA<CareRequestFailed>());
    });

    test('a reload keeps the previous days visible while in flight (no '
        'blanking mid-load)', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      expect(controller.days, isNotEmpty);

      final completer = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.add(() => completer.future);
      final reload = controller.load('token-123');

      // Still loading, but the previously loaded days are still held.
      expect(controller.status, CareHistoryLoadStatus.loading);
      expect(controller.days, isNotEmpty);

      completer.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await reload;
    });
  });

  // Two independent drivers can load the same controller instance at once —
  // the user (the card's period selector -> setSpan) and
  // HealthScaffold._load's Future.wait, re-run on every DataRevision bump
  // (i.e. after every /care-history edit). Without a generation guard the
  // last response to *arrive* wins, so `days` can end up holding one
  // period's records while `spanDays` (and the selector) says another, with
  // status == loaded and nothing indicating the mismatch.
  group('CareHistoryController.load generation guard', () {
    test('a superseded load\'s late response is discarded — days stay those '
        'of the newest load', () async {
      final repository = _FakeCareHistoryRepository(days: const []);
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      final superseded = Completer<List<CareHistoryDay>>();
      final newest = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.addAll([
        () => superseded.future,
        () => newest.future,
      ]);

      final first = controller.load('token-123');
      final second = controller.setSpan('token-123', 90);

      // The newer (90-day) request comes back first.
      newest.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await second;
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days.single.date, '2026-07-22');

      // The superseded 7-day request lands afterwards with different data.
      superseded.complete([
        CareHistoryDay(date: '2026-07-16', slots: [_slot()]),
      ]);
      await first;

      expect(controller.spanDays, 90);
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days.single.date, '2026-07-22');
    });

    test('a superseded load\'s late failure does not flip the newest load\'s '
        'loaded status to error', () async {
      final repository = _FakeCareHistoryRepository(days: const []);
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      final superseded = Completer<List<CareHistoryDay>>();
      final newest = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.addAll([
        () => superseded.future,
        () => newest.future,
      ]);

      final first = controller.load('token-123');
      final second = controller.setSpan('token-123', 90);

      newest.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await second;

      superseded.completeError(const CareRequestFailed());
      await first;

      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.error, isNull);
    });

    test('a superseded load does not overwrite the range a later edit '
        'quietly re-fetches', () async {
      final repository = _FakeCareHistoryRepository(days: const []);
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      final superseded = Completer<List<CareHistoryDay>>();
      final newest = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.addAll([
        () => superseded.future,
        () => newest.future,
      ]);

      final first = controller.load('token-123');
      final second = controller.setSpan('token-123', 90);
      newest.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await second;
      superseded.complete([
        CareHistoryDay(date: '2026-07-16', slots: [_slot()]),
      ]);
      await first;

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      // The 90-day range that is actually on screen, not the superseded
      // 7-day one.
      expect(
        repository.getRangeCalls.last,
        (from: '2026-04-24', to: '2026-07-22'),
      );
    });

    // A failed edit must supersede an in-flight load too, symmetrically with
    // the successful one — otherwise that load lands afterwards and settles
    // the status itself, overwriting the failure. For a reauth that means the
    // sign-in-again exit is replaced by `loaded`, which the screen reads as
    // "the edit went through" and reports with the success message: a record
    // that never saved, shown as saved.
    test('a reauth-failed edit supersedes an in-flight load, so the landing '
        'load cannot overwrite the reauth exit', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');

      // A period switch whose GET is still in flight — the screen doesn't
      // blank during one, so its tiles stay tappable.
      final inFlight = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.add(() => inFlight.future);
      final switching = controller.setSpan('token-123', 30);

      repository.editError = CareReauthRequired();
      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );
      expect(controller.status, CareHistoryLoadStatus.reauth);

      inFlight.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await switching;

      expect(controller.status, CareHistoryLoadStatus.reauth);
    });

    // The failed-PUT branch repairs a superseded period switch with a second
    // fetch. `editing` — this method's re-entrancy guard — must stay held
    // across that repair: released early, a second edit starts mid-repair and
    // clears `editError` on entry, so the caller awaiting the FIRST edit sees
    // no error at all and reports a PUT that failed as saved.
    test('a failed edit holds the re-entrancy guard across its repair fetch, '
        'so a second edit cannot clear the first one\'s editError', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');

      // A period switch left in flight, so the failed edit below has a
      // superseded load to repair.
      final switching = Completer<List<CareHistoryDay>>();
      final repair = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.addAll([
        () => switching.future,
        () => repair.future,
      ]);
      final switched = controller.setSpan('token-123', 30);

      repository.editError = const CareRequestFailed();
      final firstEdit = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );
      // Let the PUT reject and the repair fetch start.
      await Future<void>.delayed(Duration.zero);

      // The user taps another slot while that repair is still in flight.
      repository.editError = null;
      final secondEdit = controller.edit(
        'token-123',
        careScheduleId: 'sch-2',
        localDate: '2026-07-22',
        timeOfDay: '20:00',
        status: CareLogStatus.done,
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        repository.editCalls,
        1,
        reason: 'the second edit must be blocked while the first is repairing',
      );

      repair.complete(const []);
      await firstEdit;
      await secondEdit;

      // What the screen reads to pick its SnackBar.
      expect(controller.editError, isA<CareRequestFailed>());
      expect(controller.refreshError, isNull);
      switching.complete(const []);
      await switched;
    });

    test('a non-auth-failed edit that superseded an in-flight load settles '
        'the status itself (no permanently stuck spinner)', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');

      final inFlight = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.add(() => inFlight.future);
      final switching = controller.setSpan('token-123', 30);
      expect(controller.status, CareHistoryLoadStatus.loading);

      repository.editError = CareRequestFailed();
      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      // The superseded load will never settle this, so the failed edit must.
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.editError, isA<CareRequestFailed>());
      expect(controller.days.single.date, '2026-07-22');

      inFlight.complete(const []);
      await switching;
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days.single.date, '2026-07-22');
    });

    // Superseding the in-flight period switch is only half the job: the
    // switch's response is discarded, so `days` still holds the *previous*
    // period's records while `spanDays` (and the selector built from it)
    // already says the new one. Settling at `loaded` there makes the very
    // mismatch `_loadGeneration` exists to prevent permanent, with nothing
    // in flight and nothing on screen indicating it. Both edit-failure
    // branches must re-fetch the current span instead.
    test('a non-auth-failed edit re-fetches the current span, so days and '
        'spanDays never describe different periods', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-16', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');
      expect(controller.days.single.date, '2026-07-16');

      // A period switch whose GET is still in flight — the screen doesn't
      // blank during one, so its tiles stay tappable.
      final inFlight = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.add(() => inFlight.future);
      final switching = controller.setSpan('token-123', 30);

      // What the 30-day range holds, distinguishable from the 7-day one.
      repository.days = [
        CareHistoryDay(date: '2026-06-23', slots: [_slot()]),
      ];
      repository.editError = CareRequestFailed();
      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      // The edit failure is still reported (the re-fetch must not swallow it).
      expect(controller.editError, isA<CareRequestFailed>());
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.spanDays, 30);
      expect(
        repository.getRangeCalls.last,
        (from: '2026-06-23', to: '2026-07-22'),
      );
      expect(controller.days.single.date, '2026-06-23');

      // The superseded switch landing late must not undo the repair.
      inFlight.complete([
        CareHistoryDay(date: '2026-07-16', slots: [_slot()]),
      ]);
      await switching;
      expect(controller.spanDays, 30);
      expect(controller.days.single.date, '2026-06-23');
    });

    test('an edit whose follow-up refresh fails re-fetches the current span '
        'too, keeping the refresh error distinct from an edit failure',
        () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-16', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');

      final inFlight = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.add(() => inFlight.future);
      final switching = controller.setSpan('token-123', 30);

      // The edit's own follow-up refresh fails; the repair fetch after it
      // succeeds against the 30-day range.
      repository.getRangeOverrides.add(
        () => Future.error(const CareRequestFailed()),
      );
      repository.days = [
        CareHistoryDay(date: '2026-06-23', slots: [_slot()]),
      ];
      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(controller.editError, isNull);
      expect(controller.refreshError, isA<CareRequestFailed>());
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.spanDays, 30);
      expect(controller.days.single.date, '2026-06-23');

      inFlight.complete([
        CareHistoryDay(date: '2026-07-16', slots: [_slot()]),
      ]);
      await switching;
      expect(controller.days.single.date, '2026-06-23');
    });
  });

  group('CareHistoryController.setSpan', () {
    test('changes spanDays and reloads with the new range, keeping the '
        'previous days visible while in flight (no blanking on a period '
        'switch)', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(
        repository: repository,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');
      expect(repository.getRangeCalls, [(from: '2026-07-16', to: '2026-07-22')]);

      final completer = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.add(() => completer.future);
      final reload = controller.setSpan('token-123', 30);

      expect(controller.spanDays, 30);
      expect(controller.status, CareHistoryLoadStatus.loading);
      expect(controller.days, isNotEmpty);

      completer.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await reload;

      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(
        repository.getRangeCalls.last,
        (from: '2026-06-23', to: '2026-07-22'),
      );
    });
  });

  group('CareHistoryController.edit', () {
    test('edit succeeds then quietly reloads (status stays loaded '
        'throughout, never dropping to loading)', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(
            date: '2026-07-22',
            slots: [_slot(status: CareTodayStatus.pending)],
          ),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      final statusesDuringEdit = <CareHistoryLoadStatus>[];
      controller.addListener(() => statusesDuringEdit.add(controller.status));

      repository.days = [
        CareHistoryDay(
          date: '2026-07-22',
          slots: [_slot(status: CareTodayStatus.done)],
        ),
      ];

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(repository.editCalls, 1);
      expect(repository.lastStatus, CareLogStatus.done);
      expect(repository.lastCareScheduleId, 'sch-1');
      expect(controller.days.single.slots.single.status, CareTodayStatus.done);
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(
        statusesDuringEdit,
        isNot(contains(CareHistoryLoadStatus.loading)),
      );
    });

    test('an edit failure keeps the existing days and surfaces editError', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      )..editError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(controller.editError, isA<CareRequestFailed>());
      expect(controller.refreshError, isNull);
      expect(controller.days.single.slots, [_slot()]);
      expect(controller.status, CareHistoryLoadStatus.loaded);
    });

    test('an edit CareReauthRequired routes status to reauth', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      )..editError = const CareReauthRequired();
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(controller.status, CareHistoryLoadStatus.reauth);
    });

    test('FIX 2: a reload failure after a successful edit keeps the days '
        'and sets refreshError (not editError, not status=error) — the edit '
        'itself succeeded, only the follow-up refresh failed', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      // The edit PUT succeeds server-side, but the follow-up reload GET
      // fails with a non-auth error.
      repository.getError = const CareRequestFailed();

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(repository.editCalls, 1);
      expect(controller.editError, isNull);
      expect(controller.refreshError, isA<CareRequestFailed>());
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days.single.slots, [_slot()]);
    });

    test('FIX 2b: a reload CareReauthRequired after a successful edit still '
        'routes to reauth', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      repository.getError = const CareReauthRequired();

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(controller.status, CareHistoryLoadStatus.reauth);
    });

    // The screen doesn't blank during a period switch, so its tiles stay
    // tappable while that switch's GET is still in flight — only `editing`
    // guards an edit. Without a generation ticket of its own, the quiet
    // reload would ask for the last *committed* range (load only commits
    // its range once it wins) and could land under the in-flight switch's
    // older response, leaving `days` and `spanDays` describing different
    // periods with status == loaded and nothing indicating the mismatch.
    test('the quiet reload after a successful edit re-derives its range from '
        'the current spanDays and takes a generation ticket, so a period '
        'switch still in flight can neither send it to the old range nor '
        'land on top of its fresher result', () async {
      final repository = _FakeCareHistoryRepository(days: const []);
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');
      expect(
        repository.getRangeCalls,
        [(from: '2026-07-16', to: '2026-07-22')],
      );

      final spanGet = Completer<List<CareHistoryDay>>();
      final editGet = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.addAll([
        () => spanGet.future,
        () => editGet.future,
      ]);

      final spanLoad = controller.setSpan('token-123', 30);
      final edit = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );
      // Let the PUT settle so the quiet reload's GET is actually issued.
      await Future<void>.delayed(Duration.zero);

      expect(repository.getRangeCalls, hasLength(3));
      // The 30-day period now on screen, not the committed 7-day one.
      expect(
        repository.getRangeCalls.last,
        (from: '2026-06-23', to: '2026-07-22'),
      );

      // The edit's reload — issued later, so it wins — lands first...
      editGet.complete([
        CareHistoryDay(
          date: '2026-07-22',
          slots: [_slot(status: CareTodayStatus.done)],
        ),
      ]);
      await edit;

      // ...and the period switch's pre-edit response lands after it, and
      // must be discarded rather than reverting the just-edited slot.
      spanGet.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await spanLoad;

      expect(controller.spanDays, 30);
      expect(controller.days.single.slots.single.status, CareTodayStatus.done);
      // The reload superseded the period switch, so it also has to settle
      // the `loading` that switch left behind — otherwise the screen keeps
      // its thin progress indicator forever.
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.editError, isNull);
      expect(controller.refreshError, isNull);
    });

    test('a failed quiet reload that superseded an in-flight period switch '
        'still settles the status (refreshError, not a stuck loading state)',
        () async {
      final repository = _FakeCareHistoryRepository(days: [
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      final controller = _controller(
        repository: repository,
        spanDays: 7,
        clock: () => DateTime(2026, 7, 22),
      );
      await controller.load('token-123');

      final spanGet = Completer<List<CareHistoryDay>>();
      final editGet = Completer<List<CareHistoryDay>>();
      repository.getRangeOverrides.addAll([
        () => spanGet.future,
        () => editGet.future,
      ]);

      final spanLoad = controller.setSpan('token-123', 30);
      final edit = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );
      await Future<void>.delayed(Duration.zero);

      editGet.completeError(const CareRequestFailed());
      await edit;

      spanGet.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await spanLoad;

      expect(controller.editError, isNull);
      expect(controller.refreshError, isA<CareRequestFailed>());
      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days, hasLength(1));
    });

    test('re-entrancy: a second edit call is ignored while one is in flight', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      final completer = Completer<void>();
      repository.editCompleter = completer;
      final first = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );
      expect(controller.editing, isTrue);
      final second = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      completer.complete();
      await Future.wait([first, second]);

      expect(repository.editCalls, 1);
      expect(controller.editing, isFalse);
    });
  });

  group('CareHistoryController.edit bumps DataRevision (design §D)', () {
    test('a successful edit bumps the injected DataRevision exactly once',
        () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final dataRevision = DataRevision();
      final controller = _controller(
        repository: repository,
        dataRevision: dataRevision,
      );
      await controller.load('token-123');

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(dataRevision.revision, 1);
    });

    test('a successful edit bumps even if the follow-up refresh fails — '
        'the underlying record already changed server-side', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final dataRevision = DataRevision();
      final controller = _controller(
        repository: repository,
        dataRevision: dataRevision,
      );
      await controller.load('token-123');

      repository.getError = const CareRequestFailed();

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(dataRevision.revision, 1);
    });

    test('an edit PUT failure does not bump', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      )..editError = const CareRequestFailed();
      final dataRevision = DataRevision();
      final controller = _controller(
        repository: repository,
        dataRevision: dataRevision,
      );
      await controller.load('token-123');

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(dataRevision.revision, 0);
    });

    test('an edit PUT that requires reauth does not bump', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      )..editError = const CareReauthRequired();
      final dataRevision = DataRevision();
      final controller = _controller(
        repository: repository,
        dataRevision: dataRevision,
      );
      await controller.load('token-123');

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(dataRevision.revision, 0);
    });
  });
}
