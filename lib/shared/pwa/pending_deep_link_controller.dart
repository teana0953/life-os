import 'dart:async';

import 'package:flutter/widgets.dart';

import 'pending_deep_link.dart';

/// Locations the pending hand-over must never be consumed on (design.md D6
/// gate 2) — transient auth-bootstrap screens and the sign-in gates. An empty
/// `currentPath` (the router hasn't parsed yet, as on the very first `check()`
/// from `initState`) is treated the same way.
const _transientLocations = {'/splash', '/auth-error', '/login', '/register'};

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
  }) : _ttl = ttl,
       _now = now,
       _canNavigate = canNavigate,
       _currentPath = currentPath,
       _navigate = navigate;

  final PendingDeepLinkStore _store;
  final Duration _ttl;
  final DateTime Function() _now;
  final bool Function() _canNavigate;
  final String Function() _currentPath;
  final void Function(String path) _navigate;

  bool _checking = false;

  /// Set whenever [check] returns at either gate, cleared once a check gets
  /// past them. [onNavigation] only re-checks while this is set, so the
  /// router-delegate subscription acts as a retry point for a gate refusal
  /// rather than a poller on every navigation (design.md D6).
  bool _gateRefused = false;

  StreamSubscription<void>? _signalSubscription;

  /// Consumes the pending hand-over if — and only if — auth is ready, the app
  /// is on a real screen, and there is a fresh, not-yet-consumed entry for
  /// somewhere other than where the app already is. Safe to call repeatedly;
  /// concurrent calls collapse to a single in-flight check (design.md D8).
  Future<void> check() async {
    if (_checking) return;
    _checking = true;
    try {
      if (!_canNavigate()) {
        _gateRefused = true;
        return;
      }
      final path = _currentPath();
      if (path.isEmpty || _transientLocations.contains(path)) {
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
      if (_currentPath() == pending.path) return;
      _navigate(pending.path);
    } finally {
      _checking = false;
    }
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
    if (_signalSubscription == null) return;
    WidgetsBinding.instance.removeObserver(this);
    _signalSubscription!.cancel();
    _signalSubscription = null;
  }
}
