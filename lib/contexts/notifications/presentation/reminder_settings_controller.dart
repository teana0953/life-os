import 'package:flutter/foundation.dart';

import '../application/enable_reminders.dart';
import '../application/send_test_push.dart';
import '../domain/push_repository.dart';
import '../domain/web_push_gateway.dart';

enum ReminderSettingsStatus {
  unsupported,
  iosNeedsInstall,
  permissionDenied,
  idle,
  enabling,
  enabled,
  error,
}

/// Drives [ReminderSettingsScreen]: [load] resolves the environment (design
/// D3: iOS-install precedence) without prompting for permission — called
/// once when the screen opens. [enable] runs the grant → subscribe → save
/// flow (idle → enabling → enabled / permissionDenied / error /
/// unsupported / iosNeedsInstall — [EnableReminders] re-checks the
/// environment as its own short-circuit). [sendTest] is only meaningful once
/// [status] is [ReminderSettingsStatus.enabled] and leaves [status] alone on
/// a generic failure — a failed test doesn't invalidate an otherwise-working
/// subscription. A [PushReauthRequired] from [sendTest] is the exception: it
/// also routes [status] to [ReminderSettingsStatus.error] so the screen's
/// full-screen reauth exit takes over, since a stale token means the
/// subscription itself needs re-auth, not just the test call. Holds typed
/// errors, not text — the owning screen maps them to localized copy.
class ReminderSettingsController extends ChangeNotifier {
  final WebPushGateway _gateway;
  final EnableReminders _enableReminders;
  final SendTestPush _sendTestPush;

  ReminderSettingsController(
    this._gateway,
    this._enableReminders,
    this._sendTestPush,
  );

  ReminderSettingsStatus status = ReminderSettingsStatus.idle;
  Object? error;

  /// Whether push is actually on: `status == enabled` alone understates it —
  /// [load] resolves back to `idle` for an already-subscribed prior session
  /// (see class doc), so this also treats a granted browser permission as
  /// "on". Read-only; does not affect [enable]/[sendTest].
  bool get pushOn =>
      status == ReminderSettingsStatus.enabled ||
      _gateway.permissionStatus() == PushPermissionStatus.granted;

  bool testInFlight = false;
  TestPushResult? testResult;
  Object? testError;

  /// Resolves the environment without prompting for permission. A no-op if
  /// [status] is already [ReminderSettingsStatus.enabled] — the screen calls
  /// [load] on every open (`initState`), and since the controller is a
  /// singleton, re-resolving would otherwise reset an already-enabled state
  /// back to idle and re-offer "Enable".
  void load() {
    if (status == ReminderSettingsStatus.enabled) return;
    final env = _gateway.describeEnvironment();
    if (env.iosNeedsInstall) {
      status = ReminderSettingsStatus.iosNeedsInstall;
    } else if (!env.supported) {
      status = ReminderSettingsStatus.unsupported;
    } else if (_gateway.permissionStatus() == PushPermissionStatus.denied) {
      status = ReminderSettingsStatus.permissionDenied;
    } else {
      status = ReminderSettingsStatus.idle;
    }
    notifyListeners();
  }

  Future<void> enable(String idToken) async {
    // Re-entrancy guard: ignore a second call while one is already running.
    if (status == ReminderSettingsStatus.enabling) return;
    status = ReminderSettingsStatus.enabling;
    error = null;
    notifyListeners();

    try {
      final outcome = await _enableReminders(idToken);
      status = switch (outcome) {
        EnableRemindersOutcome.enabled => ReminderSettingsStatus.enabled,
        EnableRemindersOutcome.permissionDenied =>
          ReminderSettingsStatus.permissionDenied,
        EnableRemindersOutcome.unsupported =>
          ReminderSettingsStatus.unsupported,
        EnableRemindersOutcome.iosNeedsInstall =>
          ReminderSettingsStatus.iosNeedsInstall,
      };
    } catch (e) {
      error = e;
      status = ReminderSettingsStatus.error;
    }
    notifyListeners();
  }

  Future<void> sendTest(String idToken) async {
    if (testInFlight) return;
    testInFlight = true;
    testError = null;
    notifyListeners();

    try {
      testResult = await _sendTestPush(idToken);
    } catch (e) {
      testError = e;
      if (e is PushReauthRequired) {
        error = e;
        status = ReminderSettingsStatus.error;
      }
    }
    testInFlight = false;
    notifyListeners();
  }
}
