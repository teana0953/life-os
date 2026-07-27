import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/shared/pwa/pending_deep_link.dart';
import 'package:life_os/shared/pwa/pending_deep_link_controller.dart';

/// A fake [PendingDeepLinkStore]: [take] pops a queued result (`null` when
/// empty, matching "nothing pending"). [holdUntil], when set, makes [take]
/// await it before resolving — lets the concurrency test hold a read open
/// while a second `check()` overlaps.
class _FakeStore implements PendingDeepLinkStore {
  final List<PendingDeepLink?> _queue = [];
  int takeCallCount = 0;
  Completer<void>? holdUntil;
  final _signals = StreamController<void>.broadcast();

  void enqueue(PendingDeepLink? value) => _queue.add(value);

  @override
  Future<PendingDeepLink?> take() async {
    takeCallCount++;
    if (holdUntil != null) await holdUntil!.future;
    return _queue.isEmpty ? null : _queue.removeAt(0);
  }

  @override
  Stream<void> get handoverSignals => _signals.stream;

  void emitSignal() => _signals.add(null);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fixedNow = DateTime(2026, 7, 27, 12, 0, 0);

  late _FakeStore store;
  late bool canNavigateValue;
  late String currentPathValue;
  late List<String> navigated;
  late int refreshes;

  PendingDeepLinkController buildController() => PendingDeepLinkController(
    store,
    now: () => fixedNow,
    canNavigate: () => canNavigateValue,
    currentPath: () => currentPathValue,
    navigate: (path) => navigated.add(path),
    refresh: () => refreshes++,
  );

  setUp(() {
    store = _FakeStore();
    canNavigateValue = true;
    currentPathValue = '/';
    navigated = [];
    refreshes = 0;
  });

  group('check', () {
    test('a fresh pending path within the TTL navigates to that path', () async {
      store.enqueue(
        PendingDeepLink(
          path: '/care-today',
          savedAt: fixedNow.subtract(const Duration(minutes: 1)),
        ),
      );

      await buildController().check();

      expect(navigated, ['/care-today']);
      expect(refreshes, 0);
    });

    test(
      'a pending path older than the TTL does not navigate but was still '
      'taken from the store',
      () async {
        store.enqueue(
          PendingDeepLink(
            path: '/care-today',
            savedAt: fixedNow.subtract(const Duration(minutes: 6)),
          ),
        );

        await buildController().check();

        expect(navigated, isEmpty);
        expect(store.takeCallCount, 1);
      },
    );

    test('canNavigate() false leaves the store entirely unread', () async {
      canNavigateValue = false;
      store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));

      await buildController().check();

      expect(navigated, isEmpty);
      expect(store.takeCallCount, 0);
    });

    for (final loc in ['/splash', '/auth-error', '/login', '/register']) {
      test('currentPath() on $loc leaves the store unread', () async {
        currentPathValue = loc;
        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );

        await buildController().check();

        expect(navigated, isEmpty);
        expect(store.takeCallCount, 0);
      });
    }

    test(
      'currentPath() empty (router has not parsed yet) leaves the store '
      'unread',
      () async {
        currentPathValue = '';
        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );

        await buildController().check();

        expect(navigated, isEmpty);
        expect(store.takeCallCount, 0);
      },
    );

    test(
      'currentPath() already equal to the pending path refreshes instead of '
      'navigating (the shown screen must not be left stale)',
      () async {
        currentPathValue = '/care-today';
        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );

        await buildController().check();

        expect(navigated, isEmpty);
        expect(refreshes, 1);
      },
    );

    test('an expired pending path does not refresh either', () async {
      currentPathValue = '/care-today';
      store.enqueue(
        PendingDeepLink(
          path: '/care-today',
          savedAt: fixedNow.subtract(const Duration(minutes: 6)),
        ),
      );

      await buildController().check();

      expect(navigated, isEmpty);
      expect(refreshes, 0);
    });

    test('a null result from the store does not navigate or throw', () async {
      store.enqueue(null);

      await buildController().check();

      expect(navigated, isEmpty);
    });

    test(
      'a second check() after a successful one does not navigate again',
      () async {
        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );
        final controller = buildController();

        await controller.check();
        await controller.check();

        expect(navigated, ['/care-today']);
      },
    );

    test('two concurrent check()s navigate exactly once', () async {
      store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
      store.holdUntil = Completer<void>();
      final controller = buildController();

      final first = controller.check();
      final second = controller.check();
      store.holdUntil!.complete();
      await first;
      await second;

      expect(navigated, ['/care-today']);
      // The overlapping trigger is re-run once the first check finishes (it
      // may have been the one that had something to hand over), so the store
      // is read a second time — and finds nothing left to act on.
      expect(store.takeCallCount, 2);
    });

    test(
      'a trigger that arrives while a check is in flight is re-run, not '
      'dropped (the worker may have written the entry after the first read)',
      () async {
        store.holdUntil = Completer<void>();
        final controller = buildController();

        // First check reads an empty store (the worker has not written yet).
        final first = controller.check();
        await Future<void>.delayed(Duration.zero);
        // The worker writes and signals while that read is still in flight.
        store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
        controller.check();
        store.holdUntil!.complete();
        await first;

        expect(navigated, ['/care-today']);
        expect(store.takeCallCount, 2);
      },
    );

    test(
      'a controller disposed while the store read is in flight does not '
      'navigate',
      () async {
        store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
        store.holdUntil = Completer<void>();
        final controller = buildController();

        final pending = controller.check();
        controller.dispose();
        store.holdUntil!.complete();
        await pending;

        expect(navigated, isEmpty);
        expect(refreshes, 0);
      },
    );
  });

  group('triggers', () {
    test('a handoverSignals event triggers a check', () async {
      final controller = buildController();
      controller.start();
      addTearDown(controller.dispose);
      // Let the initial start()-driven check (store empty) settle.
      await Future<void>.delayed(Duration.zero);

      store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
      store.emitSignal();
      await Future<void>.delayed(Duration.zero);

      expect(navigated, ['/care-today']);
    });

    test(
      "didChangeAppLifecycleState(resumed) triggers a check; other lifecycle "
      'states do not',
      () async {
        final controller = buildController();

        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );
        controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
        await Future<void>.delayed(Duration.zero);
        expect(navigated, isEmpty);
        expect(store.takeCallCount, 0);

        controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        await Future<void>.delayed(Duration.zero);
        expect(navigated, ['/care-today']);
      },
    );

    test('onNavigation() after a gate refusal runs a check', () async {
      canNavigateValue = false;
      final controller = buildController();
      await controller.check(); // gate-refused: canNavigate() false

      canNavigateValue = true;
      store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));

      controller.onNavigation();
      await Future<void>.delayed(Duration.zero);

      expect(navigated, ['/care-today']);
    });

    test(
      'onNavigation() when the previous check was not gate-refused does not '
      'touch the store',
      () async {
        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );
        final controller = buildController();
        await controller.check(); // succeeds, not gate-refused
        final takesBefore = store.takeCallCount;

        controller.onNavigation();
        await Future<void>.delayed(Duration.zero);

        expect(store.takeCallCount, takesBefore);
      },
    );
  });
}
