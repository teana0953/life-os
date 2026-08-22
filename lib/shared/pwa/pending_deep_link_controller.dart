import 'dart:async';

import 'package:flutter/widgets.dart';

import '../routing/app_locations.dart';
import 'pending_deep_link.dart';

/// Locations the pending hand-over must never be consumed on (design.md D6
/// gate 2) — transient auth-bootstrap screens and the sign-in gates, from the
/// same declarations the router's own redirect uses. An empty `currentPath`
/// (the router hasn't parsed yet, as on the very first `check()` from
/// `initState`) is treated the same way.
bool _isTransitionScreen(String loc) =>
    loc.isEmpty || isTransientLocation(loc) || isAuthGateLocation(loc);

/// Holds all the judgement for consuming a [PendingDeepLinkStore] entry:
/// 5-minute TTL, clear-on-read, never read while auth is unresolved or the
/// app sits on a transition screen, ignore a destination this app version
/// does not recognize, reload rather than stack when the app is already
/// showing it, a bounded single-flight guard, and re-checks on resume / auth
/// transition / worker signal (design.md D2/D4/D6-D8).
///
/// [start] wires the lifecycle observer + signal subscription and is called
/// once from the composition root; tests instead drive [check] directly so
/// they never need a real observer.
class PendingDeepLinkController with WidgetsBindingObserver {
  PendingDeepLinkController(
    this._store, {
    Duration ttl = const Duration(minutes: 5),
    Duration storeTimeout = const Duration(seconds: 5),
    DateTime Function() now = DateTime.now,
    required bool Function() canNavigate,
    required String Function() currentPath,
    required bool Function(String path) recognizes,
    required Future<bool> Function(String path) navigate,
    required Future<void> Function(String path) refresh,
    required void Function() onForegrounded,
  }) : _onForegrounded = onForegrounded,
       _ttl = ttl,
       _storeTimeout = storeTimeout,
       _now = now,
       _canNavigate = canNavigate,
       _currentPath = currentPath,
       _recognizes = recognizes,
       _navigate = navigate,
       _refresh = refresh;

  final PendingDeepLinkStore _store;
  final Duration _ttl;

  /// Bound on the store read (design.md D6). Cache Storage can answer neither
  /// with a value nor with an error — blocked site data, private mode — and
  /// an unbounded `await` there never reaches the `finally` that releases the
  /// single-flight guard, so ONE such read would silently drop every
  /// notification tap for the rest of the session (issue #193).
  final Duration _storeTimeout;
  final DateTime Function() _now;
  final bool Function() _canNavigate;
  final String Function() _currentPath;

  /// Whether the *running app version* has a screen for this path, answered
  /// by the router's own configuration (design.md D2). The worker that writes
  /// a hand-over deliberately outlives app updates, so the writer and the
  /// reader can be different versions; a path this version cannot match must
  /// be treated as no hand-over at all rather than navigated to, which would
  /// replace the user's screen with a not-found page.
  final bool Function(String path) _recognizes;

  /// Navigates to the destination, reporting whether the app was **already
  /// showing it somewhere in its stack** and was returned to it rather than
  /// having a new screen built (design.md D4). That answer is what decides
  /// whether the destination needs reloading: nothing was built, so nothing
  /// loaded.
  final Future<bool> Function(String path) _navigate;

  /// Reloads what the destination screen is showing, for the case where no
  /// screen was built because the app was already on it. The screen loads
  /// once on `initState`, so without this a reminder tapped from 今日照護
  /// itself would leave the user staring at the list as it was when they last
  /// opened it — across midnight, at yesterday's date, where Done records
  /// against the wrong day. Takes the destination: more than one path can be
  /// handed over, and only the one arrived at may be reloaded. Awaited, so
  /// the reload it runs stays inside this check's in-flight window.
  final Future<void> Function(String path) _refresh;

  /// What being brought to the foreground does on its own, independently of
  /// any hand-over: the composition root asks the engine for a frame
  /// (issue #226). Injected rather than called directly so it is observable
  /// off the browser — the store that carries these signals on web is an
  /// untested adapter.
  final void Function() _onForegrounded;

  bool _checking = false;

  /// A trigger that arrived while a check was in flight. The in-flight check
  /// may already have read an empty store just before the worker wrote its
  /// entry, and in the foreground case (design.md D4) there is no later
  /// trigger to fall back on — so the request is remembered and re-run rather
  /// than dropped by the single-flight guard.
  bool _recheckRequested = false;

  /// Set by [dispose]: nothing may navigate after the owning widget is gone,
  /// including a check that was already awaiting the store when it happened.
  bool _disposed = false;

  StreamSubscription<void>? _signalSubscription;

  /// Consumes the pending hand-over if — and only if — auth is ready, the app
  /// is on a real screen, and there is a fresh, not-yet-consumed entry. Safe
  /// to call repeatedly; concurrent calls collapse to a single in-flight check
  /// and are re-run once it finishes (design.md D8).
  Future<void> check() async {
    if (_checking) {
      _recheckRequested = true;
      return;
    }
    _checking = true;
    try {
      await _runCheck();
      while (_recheckRequested) {
        _recheckRequested = false;
        await _runCheck();
      }
    } finally {
      _checking = false;
      _recheckRequested = false;
    }
  }

  Future<void> _runCheck() async {
    // Nothing may be read after dispose, not even by a re-run queued before
    // it happened: `take()` is read-and-delete, so a check that runs anyway
    // would silently swallow a live hand-over.
    if (_disposed) return;
    if (!_canNavigate()) return;
    final path = _currentPath();
    if (_isTransitionScreen(path)) return;

    final PendingDeepLink? pending;
    try {
      pending = await _store.take().timeout(_storeTimeout);
    } catch (_) {
      // A broken — or unanswerable — hand-over must not surface as an error
      // (design.md D2/D6). The TimeoutException lands here too, which is the
      // point: it is what lets the `finally` above release the guard.
      return;
    }
    if (pending == null) return;
    if (_now().difference(pending.savedAt) > _ttl) return;
    if (_disposed) return;
    // Consumed (take() already deleted it) but not acted on: a destination
    // this app version cannot navigate by, or has no screen for, is no
    // hand-over at all (design.md D2). Malformed is checked here rather than
    // left to the router: a relative or absolute-URL string is not the form
    // the app navigates by, whatever a matcher would make of it.
    if (!pending.path.startsWith('/') || pending.path.startsWith('//')) {
      return;
    }
    if (!_recognizes(pending.path)) return;

    final alreadyShowing = await _navigate(pending.path);
    if (_disposed) return;
    if (!alreadyShowing) return;
    try {
      await _refresh(pending.path);
    } catch (_) {
      // Every trigger is fire-and-forget, so a throw here (fetching a fresh
      // id token, say) would escape as an unhandled async error. A failed
      // hand-over is silent by design — the screen keeps what it has.
    }
  }

  /// The app is in front of the user again. The foreground effect runs FIRST
  /// and unconditionally — before every gate in [check] — because those gates
  /// are what swallowed the signal in issue #226: a tap that finds nothing
  /// pending (the common case) ended the code path having never asked the
  /// engine to paint, leaving the user in front of a painted, dead screen.
  void _foregrounded() {
    _onForegrounded();
    check();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _foregrounded();
  }

  /// Begins lifecycle observation and worker-signal subscription, and runs
  /// one initial check. Idempotent, mirroring `PwaUpdateController.start()`.
  void start() {
    if (_signalSubscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _signalSubscription = _store.handoverSignals.listen((_) => _foregrounded());
    check();
  }

  void dispose() {
    _disposed = true;
    if (_signalSubscription == null) return;
    WidgetsBinding.instance.removeObserver(this);
    _signalSubscription!.cancel();
    _signalSubscription = null;
  }
}
