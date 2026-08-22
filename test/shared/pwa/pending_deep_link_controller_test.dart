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

  /// When true, [take] never returns at all — Cache Storage blocked (private
  /// mode, blocked site data) answers neither with a value nor with an error.
  /// A fake that *throws* instead would exercise the wrong seam: throwing
  /// already reaches the `finally` that releases the single-flight guard.
  bool neverSettles = false;
  final _signals = StreamController<void>.broadcast();

  void enqueue(PendingDeepLink? value) => _queue.add(value);

  @override
  Future<PendingDeepLink?> take() async {
    takeCallCount++;
    // Snapshot before the hold, not after. The real store reads whatever is
    // in the Cache at the moment take() is called, so an entry written while
    // a read is already in flight must NOT become visible to that read.
    // Popping after the await would let the in-flight check pick up the later
    // hand-over and navigate by itself — hiding the dropped trigger that the
    // re-check guard exists to fix.
    final snapshot = _queue.isEmpty ? null : _queue.removeAt(0);
    if (neverSettles) await Completer<void>().future;
    if (holdUntil != null) await holdUntil!.future;
    return snapshot;
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
  late List<String> refreshes;

  /// Paths this fake "app version" has a screen for — the composition root
  /// answers this from the router's own configuration (design D2), so a
  /// path outside this set must be treated as no hand-over at all.
  late Set<String> recognized;

  /// Destinations the fake navigator reports as *already on the stack*, so
  /// navigating returns to them instead of building a new screen — the
  /// signal the controller uses to decide it must reload that screen.
  late Set<String> alreadyShowing;

  /// How many times the composition root's "the app was brought forward"
  /// effect ran — the frame demand of issue #226. Counted rather than
  /// flagged: the point of the fix is that it runs on EVERY foreground
  /// signal, not once.
  late int foregrounded;

  PendingDeepLinkController buildController() => PendingDeepLinkController(
    store,
    now: () => fixedNow,
    onForegrounded: () => foregrounded++,
    canNavigate: () => canNavigateValue,
    currentPath: () => currentPathValue,
    recognizes: (path) => recognized.contains(path),
    navigate: (path) async {
      navigated.add(path);
      return alreadyShowing.contains(path);
    },
    refresh: (path) async => refreshes.add(path),
  );

  setUp(() {
    store = _FakeStore();
    canNavigateValue = true;
    currentPathValue = '/';
    navigated = [];
    refreshes = [];
    recognized = {'/care-today', '/care-history', '/'};
    alreadyShowing = {};
    foregrounded = 0;
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
      expect(refreshes, isEmpty);
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
        alreadyShowing.add('/care-today');
        store.enqueue(
          PendingDeepLink(path: '/care-today', savedAt: fixedNow),
        );

        await buildController().check();

        expect(navigated, ['/care-today']);
        expect(refreshes, ['/care-today']);
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
      expect(refreshes, isEmpty);
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
      'a take() that never answers does not disable every later tap for the '
      'rest of the session',
      () async {
        store.neverSettles = true;
        final controller = PendingDeepLinkController(
          store,
          now: () => fixedNow,
          storeTimeout: const Duration(milliseconds: 10),
          canNavigate: () => canNavigateValue,
          currentPath: () => currentPathValue,
          recognizes: (path) => recognized.contains(path),
          navigate: (path) async {
            navigated.add(path);
            return alreadyShowing.contains(path);
          },
          refresh: (path) async => refreshes.add(path),
          onForegrounded: () => foregrounded++,
        );

        // The first tap's read is swallowed by blocked Cache Storage.
        unawaited(controller.check());
        await Future<void>.delayed(const Duration(milliseconds: 30));

        // The user taps a second notification.
        store.neverSettles = false;
        store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
        await controller.check();

        expect(store.takeCallCount, 2);
        expect(navigated, ['/care-today']);
      },
    );

    test(
      'a path this app version does not recognize is consumed but never '
      'navigated (design D2)',
      () async {
        store.enqueue(
          PendingDeepLink(path: '/no-such-route', savedAt: fixedNow),
        );

        await buildController().check();

        expect(store.takeCallCount, 1);
        expect(navigated, isEmpty);
        expect(refreshes, isEmpty);
      },
    );

    for (final malformed in [
      '',
      'care-today',
      'https://evil.example/x',
      '//evil.example/care-today',
    ]) {
      test('a malformed path (${malformed.isEmpty ? '<empty>' : malformed}) '
          'is consumed but never navigated', () async {
        // recognizes: (_) => true mimics the real router — GoRouter's
        // findMatch parses `//evil.example/care-today` as path
        // `/care-today` and would match it (Uri.parse strips the
        // protocol-relative authority). Using the default `recognized`
        // set here would let this case pass for the wrong reason: it
        // would be rejected by "not recognized", not by the malformed-path
        // guard this test exists to cover, so removing that guard would
        // not turn this test red.
        final controller = PendingDeepLinkController(
          store,
          now: () => fixedNow,
          canNavigate: () => canNavigateValue,
          currentPath: () => currentPathValue,
          recognizes: (_) => true,
          navigate: (path) async {
            navigated.add(path);
            return alreadyShowing.contains(path);
          },
          refresh: (path) async => refreshes.add(path),
          onForegrounded: () => foregrounded++,
        );
        store.enqueue(PendingDeepLink(path: malformed, savedAt: fixedNow));

        await controller.check();

        expect(store.takeCallCount, 1);
        expect(navigated, isEmpty);
      });
    }

    test(
      'a destination already somewhere in the stack is returned to and '
      'reloaded rather than pushed again',
      () async {
        alreadyShowing.add('/care-today');
        store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));

        await buildController().check();

        expect(navigated, ['/care-today']);
        expect(refreshes, ['/care-today']);
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
        expect(refreshes, isEmpty);
      },
    );

    test(
      'a re-run queued before dispose does not read the store afterwards '
      '(take() deletes, so it would swallow a live hand-over)',
      () async {
        store.enqueue(null);
        store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
        store.holdUntil = Completer<void>();
        final controller = buildController();

        // First check reads an empty store; a trigger arrives while it is
        // still in flight, so a re-run is queued…
        final pending = controller.check();
        await Future<void>.delayed(Duration.zero);
        controller.check();
        // …and the widget goes away before that re-run gets to happen.
        controller.dispose();
        store.holdUntil!.complete();
        await pending;

        expect(store.takeCallCount, 1);
        expect(navigated, isEmpty);
      },
    );
  });

  group('triggers', () {
    test(
      'every signal triggers its own check, and one with nothing pending is '
      'harmless (design D7 feeds visibility and focus into this same stream, '
      'so the extra signals must cost nothing)',
      () async {
        final controller = buildController();
        controller.start();
        addTearDown(controller.dispose);
        await Future<void>.delayed(Duration.zero);
        final afterStart = store.takeCallCount;

        store.emitSignal();
        await Future<void>.delayed(Duration.zero);
        store.emitSignal();
        await Future<void>.delayed(Duration.zero);

        expect(store.takeCallCount, afterStart + 2);
        expect(navigated, isEmpty);

        store.enqueue(PendingDeepLink(path: '/care-today', savedAt: fixedNow));
        store.emitSignal();
        await Future<void>.delayed(Duration.zero);

        expect(navigated, ['/care-today']);
      },
    );

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

  });

  /// Issue #226: a window brought forward by a notification tap stays painted
  /// but dead until it is backgrounded and returned to. Every foreground
  /// signal the app has was being spent asking "is there a destination
  /// pending?", so each of the gates below ended the code path with nothing
  /// ever asking the engine to paint. The effect must therefore be produced
  /// BEFORE any gate, on every signal, whatever the hand-over turns out to
  /// be.
  group('foregrounding', () {
    test('start() alone is not a foregrounding', () async {
      final controller = buildController();
      controller.start();
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      expect(foregrounded, 0);
      expect(store.takeCallCount, 1);
    });

    test('a foreground signal with an empty store still foregrounds', () async {
      final controller = buildController();
      controller.start();
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      store.emitSignal();
      await Future<void>.delayed(Duration.zero);
      store.emitSignal();
      await Future<void>.delayed(Duration.zero);

      expect(foregrounded, 2);
      expect(navigated, isEmpty);
    });

    test('a foreground signal with an expired entry still foregrounds', () async {
      final controller = buildController();
      controller.start();
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);

      store.enqueue(
        PendingDeepLink(
          path: '/care-today',
          savedAt: fixedNow.subtract(const Duration(minutes: 6)),
        ),
      );
      store.emitSignal();
      await Future<void>.delayed(Duration.zero);

      expect(foregrounded, 1);
      expect(navigated, isEmpty);
    });

    test(
      'a foreground signal carrying a path this app version cannot match '
      'still foregrounds',
      () async {
        final controller = buildController();
        controller.start();
        addTearDown(controller.dispose);
        await Future<void>.delayed(Duration.zero);

        store.enqueue(
          PendingDeepLink(path: '/no-such-route', savedAt: fixedNow),
        );
        store.emitSignal();
        await Future<void>.delayed(Duration.zero);

        expect(foregrounded, 1);
        expect(navigated, isEmpty);
      },
    );

    test(
      'a foreground signal still foregrounds while the gates are shut — auth '
      'unresolved, and the app on a transition screen (the earliest gates, '
      'the ones that return before the store is even read)',
      () async {
        canNavigateValue = false;
        final controller = buildController();
        controller.start();
        addTearDown(controller.dispose);
        await Future<void>.delayed(Duration.zero);

        store.emitSignal();
        await Future<void>.delayed(Duration.zero);
        expect(foregrounded, 1);
        expect(store.takeCallCount, 0);

        canNavigateValue = true;
        currentPathValue = '';
        store.emitSignal();
        await Future<void>.delayed(Duration.zero);
        expect(foregrounded, 2);
        expect(store.takeCallCount, 0);
      },
    );

    test(
      'a store read that never settles does not swallow the NEXT signal\'s '
      'foregrounding (the single-flight guard collapses the check, not the '
      'frame demand)',
      () async {
        store.neverSettles = true;
        final controller = buildController();
        controller.start();
        addTearDown(controller.dispose);
        await Future<void>.delayed(Duration.zero);

        store.emitSignal();
        await Future<void>.delayed(Duration.zero);
        store.emitSignal();
        await Future<void>.delayed(Duration.zero);

        expect(foregrounded, 2);
      },
    );

    test('didChangeAppLifecycleState(resumed) foregrounds too', () async {
      final controller = buildController();
      addTearDown(controller.dispose);

      controller.didChangeAppLifecycleState(AppLifecycleState.inactive);
      await Future<void>.delayed(Duration.zero);
      expect(foregrounded, 0);

      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);
      expect(foregrounded, 1);
    });
  });
}
