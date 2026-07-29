import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/auth/domain/auth_repository.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';
import 'package:life_os/contexts/notifications/presentation/push_health_controller.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';

class _InertAuthRepository implements AuthRepository {
  @override
  Future<String?> idToken() async => null;

  @override
  Stream<bool> get authStateChanges => const Stream.empty();

  @override
  Future<void> signIn(String email, String password) async {}

  @override
  Future<void> signUp(String email, String password) async {}

  @override
  Future<void> signOut() async {}
}

class _InertWebPushGateway implements WebPushGateway {
  @override
  PushEnvironment describeEnvironment() =>
      const PushEnvironment(supported: true, iosNeedsInstall: false);

  @override
  PushPermissionStatus permissionStatus() => PushPermissionStatus.granted;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) async =>
      null;
}

class _InertPushRepository implements PushRepository {
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

/// A [PushHealthController] pinned to [health] for widget tests: its
/// dependencies are inert fakes and nothing triggers a check, so the screen
/// under test simply reads [PushHealthController.health] and rebuilds when the
/// test flips it and calls `notifyListeners`. Its own behavior is covered by
/// `push_health_controller_test.dart`.
///
/// Disposed on tear-down: the controller registers itself as a
/// `WidgetsBindingObserver` in its constructor, so without this every widget
/// test that builds one would leave another observer on the binding for the
/// rest of the file.
PushHealthController testPushHealthController([
  PushHealth health = PushHealth.unknown,
]) {
  final gateway = _InertWebPushGateway();
  final repository = _InertPushRepository();
  final enableReminders = EnableReminders(repository, gateway);
  final controller = PushHealthController(
    gateway: gateway,
    enableReminders: enableReminders,
    authRepository: _InertAuthRepository(),
    reminderSettingsController: ReminderSettingsController(
      gateway,
      enableReminders,
      SendTestPush(repository),
    ),
  )..health = health;
  addTearDown(controller.dispose);
  return controller;
}
