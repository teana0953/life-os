import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/care_items.dart';
import 'package:life_os/contexts/notifications/domain/care_item.dart';
import 'package:life_os/contexts/notifications/presentation/care_items_controller.dart';

class _FakeCareItemRepository implements CareItemRepository {
  List<CareItem> items;
  Object? listError;
  Object? mutateError;
  Completer<void>? mutateCompleter;
  int createCalls = 0;
  int deleteCalls = 0;
  CareItemUpdate? lastUpdate;
  String? lastUpdateId;

  _FakeCareItemRepository({this.items = const []});

  @override
  Future<List<CareItem>> list(String idToken) async {
    if (listError != null) throw listError!;
    return items;
  }

  @override
  Future<CareItem> create(String idToken, CareItemDraft draft) async {
    createCalls++;
    if (mutateCompleter != null) await mutateCompleter!.future;
    if (mutateError != null) throw mutateError!;
    return CareItem(
      id: 'care-new',
      category: draft.category,
      title: draft.title,
      note: draft.note,
      dose: draft.dose,
      stock: draft.stock,
      stockAlert: draft.stockAlert,
      schedules: draft.schedules,
    );
  }

  @override
  Future<CareItem> update(
    String idToken,
    String id,
    CareItemUpdate update,
  ) async {
    lastUpdateId = id;
    lastUpdate = update;
    if (mutateCompleter != null) await mutateCompleter!.future;
    if (mutateError != null) throw mutateError!;
    return CareItem(
      id: id,
      category: update.category,
      title: update.title,
      note: update.note,
      dose: update.dose,
      stock: update.stock,
      stockAlert: update.stockAlert,
      schedules: update.schedules,
    );
  }

  @override
  Future<void> delete(String idToken, String id) async {
    deleteCalls++;
    if (mutateCompleter != null) return mutateCompleter!.future;
    if (mutateError != null) throw mutateError!;
  }
}

CareItemsController _controller({CareItemRepository? repository}) {
  final repo = repository ?? _FakeCareItemRepository();
  return CareItemsController(
    ListCareItems(repo),
    CreateCareItem(repo),
    UpdateCareItem(repo),
    DeleteCareItem(repo),
  );
}

final _item = CareItem(
  id: 'care-1',
  category: CareCategory.medication,
  title: 'Metformin',
  schedules: [
    CareSchedule(
      id: 'sch-1',
      timeOfDay: '08:00',
      repeatDays: const [1, 3, 5],
      weekInterval: 1,
      startDate: DateTime(2026, 7, 20),
      doseQuantity: 1,
      nagIntervalMinutes: 0,
      enabled: true,
    ),
  ],
);

CareItemDraft get _draft => CareItemDraft(
  category: CareCategory.rehab,
  title: 'Stretching',
  schedules: [
    CareSchedule(
      timeOfDay: '09:00',
      repeatDays: const [],
      weekInterval: 1,
      startDate: DateTime(2026, 7, 21),
      doseQuantity: 1,
      nagIntervalMinutes: 0,
      enabled: true,
    ),
  ],
);

void main() {
  group('CareItemsController.load', () {
    test('populates items and sets loaded on success', () async {
      final repository = _FakeCareItemRepository(items: [_item]);
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareItemsStatus.loaded);
      expect(controller.items, [_item]);
    });

    test('an empty list still resolves to loaded (empty state)', () async {
      final controller = _controller();

      await controller.load('token-123');

      expect(controller.status, CareItemsStatus.loaded);
      expect(controller.items, isEmpty);
    });

    test('a CareReauthRequired routes to reauth', () async {
      final repository = _FakeCareItemRepository()
        ..listError = const CareReauthRequired();
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareItemsStatus.reauth);
    });

    test('a CareRequestFailed routes to error and holds it', () async {
      final repository = _FakeCareItemRepository()
        ..listError = const CareRequestFailed();
      final controller = _controller(repository: repository);

      await controller.load('token-123');

      expect(controller.status, CareItemsStatus.error);
      expect(controller.error, isA<CareRequestFailed>());
    });

    test('clears a stale mutationError so an old banner does not linger', () async {
      final repository = _FakeCareItemRepository(items: [_item])
        ..mutateError = const CareRequestFailed();
      final controller = _controller(repository: repository);
      await controller.load('token-123');
      await controller.delete('token-123', 'care-1');
      expect(controller.mutationError, isNotNull);

      repository.mutateError = null;
      await controller.load('token-123');

      expect(controller.mutationError, isNull);
    });
  });

  group('CareItemsController mutations', () {
    test('create calls the repository then reloads the list', () async {
      final repository = _FakeCareItemRepository(items: [_item]);
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.create('token-123', _draft);

      expect(repository.createCalls, 1);
      expect(controller.items, [_item]);
      expect(controller.status, CareItemsStatus.loaded);
    });

    test('update calls the repository with the item id then reloads', () async {
      final repository = _FakeCareItemRepository(items: [_item]);
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.update(
        'token-123',
        'care-1',
        CareItemUpdate(
          category: CareCategory.medication,
          title: 'Metformin XR',
          schedules: _item.schedules,
        ),
      );

      expect(repository.lastUpdateId, 'care-1');
      expect(repository.lastUpdate!.title, 'Metformin XR');
    });

    test('delete calls the repository then reloads the list', () async {
      final repository = _FakeCareItemRepository(items: [_item]);
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.delete('token-123', 'care-1');

      expect(repository.deleteCalls, 1);
    });

    test(
      'a mutation failure surfaces the typed error and keeps the existing '
      'list',
      () async {
        final repository = _FakeCareItemRepository(items: [_item])
          ..mutateError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        await controller.delete('token-123', 'care-1');

        expect(controller.mutationError, isA<CareRequestFailed>());
        expect(controller.items, [_item]);
        expect(controller.status, CareItemsStatus.loaded);
      },
    );

    test('a mutation CareReauthRequired routes status to reauth', () async {
      final repository = _FakeCareItemRepository(items: [_item])
        ..mutateError = const CareReauthRequired();
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      await controller.delete('token-123', 'care-1');

      expect(controller.status, CareItemsStatus.reauth);
    });

    test(
      'a mutation that succeeds but whose reload fails surfaces the reload '
      'failure as the load-level error state (no mutationError)',
      () async {
        final repository = _FakeCareItemRepository(items: [_item]);
        final controller = _controller(repository: repository);
        await controller.load('token-123');

        repository.listError = const CareRequestFailed();

        await controller.delete('token-123', 'care-1');

        expect(repository.deleteCalls, 1);
        expect(controller.mutationError, isNull);
        expect(controller.status, CareItemsStatus.error);
        expect(controller.error, isA<CareRequestFailed>());
      },
    );

    test(
      'clearMutationError clears a stale error without touching the list',
      () async {
        final repository = _FakeCareItemRepository(items: [_item])
          ..mutateError = const CareRequestFailed();
        final controller = _controller(repository: repository);
        await controller.load('token-123');
        await controller.delete('token-123', 'care-1');
        expect(controller.mutationError, isNotNull);

        controller.clearMutationError();

        expect(controller.mutationError, isNull);
        expect(controller.items, [_item]);
      },
    );

    test('re-entrancy: a second mutation call is ignored while one is in flight', () async {
      final repository = _FakeCareItemRepository(items: [_item]);
      final controller = _controller(repository: repository);
      await controller.load('token-123');

      final completer = Completer<void>();
      repository.mutateCompleter = completer;
      final first = controller.delete('token-123', 'care-1');
      expect(controller.mutating, isTrue);
      final second = controller.delete('token-123', 'care-1');

      completer.complete();
      await Future.wait([first, second]);

      expect(repository.deleteCalls, 1);
      expect(controller.mutating, isFalse);
    });
  });
}
