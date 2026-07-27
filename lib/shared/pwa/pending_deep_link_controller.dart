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
/// single-flight guard, and re-checks on resume / navigation / worker signal
/// (design.md D6-D8).
///
/// [start] wires the lifecycle observer + signal subscription and is called
/// once from the composition root; tests instead drive [check] /
/// [onNavigation] directly so they never need a real observer.
class PendingDeepLinkController with WidgetsBindingObserver {
  PendingDeepLinkController(
    this._store, {
    Duration ttl = const Duration(minutes: 5),
    DateTime Function() now = DateTime.now,
    required bool Function() canNavigate,
    required String Function() currentPath,
    required void Function(String path) navigate,
    required void Function() refresh,
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
  /// records against the wrong day.
  final void Function() _refresh;

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

  /// Set whenever [check] returns at either gate, cleared once a check gets
  /// past them. [onNavigation] only re-checks while this is set, so the
  /// router-delegate subscription acts as a retry point for a gate refusal
  /// rather than a poller on every navigation (design.md D6).
  bool _gateRefused = false;

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
    if (!_canNavigate()) {
      _gateRefused = true;
      return;
    }
    final path = _currentPath();
    if (_isTransitionScreen(path)) {
      _gateRefused = true;
      return;
    }
    _gateRefused = false;

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
      _refresh();
      return;
    }
    _navigate(pending.path);
  }

  /// Retries after a gate refusal — the reason the router-delegate
  /// subscription exists. A no-op otherwise, so ordinary navigation doesn't
  /// read the store on every route change.
  void onNavigation() {
    if (_gateRefused) check();
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
