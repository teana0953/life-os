import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/edit_care_slot.dart';
import 'package:life_os/contexts/notifications/application/get_care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_history.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/domain/care_today.dart';
import 'package:life_os/contexts/notifications/presentation/care_history_controller.dart';

class _FakeCareHistoryRepository implements CareHistoryRepository {
  List<CareHistoryDay> days;
  Object? getError;
  Object? editError;
  Completer<void>? editCompleter;
  int editCalls = 0;
  CareLogStatus? lastStatus;
  String? lastCareScheduleId;

  /// When set, the next [getRange] call defers to this instead of returning
  /// [days]/[getError] immediately — used to hold a load in flight so a test
  /// can assert on the controller's state mid-fetch.
  Future<List<CareHistoryDay>> Function()? getRangeOverride;

  _FakeCareHistoryRepository({required this.days});

  @override
  Future<List<CareHistoryDay>> getRange(
    String idToken,
    String from,
    String to,
  ) async {
    final override = getRangeOverride;
    if (override != null) {
      getRangeOverride = null;
      return override();
    }
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

CareHistoryController _controller({CareHistoryRepository? repository}) {
  final repo = repository ?? _FakeCareHistoryRepository(days: const []);
  return CareHistoryController(GetCareHistory(repo), EditCareSlot(repo));
}

void main() {
  group('CareHistoryController.load', () {
    test('populates days and sets loaded on success', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);

      await controller.load('token-123', '2026-07-16', '2026-07-22');

      expect(controller.status, CareHistoryLoadStatus.loaded);
      expect(controller.days, hasLength(1));
      expect(controller.days.single.slots, [_slot()]);
    });

    test('a CareReauthRequired routes to reauth', () async {
      final repository = _FakeCareHistoryRepository(days: const [])
        ..getError = const CareReauthRequired();
      final controller = _controller(repository: repository);

      await controller.load('token-123', '2026-07-16', '2026-07-22');

      expect(controller.status, CareHistoryLoadStatus.reauth);
    });

    test('a CareRequestFailed routes to error and holds it', () async {
      final repository = _FakeCareHistoryRepository(days: const [])
        ..getError = const CareRequestFailed();
      final controller = _controller(repository: repository);

      await controller.load('token-123', '2026-07-16', '2026-07-22');

      expect(controller.status, CareHistoryLoadStatus.error);
      expect(controller.error, isA<CareRequestFailed>());
    });

    test('a reload keeps the previous days visible while in flight (no '
        'blanking on a span switch)', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123', '2026-07-16', '2026-07-22');
      expect(controller.days, isNotEmpty);

      final completer = Completer<List<CareHistoryDay>>();
      repository.getRangeOverride = () => completer.future;
      final reload = controller.load('token-123', '2026-06-23', '2026-07-22');

      // Still loading, but the previously loaded days are still held.
      expect(controller.status, CareHistoryLoadStatus.loading);
      expect(controller.days, isNotEmpty);

      completer.complete([
        CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
      ]);
      await reload;
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
      await controller.load('token-123', '2026-07-16', '2026-07-22');

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
      await controller.load('token-123', '2026-07-16', '2026-07-22');

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
      await controller.load('token-123', '2026-07-16', '2026-07-22');

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
      await controller.load('token-123', '2026-07-16', '2026-07-22');

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
      await controller.load('token-123', '2026-07-16', '2026-07-22');

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

    test('re-entrancy: a second edit call is ignored while one is in flight', () async {
      final repository = _FakeCareHistoryRepository(
        days: [
          CareHistoryDay(date: '2026-07-22', slots: [_slot()]),
        ],
      );
      final controller = _controller(repository: repository);
      await controller.load('token-123', '2026-07-16', '2026-07-22');

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
}
