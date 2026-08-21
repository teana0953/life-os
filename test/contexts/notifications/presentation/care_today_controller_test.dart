import 'dart:async';

import 'package:life_os/shared/screen_batch/section_outcome.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/care_today.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_today_controller.dart';

class _FakeCareTodayRepository implements CareTodayRepository {
  CareToday today;
  Object? getError;

  /// How many `getToday` calls succeed before [getError] starts being
  /// thrown. `0` (the default) fails every call; `1` lets the initial load
  /// succeed and fails the *reload* an edit/mark triggers afterwards.
  int getErrorAfterCalls = 0;
  Object? logError;
  Completer<void>? logCompleter;
  Completer<void>? getCompleter;
  int getCalls = 0;
  int logCalls = 0;
  CareLogStatus? lastStatus;
  String? lastCareScheduleId;

  _FakeCareTodayRepository({required this.today});

  @override
  Future<CareToday> getToday(String idToken) async {
    getCalls++;
    if (getCompleter != null) await getCompleter!.future;
    if (getError != null && getCalls > getErrorAfterCalls) throw getError!;
    return today;
  }

  @override
  Future<void> logSlot(
    String idToken, {
    required String careScheduleId,
    required String localDate,
    required String timeOfDay,
    required CareLogStatus status,
  }) async {
    logCalls++;
    lastStatus = status;
    lastCareScheduleId = careScheduleId;
    if (logCompleter != null) await logCompleter!.future;
    if (logError != null) throw logError!;
  }
}

class _FakeCareHistoryRepository implements CareHistoryRepository {
  Object? editError;
  Completer<void>? editCompleter;
  int editCalls = 0;
  CareLogStatus? lastStatus;
  DateTime? lastDoneTime;

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async => const [];

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
    lastDoneTime = doneTime;
    if (editCompleter != null) await editCompleter!.future;
    if (editError != null) throw editError!;
  }
}

CareTodaySlot _slot({
  String careScheduleId = 'sch-1',
  CareTodayStatus status = CareTodayStatus.pending,
  String timeOfDay = '08:00',
  String? doneTime,
}) => CareTodaySlot(
  careItemId: 'care-1',
  careScheduleId: careScheduleId,
  category: CareCategory.medication,
  title: 'Metformin',
  timeOfDay: timeOfDay,
  localDate: '2026-07-22',
  status: status,
  doneTime: doneTime,
  doseQuantity: 1,
);

CareTodayController _controller({
  CareTodayRepository? repository,
  CareHistoryRepository? historyRepository,
}) {
  final repo =
      repository ?? _FakeCareTodayRepository(today: const CareToday(date: '2026-07-22', slots: []));
  return CareTodayController(
    GetCareToday(repo),
    MarkCareDone(repo),
    MarkCareSkipped(repo),
    EditCareSlot(historyRepository ?? _FakeCareHistoryRepository()),
  );
}

void main() {

  group('CareTodayController.applyBatchSection', () {
    CareToday today() => CareToday(
      date: '2026-07-22',
      slots: [_slot(status: CareTodayStatus.overdue)],
    );

    test('ok lands the identical state load() lands for the same payload', () async {
      final viaLoad = _controller(
        repository: _FakeCareTodayRepository(today: today()),
      );
      await viaLoad.load('token');

      final viaBatch = _controller();
      viaBatch.applyBatchSection(SectionOk(today()));

      expect(viaBatch.status, viaLoad.status);
      expect(viaBatch.error, viaLoad.error);
      expect(viaBatch.date, viaLoad.date);
      expect(
        viaBatch.slots.map((s) => s.careScheduleId),
        viaLoad.slots.map((s) => s.careScheduleId),
      );
      expect(viaBatch.focusSlot?.timeOfDay, viaLoad.focusSlot?.timeOfDay);
    });

    // The card renders a setup prompt for an empty checklist, so a failed
    // section must reach `error`, never "you have no reminders".
    test('unavailable reaches the fetch-failed state, not an empty checklist', () {
      final controller = _controller();

      controller.applyBatchSection(const SectionUnavailable<CareToday>());

      expect(controller.status, CareTodayLoadStatus.error);
      expect(controller.error, isNotNull);
      expect(controller.slots, isEmpty);
    });

    test('reauth reaches the re-auth state', () {
      final controller = _controller();

      controller.applyBatchSection(const SectionReauth<CareToday>());

      expect(controller.status, CareTodayLoadStatus.reauth);
    });
  });


  group('deriveFocusSlot', () {
    test('picks the earliest overdue slot over any pending slot', () {
      final slots = [
        _slot(careScheduleId: 'a', status: CareTodayStatus.pending, timeOfDay: '07:00'),
        _slot(careScheduleId: 'b', status: CareTodayStatus.overdue, timeOfDay: '09:00'),
        _slot(careScheduleId: 'c', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
      ];

      final focus = deriveFocusSlot(slots);

      expect(focus?.careScheduleId, 'c');
    });

    test('picks the earliest pending slot when none is overdue', () {
      final slots = [
        _slot(careScheduleId: 'a', status: CareTodayStatus.pending, timeOfDay: '12:00'),
        _slot(careScheduleId: 'b', status: CareTodayStatus.pending, timeOfDay: '09:00'),
        _slot(careScheduleId: 'c', status: CareTodayStatus.done, timeOfDay: '07:00'),
      ];

      final focus = deriveFocusSlot(slots);

      expect(focus?.careScheduleId, 'b');
    });

    test('is null when nothing is pending or overdue', () {
      final slots = [
        _slot(status: CareTodayStatus.done),
        _slot(careScheduleId: 'b', status: CareTodayStatus.skipped),
      ];

      expect(deriveFocusSlot(slots), isNull);
    });
  });

  group('deriveGroups', () {
    test('groups by status and orders each group by timeOfDay, excluding '
        'the focus slot from its group (FIX 1)', () {
      final slots = [
        _slot(careScheduleId: 'later-2', status: CareTodayStatus.pending, timeOfDay: '20:00'),
        _slot(careScheduleId: 'later-1', status: CareTodayStatus.pending, timeOfDay: '10:00'),
        _slot(careScheduleId: 'overdue-2', status: CareTodayStatus.overdue, timeOfDay: '09:00'),
        // Earliest overdue — this becomes the focus slot, so it must not
        // also appear in groups.overdue (FIX 1: no double render).
        _slot(careScheduleId: 'overdue-1', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
        _slot(careScheduleId: 'done-1', status: CareTodayStatus.done, timeOfDay: '06:00'),
        _slot(careScheduleId: 'skipped-1', status: CareTodayStatus.skipped, timeOfDay: '07:00'),
        _slot(careScheduleId: 'missed-1', status: CareTodayStatus.missed, timeOfDay: '05:00'),
      ];

      final groups = deriveGroups(slots);

      expect(groups.overdue.map((s) => s.careScheduleId), ['overdue-2']);
      expect(
        groups.later.map((s) => s.careScheduleId),
        ['later-1', 'later-2'],
      );
      expect(
        groups.done.map((s) => s.careScheduleId),
        ['missed-1', 'done-1', 'skipped-1'],
      );
    });

    test('excludes the sole overdue slot from groups.overdue when it is the '
        'focus (FIX 1: no double render)', () {
      final slots = [
        _slot(careScheduleId: 'only-overdue', status: CareTodayStatus.overdue, timeOfDay: '08:00'),
      ];

      final groups = deriveGroups(slots);

      expect(groups.overdue, isEmpty);
    });

    test('excludes the sole pending slot from groups.later when it is the '
        'focus (FIX 1: no double render)', () {
      final slots = [
        _slot(careScheduleId: 'only-pending', status: CareTodayStatus.pending, timeOfDay: '08:00'),
      ];

      final groups = deriveGroups(slots);

      expect(groups.later, isEmpty);
    });
  });

  group('CareTodayController.load', () {
    test('populates date/slots and sets loaded on success', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareTodayLoadStatus.loaded);
      expect(controller.date, '2026-07-22');
      expect(controller.slots, [_slot()]);
    });

    test('a CareReauthRequired routes to reauth', () async {
      final repository = _FakeCareTodayRepository(
        today: const CareToday(date: '2026-07-22', slots: []),
      )..getError = const CareReauthRequired();
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareTodayLoadStatus.reauth);
    });

    test('a CareRequestFailed routes to error and holds it', () async {
      final repository = _FakeCareTodayRepository(
        today: const CareToday(date: '2026-07-22', slots: []),
      )..getError = const CareRequestFailed();
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareTodayLoadStatus.error);
      expect(controller.error, isA<CareRequestFailed>());
    });
  });

  group('CareTodayController.reloadQuietly', () {
    test('re-fetches Today without ever dropping to the loading state — the '
        'list the user is looking at must not be replaced by a spinner', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      final statuses = <CareTodayLoadStatus>[];
      controller.addListener(() => statuses.add(controller.status));
      repository.today = CareToday(
        date: '2026-07-23',
        slots: [_slot(careScheduleId: 'sch-2')],
      );

      await controller.reloadQuietly('token-123');

      expect(controller.date, '2026-07-23');
      expect(controller.slots.single.careScheduleId, 'sch-2');
      expect(controller.status, CareTodayLoadStatus.loaded);
      expect(statuses, isNot(contains(CareTodayLoadStatus.loading)));
    });

    test('a successful quiet reload recovers from an error state — the screen '
        'renders from status, so leaving it on error hides the list it just '
        'fetched', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      repository.getError = const CareRequestFailed();
      await controller.load('token-123');
      expect(controller.status, CareTodayLoadStatus.error);

      repository.getError = null;
      repository.today = CareToday(
        date: '2026-07-23',
        slots: [_slot(careScheduleId: 'sch-2')],
      );
      await controller.reloadQuietly('token-123');

      expect(controller.status, CareTodayLoadStatus.loaded);
      expect(controller.slots.single.careScheduleId, 'sch-2');
    });

    test('a failed quiet reload that had swallowed the first load surfaces the '
        'error instead of leaving the screen spinning forever', () async {
      // The screen's own load() can be skipped by the shared in-flight guard
      // when a hand-over reload starts inside its `await idToken()` window.
      // Staying quiet then means staying on the initial `loading` — a spinner
      // with no retry button and no way out. `error` at least offers one.
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      expect(controller.status, CareTodayLoadStatus.loading);
      repository.getError = const CareRequestFailed();

      await controller.reloadQuietly('token-123');

      expect(controller.status, CareTodayLoadStatus.error);
    });

    test('a failed quiet reload keeps the rendered list and stays loaded — a '
        'background reload must never swap a good list for the error screen', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      repository.getError = const CareRequestFailed();

      await controller.reloadQuietly('token-123');

      expect(controller.status, CareTodayLoadStatus.loaded);
      expect(controller.slots, [_slot()]);
      expect(controller.date, '2026-07-22');
    });

    test('a CareReauthRequired during a quiet reload still routes to reauth', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      repository.getError = const CareReauthRequired();

      await controller.reloadQuietly('token-123');

      expect(controller.status, CareTodayLoadStatus.reauth);
    });

    test('a second quiet reload while one is in flight is ignored (repeated '
        'notification taps must not race two GETs)', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      final getsAfterLoad = repository.getCalls;

      final completer = Completer<void>();
      repository.getCompleter = completer;
      final first = controller.reloadQuietly('token-123');
      final second = controller.reloadQuietly('token-123');
      completer.complete();
      await Future.wait([first, second]);

      expect(repository.getCalls, getsAfterLoad + 1);
    });

    test('a quiet reload while the initial load is still in flight is ignored', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);

      final completer = Completer<void>();
      repository.getCompleter = completer;
      final load = controller.load('token-123');
      final reload = controller.reloadQuietly('token-123');
      completer.complete();
      await Future.wait([load, reload]);

      expect(repository.getCalls, 1);
      expect(controller.status, CareTodayLoadStatus.loaded);
    });
  });

  group('CareTodayController marks', () {
    test('markDone logs "done" then reloads (design D2 — status stays loaded '
        'throughout, never dropping to loading)', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot(status: CareTodayStatus.pending)]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      final statusesDuringMark = <CareTodayLoadStatus>[];
      controller.addListener(() => statusesDuringMark.add(controller.status));

      // After the mark, the fake repo returns the slot as done.
      repository.today = CareToday(
        date: '2026-07-22',
        slots: [_slot(status: CareTodayStatus.done, doneTime: '08:05')],
      );

      await controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(repository.logCalls, 1);
      expect(repository.lastStatus, CareLogStatus.done);
      expect(repository.lastCareScheduleId, 'sch-1');
      expect(controller.slots.single.status, CareTodayStatus.done);
      expect(controller.status, CareTodayLoadStatus.loaded);
      // Never dropped to the top-level loading state during the mark.
      expect(statusesDuringMark, isNot(contains(CareTodayLoadStatus.loading)));
    });

    test('markSkipped logs "skipped"', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.markSkipped(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(repository.lastStatus, CareLogStatus.skipped);
    });

    test('a mark failure keeps the existing slots and surfaces markError', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      )..logError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(controller.markError, isA<CareRequestFailed>());
      expect(controller.slots, [_slot()]);
      expect(controller.status, CareTodayLoadStatus.loaded);
    });

    test('a reload failure after a successful mark keeps the list and sets '
        'markError, not status=error (FIX 2)', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      // The mark POST succeeds server-side, but the follow-up reload GET
      // fails with a non-auth error.
      repository.getError = const CareRequestFailed();

      await controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(repository.logCalls, 1);
      expect(controller.markError, isA<CareRequestFailed>());
      expect(controller.status, CareTodayLoadStatus.loaded);
      expect(controller.slots, [_slot()]);
    });

    test('a mark CareReauthRequired routes status to reauth', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      )..logError = const CareReauthRequired();
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(controller.status, CareTodayLoadStatus.reauth);
    });

    test('re-entrancy: a second mark call is ignored while one is in flight', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      final completer = Completer<void>();
      repository.logCompleter = completer;
      final first = controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );
      expect(controller.marking, isTrue);
      final second = controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      completer.complete();
      await Future.wait([first, second]);

      expect(repository.logCalls, 1);
      expect(controller.marking, isFalse);
    });

    test('a mark dropped by the re-entrancy gate does not carry over a '
        'stale markError from an earlier, already-settled action — the gate '
        'used to fire before markError was cleared, so an action that was '
        'never attempted could pop up the last failure', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      // Simulate another mark already being in flight, with a stale error
      // left over from an earlier, unrelated failure.
      controller.marking = true;
      controller.markError = const CareRequestFailed();

      await controller.markDone(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(controller.markError, isNull);
      expect(repository.logCalls, 0);
    });

    test('markingAction identifies only the slot mid-mark, and clears once '
        'it settles (FIX 8: per-row marking feedback)', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(
          date: '2026-07-22',
          slots: [
            _slot(careScheduleId: 'sch-1', timeOfDay: '08:00'),
            _slot(careScheduleId: 'sch-2', timeOfDay: '09:00'),
          ],
        ),
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      final slot1 = controller.slots[0];
      final slot2 = controller.slots[1];

      final completer = Completer<void>();
      repository.logCompleter = completer;
      final mark = controller.markSkipped(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
      );

      expect(controller.markingAction(slot1), CareLogStatus.skipped);
      expect(controller.markingAction(slot2), isNull);

      completer.complete();
      await mark;

      expect(controller.markingAction(slot1), isNull);
      expect(controller.markingAction(slot2), isNull);
    });
  });

  group('CareTodayController.edit', () {
    test('a successful edit quietly reloads — status stays loaded '
        'throughout', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot(status: CareTodayStatus.done)]),
      );
      final historyRepository = _FakeCareHistoryRepository();
      final controller = _controller(repository: repository, historyRepository: historyRepository);
      await controller.load('token-123');

      final statuses = <CareTodayLoadStatus>[];
      controller.addListener(() => statuses.add(controller.status));
      repository.today = CareToday(
        date: '2026-07-22',
        slots: [_slot(status: CareTodayStatus.done, timeOfDay: '09:00')],
      );

      final outcome = await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
        doneTime: DateTime.utc(2026, 7, 22, 1, 0),
      );

      expect(outcome, CareTodayEditOutcome.saved);
      expect(historyRepository.editCalls, 1);
      expect(historyRepository.lastStatus, CareLogStatus.done);
      expect(historyRepository.lastDoneTime, DateTime.utc(2026, 7, 22, 1, 0));
      expect(controller.slots.single.timeOfDay, '09:00');
      expect(controller.status, CareTodayLoadStatus.loaded);
      expect(statuses, isNot(contains(CareTodayLoadStatus.loading)));
    });

    test('a skipped status does not forward doneTime, even when given', () async {
      final historyRepository = _FakeCareHistoryRepository();
      final controller = _controller(historyRepository: historyRepository);
      await controller.load('token-123');

      await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.skipped,
        doneTime: DateTime.utc(2026, 7, 22, 1, 0),
      );

      expect(historyRepository.lastStatus, CareLogStatus.skipped);
      expect(historyRepository.lastDoneTime, isNull);
    });

    test('an edit failure keeps the existing slots and surfaces markError', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final historyRepository = _FakeCareHistoryRepository()
        ..editError = const CareRequestFailed();
      final controller = _controller(repository: repository, historyRepository: historyRepository);
      await controller.load('token-123');

      final outcome = await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(outcome, CareTodayEditOutcome.failed);
      expect(controller.markError, isA<CareRequestFailed>());
      expect(controller.slots, [_slot()]);
      expect(controller.status, CareTodayLoadStatus.loaded);
    });

    test('an edit CareReauthRequired routes status to reauth', () async {
      final historyRepository = _FakeCareHistoryRepository()
        ..editError = const CareReauthRequired();
      final controller = _controller(historyRepository: historyRepository);
      await controller.load('token-123');

      final outcome = await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(outcome, CareTodayEditOutcome.reauth);
      expect(controller.status, CareTodayLoadStatus.reauth);
    });

    test('a second edit call while one is in flight is dropped and reports '
        'skipped, not silently discarded', () async {
      final historyRepository = _FakeCareHistoryRepository();
      final controller = _controller(historyRepository: historyRepository);
      await controller.load('token-123');

      final completer = Completer<void>();
      historyRepository.editCompleter = completer;
      final first = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );
      expect(controller.marking, isTrue);
      final second = controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      completer.complete();
      final results = await Future.wait([first, second]);

      expect(results[1], CareTodayEditOutcome.skipped);
      expect(historyRepository.editCalls, 1);
    });

    test('a reload failure after a successful edit keeps the list and reports '
        'refreshFailed — the PUT already landed, so the caller must not tell '
        'the user their correction was lost', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final historyRepository = _FakeCareHistoryRepository();
      final controller = _controller(repository: repository, historyRepository: historyRepository);
      await controller.load('token-123');

      repository.getError = const CareRequestFailed();
      repository.getErrorAfterCalls = 1;

      final outcome = await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(historyRepository.editCalls, 1);
      expect(outcome, CareTodayEditOutcome.refreshFailed);
      expect(controller.markError, isA<CareRequestFailed>());
      expect(controller.slots, [_slot()]);
      expect(controller.status, CareTodayLoadStatus.loaded);
    });

    test('a CareReauthRequired from the reload that follows a successful edit '
        'routes to reauth', () async {
      final repository = _FakeCareTodayRepository(
        today: CareToday(date: '2026-07-22', slots: [_slot()]),
      );
      final historyRepository = _FakeCareHistoryRepository();
      final controller = _controller(repository: repository, historyRepository: historyRepository);
      await controller.load('token-123');

      repository.getError = const CareReauthRequired();
      repository.getErrorAfterCalls = 1;

      final outcome = await controller.edit(
        'token-123',
        careScheduleId: 'sch-1',
        localDate: '2026-07-22',
        timeOfDay: '08:00',
        status: CareLogStatus.done,
      );

      expect(historyRepository.editCalls, 1);
      expect(outcome, CareTodayEditOutcome.reauth);
      expect(controller.status, CareTodayLoadStatus.reauth);
      expect(controller.markError, isNull);
    });
  });
}
