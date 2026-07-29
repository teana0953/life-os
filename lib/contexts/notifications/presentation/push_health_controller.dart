import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../auth/domain/auth_repository.dart';
import '../application/enable_reminders.dart';
import '../domain/web_push_gateway.dart';
import 'reminder_settings_controller.dart';

/// Whether push notifications can actually reach this device.
enum PushHealth {
  /// Not checked yet — show nothing rather than guess.
  unknown,

  /// The subscription is registered and permission is granted.
  ok,

  /// Permission has never been requested (browser `default`).
  permissionPrompt,

  /// Permission was turned off by the user or the system.
  permissionDenied,

  /// Permission is granted but re-registering the subscription failed. Not
  /// surfaced to the user (the backend subscription is still live and push
  /// still arrives); retried silently on the next check.
  syncFailed,

  /// This environment cannot do Web Push at all.
  unsupported,
}

/// Detects when push can't be delivered and silently repairs what it can.
///
/// The dividing line: a drifted *subscription* is the program's problem and is
/// fixed by re-running [EnableReminders] (idempotent — an already-subscribed
/// browser returns its existing subscription and the backend upserts by
/// endpoint), while an OS-level *permission* being off is the only thing the
/// user has to act on, and the only thing that raises a banner.
///
/// [check] resolves in four steps and the order is the design: the environment
/// first (`iosNeedsInstall` before `supported`, as in `EnableReminders` — iOS
/// Safari hides `PushManager` until the app is installed), then the signed-in
/// state, then the permission, and only then the sync.
///
/// Checked on three triggers, all three needed: the sign-in becoming
/// established (a check at app start would find no user, since restoring a
/// persisted sign-in is asynchronous, and would never run again), the app
/// returning to the foreground, and the reminder settings screen transitioning
/// into `enabled` (the banner → settings → enable → back journey never leaves
/// the SPA, so it produces no `resumed`).
class PushHealthController extends ChangeNotifier with WidgetsBindingObserver {
  final WebPushGateway _gateway;
  final EnableReminders _enableReminders;
  final AuthRepository _authRepository;
  final ReminderSettingsController _reminderSettingsController;
  final DateTime Function() _clock;
  final Duration _suppressWindow;

  late StreamSubscription<bool> _authSubscription;
  ReminderSettingsStatus _lastSettingsStatus;
  DateTime? _lastSyncAt;
  bool _checking = false;

  PushHealthController({
    required WebPushGateway gateway,
    required EnableReminders enableReminders,
    required AuthRepository authRepository,
    required ReminderSettingsController reminderSettingsController,
    DateTime Function() clock = DateTime.now,
    Duration suppressWindow = const Duration(hours: 1),
  }) : _gateway = gateway,
       _enableReminders = enableReminders,
       _authRepository = authRepository,
       _reminderSettingsController = reminderSettingsController,
       _clock = clock,
       _suppressWindow = suppressWindow,
       _lastSettingsStatus = reminderSettingsController.status {
    _reminderSettingsController.addListener(_onSettingsChanged);
    _authSubscription = _authRepository.authStateChanges.listen((signedIn) {
      if (signedIn) check();
    });
  }

  PushHealth health = PushHealth.unknown;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) check();
  }

  /// Resolves [health], re-registering the push subscription when permission
  /// allows it. [force] skips the post-success suppression window.
  Future<void> check({bool force = false}) async {
    // Re-entrancy guard: ignore a second call while one is already running.
    if (_checking) return;
    _checking = true;
    try {
      final env = _gateway.describeEnvironment();
      if (env.iosNeedsInstall || !env.supported) {
        _set(PushHealth.unsupported);
        return;
      }

      // Signed out: not a failure. Leaving [health] alone keeps a banner from
      // flashing on the way out.
      final idToken = await _authRepository.idToken();
      if (idToken == null) return;

      switch (_gateway.permissionStatus()) {
        case PushPermissionStatus.denied:
          _set(PushHealth.permissionDenied);
          return;
        case PushPermissionStatus.prompt:
          _set(PushHealth.permissionPrompt);
          return;
        case PushPermissionStatus.granted:
          break;
      }

      // Suppression applies only after a success: the moment permission comes
      // back is exactly when re-subscribing matters most (the browser
      // invalidates the old subscription when permission is revoked), so a
      // failed or permission-blocked state always re-attempts.
      if (!force && health == PushHealth.ok && _lastSyncAt != null) {
        if (_clock().difference(_lastSyncAt!) < _suppressWindow) return;
      }

      try {
        final outcome = await _enableReminders(idToken);
        if (outcome == EnableRemindersOutcome.enabled) {
          _lastSyncAt = _clock();
          _set(PushHealth.ok);
        } else {
          _set(PushHealth.syncFailed);
        }
      } catch (_) {
        _set(PushHealth.syncFailed);
      }
    } finally {
      _checking = false;
    }
  }

  /// Edge-triggered: only the transition *into* `enabled` re-checks. Level
  /// triggering would re-sync on every unrelated notification from that
  /// screen — `sendTest` alone notifies twice per call while already enabled,
  /// each of which would bypass the suppression window.
  void _onSettingsChanged() {
    final previous = _lastSettingsStatus;
    final current = _reminderSettingsController.status;
    _lastSettingsStatus = current;
    if (current == ReminderSettingsStatus.enabled &&
        previous != ReminderSettingsStatus.enabled) {
      check(force: true);
    }
  }

  void _set(PushHealth next) {
    if (health == next) return;
    health = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    _reminderSettingsController.removeListener(_onSettingsChanged);
    super.dispose();
  }
}
