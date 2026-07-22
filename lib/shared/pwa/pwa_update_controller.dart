import 'dart:async';

import 'package:flutter/widgets.dart';

import 'pwa_update.dart';

/// Drives the app-wide "update available" banner.
///
/// The `window.pwaUpdate.available` flag flips asynchronously (once a new
/// service-worker version has installed), so this controller polls
/// [PwaUpdate.updateAvailable] on a periodic [Timer] and re-checks whenever
/// the app is resumed, flipping [showBanner] and notifying listeners.
///
/// [start] wires the timer + lifecycle observer and is called once from the
/// composition root (`main.dart`); widget tests instead drive detection
/// directly via [checkForUpdate] so they never leave a pending timer.
class PwaUpdateController extends ChangeNotifier with WidgetsBindingObserver {
  PwaUpdateController(
    this._pwaUpdate, {
    Duration pollInterval = const Duration(seconds: 15),
  }) : _pollInterval = pollInterval;

  final PwaUpdate _pwaUpdate;
  final Duration _pollInterval;
  Timer? _timer;
  bool _available = false;
  bool _dismissed = false;

  /// Whether the update banner should be visible: an update is available and
  /// the user hasn't dismissed it this session.
  bool get showBanner => _available && !_dismissed;

  /// Begins periodic polling and app-lifecycle observation. Idempotent.
  void start() {
    if (_timer != null) return;
    WidgetsBinding.instance.addObserver(this);
    checkForUpdate();
    _timer = Timer.periodic(_pollInterval, (_) => checkForUpdate());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) checkForUpdate();
  }

  /// Reads the current availability from the bridge and, on a change, updates
  /// [showBanner]. A fresh detection re-shows a previously dismissed banner.
  void checkForUpdate() {
    final available = _pwaUpdate.updateAvailable;
    if (available == _available) return;
    _available = available;
    if (available) _dismissed = false;
    notifyListeners();
  }

  /// Loads the newly downloaded version.
  Future<void> applyUpdate() => _pwaUpdate.applyUpdate();

  /// Hides the banner for this session; it reappears on a future detection or
  /// on next launch.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
      _timer = null;
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }
}
