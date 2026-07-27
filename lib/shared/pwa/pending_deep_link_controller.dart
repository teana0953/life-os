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
/// app sits on a transition screen, skip when already on the target route,
/// single-flight guard, and re-checks on resume / auth transition / worker
/// signal (design.md D6-D8).
///
/// [start] wires the lifecycle observer + signal subscription and is called
/// once from the composition root; tests instead drive [check] directly so
/// they never need a real observer.
class PendingDeepLinkController with WidgetsBindingObserver {
  PendingDeepLinkController(
    this._store, {
    Duration ttl = const Duration(minutes: 5),
    DateTime Function() now = DateTime.now,
    required bool Function() canNavigate,
    required String Function() currentPath,
    required void Function(String path) navigate,
    required Future<void> Function() refresh,
  }) : _ttl = ttl,
       _now = now,
       _canNavigate = canNavigate,
       _currentPath = currentPath,
       _navigate = navigate,
       _refresh = refresh;

  final PendingDeepLinkStore _store;
  final Duration _ttl;
  final DateTime Function() _now;
  final bool Function() _canNavigate;
  final String Function() _currentPath;
  final void Function(String path) _navigate;

  /// Reloads what the destination screen is showing, for the one case where
  /// there is nothing to navigate to because the app is *already* there. The
  /// screen loads once on `initState`, so without this a reminder tapped from
  /// 今日照護 itself would leave the user staring at the list as it was when
  /// they last opened it — across midnight, at yesterday's date, where Done
  /// records against the wrong day. Awaited, so the reload it runs stays
  /// inside this check's in-flight window.
  final Future<void> Function() _refresh;

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
      pending = await _store.take();
    } catch (_) {
      // A broken hand-over must not surface as an error (design.md D2).
      return;
    }
    if (pending == null) return;
    if (_now().difference(pending.savedAt) > _ttl) return;
    if (_disposed) return;
    if (_currentPath() == pending.path) {
      await _refresh();
      return;
    }
    _navigate(pending.path);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  /// Begins lifecycle observation and worker-signal subscription, and runs
  /// one initial check. Idempotent, mirroring `PwaUpdateController.start()`.
  void start() {
    if (_signalSubscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _signalSubscription = _store.handoverSignals.listen((_) => check());
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
