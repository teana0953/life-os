import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';

class _FakeAuthRepository implements AuthRepository {
  String? token = 'token-123';
  Object? tokenError;
  final StreamController<bool> authState = StreamController<bool>.broadcast();

  @override
  Future<String?> idToken() async {
    if (tokenError != null) throw tokenError!;
    return token;
  }

  @override
  Stream<bool> get authStateChanges => authState.stream;

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _FakeWebPushGateway implements WebPushGateway {
  PushEnvironment environment = const PushEnvironment(
    supported: true,
    iosNeedsInstall: false,
  );
  PushPermissionStatus permission = PushPermissionStatus.granted;

  @override
  PushEnvironment describeEnvironment() => environment;

  @override
  PushPermissionStatus permissionStatus() => permission;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) async =>
      null;
}

class _FakePushRepository implements PushRepository {
  @override
  Future<String> fetchVapidPublicKey(String idToken) async => 'vapid';

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) async {}

  @override
  Future<TestPushResult> sendTest(String idToken) async =>
      const TestPushResult(sent: 0, failed: 0);
}

/// Records every call and lets a test choose the outcome — or make the call
/// throw, or hang on [gate] so re-entrancy can be observed.
class _FakeEnableReminders extends EnableReminders {
  _FakeEnableReminders(super.repository, super.gateway);

  int calls = 0;
  String? lastIdToken;
  EnableRemindersOutcome outcome = EnableRemindersOutcome.enabled;
  Object? error;
  Completer<void>? gate;

  @override
  Future<EnableRemindersOutcome> call(String idToken) async {
    calls++;
    lastIdToken = idToken;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return outcome;
  }
}

class _Harness {
  final _FakeAuthRepository auth = _FakeAuthRepository();
  final _FakeWebPushGateway gateway = _FakeWebPushGateway();
  late final _FakeEnableReminders enableReminders = _FakeEnableReminders(
    _FakePushRepository(),
    gateway,
  );
  late final ReminderSettingsController settings = ReminderSettingsController(
    gateway,
    enableReminders,
    SendTestPush(_FakePushRepository()),
  );
  DateTime now = DateTime(2026, 7, 29, 8);

  late final PushHealthController controller = PushHealthController(
    gateway: gateway,
    enableReminders: enableReminders,
    authRepository: auth,
    reminderSettingsController: settings,
    clock: () => now,
  );
}

_Harness _harness() {
  final harness = _Harness();
  // Builds the controller (and with it its auth/settings subscriptions) before
  // a test drives either of them, and pins that it starts out undetermined.
  expect(harness.controller.health, PushHealth.unknown);
  addTearDown(() {
    harness.controller.dispose();
    harness.settings.dispose();
    harness.auth.authState.close();
  });
  return harness;
}

/// Replays what `ReminderSettingsController.enable` broadcasts: idle →
/// `enabling` → [outcome], each with its own notification. Going through
/// `enabling` matters — that transition out of it is what the health
/// controller keys on.
Future<void> _enableOnSettings(
  _Harness harness,
  ReminderSettingsStatus outcome,
) async {
  harness.settings.status = ReminderSettingsStatus.enabling;
  harness.settings.notifyListeners();
  harness.settings.status = outcome;
  harness.settings.notifyListeners();
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushHealthController.check environment', () {
    test('iosNeedsInstall resolves to unsupported without syncing', () async {
      final h = _harness();
      h.gateway.environment = const PushEnvironment(
        supported: false,
        iosNeedsInstall: true,
      );

      await h.controller.check();

      expect(h.controller.health, PushHealth.unsupported);
      expect(h.enableReminders.calls, 0);
    });

    test('an unsupported browser resolves to unsupported', () async {
      final h = _harness();
      h.gateway.environment = const PushEnvironment(
        supported: false,
        iosNeedsInstall: false,
      );

      await h.controller.check();

      expect(h.controller.health, PushHealth.unsupported);
      expect(h.enableReminders.calls, 0);
    });
  });

  group('PushHealthController.check sign-in', () {
    test(
      'a signed-out check leaves the previously resolved health alone',
      () async {
        final h = _harness();
        await h.controller.check();
        expect(h.controller.health, PushHealth.ok);

        h.auth.token = null;
        // force: so the assertion is about the signed-out step, not the
        // post-success suppression.
        await h.controller.check(force: true);

        expect(h.controller.health, PushHealth.ok);
        expect(h.enableReminders.calls, 1);
      },
    );

    test(
      'a throwing idToken resolves to syncFailed instead of escaping — '
      'an expired token on an offline device throws',
      () async {
        final h = _harness();
        h.auth.tokenError = Exception('network-request-failed');

        // Unawaited, exactly as all three triggers call it: an escaping error
        // would surface as an unhandled async error and fail the test.
        h.controller.check();
        await pumpEventQueue();

        expect(h.controller.health, PushHealth.syncFailed);
        expect(h.enableReminders.calls, 0);
      },
    );
  });

  group('PushHealthController.check permission', () {
    test('denied resolves to permissionDenied and costs no request', () async {
      final h = _harness();
      h.gateway.permission = PushPermissionStatus.denied;

      await h.controller.check();

      expect(h.controller.health, PushHealth.permissionDenied);
      expect(h.enableReminders.calls, 0);
    });

    test('prompt resolves to permissionPrompt and costs no request', () async {
      final h = _harness();
      h.gateway.permission = PushPermissionStatus.prompt;

      await h.controller.check();

      expect(h.controller.health, PushHealth.permissionPrompt);
      expect(h.enableReminders.calls, 0);
    });
  });

  group('PushHealthController.check sync', () {
    test('granted + enabled resolves to ok', () async {
      final h = _harness();

      await h.controller.check();

      expect(h.controller.health, PushHealth.ok);
      expect(h.enableReminders.calls, 1);
      expect(h.enableReminders.lastIdToken, 'token-123');
    });

    test('a thrown error resolves to syncFailed', () async {
      final h = _harness();
      h.enableReminders.error = Exception('offline');

      await h.controller.check();

      expect(h.controller.health, PushHealth.syncFailed);
    });

    test('a non-enabled outcome resolves to syncFailed', () async {
      final h = _harness();
      h.enableReminders.outcome = EnableRemindersOutcome.permissionDenied;

      await h.controller.check();

      expect(h.controller.health, PushHealth.syncFailed);
    });
  });

  group('PushHealthController suppression', () {
    test('a success within the hour suppresses the next sync', () async {
      final h = _harness();
      await h.controller.check();

      h.now = h.now.add(const Duration(minutes: 30));
      await h.controller.check();

      expect(h.enableReminders.calls, 1);
      expect(h.controller.health, PushHealth.ok);
    });

    test('an hour later the sync runs again', () async {
      final h = _harness();
      await h.controller.check();

      h.now = h.now.add(const Duration(hours: 1, minutes: 1));
      await h.controller.check();

      expect(h.enableReminders.calls, 2);
    });

    test(
      'a permission revoked inside the suppression window is still caught',
      () async {
        final h = _harness();
        await h.controller.check();
        expect(h.controller.health, PushHealth.ok);

        h.gateway.permission = PushPermissionStatus.denied;
        h.now = h.now.add(const Duration(minutes: 5));
        await h.controller.check();

        expect(h.controller.health, PushHealth.permissionDenied);
        expect(h.enableReminders.calls, 1);
      },
    );

    test('a previous syncFailed is never suppressed', () async {
      final h = _harness();
      h.enableReminders.error = Exception('offline');
      await h.controller.check();
      expect(h.controller.health, PushHealth.syncFailed);

      h.enableReminders.error = null;
      h.now = h.now.add(const Duration(minutes: 1));
      await h.controller.check();

      expect(h.enableReminders.calls, 2);
      expect(h.controller.health, PushHealth.ok);
    });

    test('force bypasses the suppression', () async {
      final h = _harness();
      await h.controller.check();

      h.now = h.now.add(const Duration(minutes: 5));
      await h.controller.check(force: true);

      expect(h.enableReminders.calls, 2);
    });

    test(
      'signing out clears the suppression, so the next account signing in on '
      'this browser re-registers its own subscription',
      () async {
        final h = _harness();
        await h.controller.check();
        expect(h.controller.health, PushHealth.ok);

        h.auth.authState.add(false);
        await pumpEventQueue();
        // Signing out must still not flash a warning.
        expect(h.controller.health, PushHealth.ok);

        h.now = h.now.add(const Duration(minutes: 10));
        h.auth.authState.add(true);
        await pumpEventQueue();

        expect(h.enableReminders.calls, 2);
      },
    );
  });

  group('PushHealthController re-entrancy', () {
    test('a second check while one is in flight is ignored', () async {
      final h = _harness();
      final gate = Completer<void>();
      h.enableReminders.gate = gate;

      final first = h.controller.check();
      await pumpEventQueue();
      final second = h.controller.check();
      gate.complete();
      await Future.wait([first, second]);

      expect(h.enableReminders.calls, 1);
      expect(h.controller.health, PushHealth.ok);
    });

    test(
      'a forced check arriving mid-flight is deferred, not dropped — it is '
      'the only trigger that clears the banner without leaving the SPA',
      () async {
        final h = _harness();
        final gate = Completer<void>();
        h.enableReminders.gate = gate;

        final first = h.controller.check();
        await pumpEventQueue();
        final second = h.controller.check(force: true);
        gate.complete();
        await Future.wait([first, second]);
        await pumpEventQueue();

        expect(h.enableReminders.calls, 2);
        expect(h.controller.health, PushHealth.ok);
      },
    );
  });

  group('PushHealthController triggers', () {
    test('a sign-in becoming established checks push health', () async {
      final h = _harness();
      // Constructing the controller alone must not check: on web the
      // persisted sign-in is restored asynchronously.
      expect(h.enableReminders.calls, 0);

      h.auth.authState.add(true);
      await pumpEventQueue();

      expect(h.enableReminders.calls, 1);
      expect(h.controller.health, PushHealth.ok);
    });

    test('returning to the foreground checks push health', () async {
      final h = _harness();

      h.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();

      expect(h.enableReminders.calls, 1);
    });

    test('a non-resumed lifecycle state does not check', () async {
      final h = _harness();

      h.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      await pumpEventQueue();

      expect(h.enableReminders.calls, 0);
    });

    test(
      'the reminder settings screen finishing an enable checks, bypassing '
      'suppression',
      () async {
        final h = _harness();
        await h.controller.check();
        expect(h.enableReminders.calls, 1);

        await _enableOnSettings(h, ReminderSettingsStatus.enabled);

        expect(h.enableReminders.calls, 2);
      },
    );

    test(
      'denying the permission prompt on the settings screen re-checks, so the '
      'banner stops claiming notifications were never asked for',
      () async {
        final h = _harness();
        h.gateway.permission = PushPermissionStatus.prompt;
        await h.controller.check();
        expect(h.controller.health, PushHealth.permissionPrompt);

        // The user tapped Enable and then denied the browser prompt.
        h.gateway.permission = PushPermissionStatus.denied;
        await _enableOnSettings(h, ReminderSettingsStatus.permissionDenied);

        expect(h.controller.health, PushHealth.permissionDenied);
      },
    );

    test(
      'an already-enabled settings screen notifying again does not check',
      () async {
        final h = _harness();
        await _enableOnSettings(h, ReminderSettingsStatus.enabled);
        expect(h.enableReminders.calls, 1);

        // What `sendTest` does twice per call while already enabled.
        h.settings.notifyListeners();
        h.settings.notifyListeners();
        await pumpEventQueue();

        expect(h.enableReminders.calls, 1);
      },
    );
  });
}
