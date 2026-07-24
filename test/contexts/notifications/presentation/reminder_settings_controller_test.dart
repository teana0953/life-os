import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';
import 'package:life_os/contexts/notifications/presentation/reminder_settings_controller.dart';

class _FakePushRepository implements PushRepository {
  String vapidPublicKey = 'fake-vapid-key';
  Object? fetchError;
  Object? saveError;
  Object? sendTestError;
  TestPushResult testResult = const TestPushResult(sent: 2, failed: 0);
  Completer<TestPushResult>? sendTestCompleter;

  @override
  Future<String> fetchVapidPublicKey(String idToken) async {
    if (fetchError != null) throw fetchError!;
    return vapidPublicKey;
  }

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) async {
    if (saveError != null) throw saveError!;
  }

  @override
  Future<TestPushResult> sendTest(String idToken) {
    if (sendTestCompleter != null) return sendTestCompleter!.future;
    if (sendTestError != null) throw sendTestError!;
    return Future.value(testResult);
  }
}

class _FakeWebPushGateway implements WebPushGateway {
  PushEnvironment environment = const PushEnvironment(
    supported: true,
    iosNeedsInstall: false,
  );
  PushSubscription? subscriptionToReturn = const PushSubscription(
    endpoint: 'https://push.example/abc',
    p256dh: 'p256dh-key',
    auth: 'auth-key',
  );
  Completer<PushSubscription?>? enableCompleter;
  PushPermissionStatus permission = PushPermissionStatus.prompt;

  @override
  PushEnvironment describeEnvironment() => environment;

  @override
  PushPermissionStatus permissionStatus() => permission;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) {
    if (enableCompleter != null) return enableCompleter!.future;
    return Future.value(subscriptionToReturn);
  }
}

ReminderSettingsController _controller({
  _FakePushRepository? repository,
  _FakeWebPushGateway? gateway,
}) {
  final repo = repository ?? _FakePushRepository();
  final gw = gateway ?? _FakeWebPushGateway();
  return ReminderSettingsController(
    gw,
    EnableReminders(repo, gw),
    SendTestPush(repo),
  );
}

void main() {
  group('ReminderSettingsController.load', () {
    test('resolves idle when the environment is supported', () {
      final controller = _controller();

      controller.load();

      expect(controller.status, ReminderSettingsStatus.idle);
    });

    test('resolves unsupported when the platform lacks support', () {
      final gateway = _FakeWebPushGateway()
        ..environment = const PushEnvironment(
          supported: false,
          iosNeedsInstall: false,
        );
      final controller = _controller(gateway: gateway);

      controller.load();

      expect(controller.status, ReminderSettingsStatus.unsupported);
    });

    test('resolves iosNeedsInstall before unsupported when both are true '
        '(design D3)', () {
      final gateway = _FakeWebPushGateway()
        ..environment = const PushEnvironment(
          supported: false,
          iosNeedsInstall: true,
        );
      final controller = _controller(gateway: gateway);

      controller.load();

      expect(controller.status, ReminderSettingsStatus.iosNeedsInstall);
    });

    test('resolves permissionDenied when the browser permission was already '
        'denied in a prior session', () {
      final gateway = _FakeWebPushGateway()
        ..permission = PushPermissionStatus.denied;
      final controller = _controller(gateway: gateway);

      controller.load();

      expect(controller.status, ReminderSettingsStatus.permissionDenied);
    });

    test('leaves an already-enabled status alone instead of re-resolving '
        'the environment', () {
      final controller = _controller()..status = ReminderSettingsStatus.enabled;

      controller.load();

      expect(controller.status, ReminderSettingsStatus.enabled);
    });
  });

  group('ReminderSettingsController.enable', () {
    test('idle -> enabling -> enabled on grant', () async {
      final gateway = _FakeWebPushGateway();
      final controller = _controller(gateway: gateway)
        ..status = ReminderSettingsStatus.idle;

      final enableCompleter = Completer<PushSubscription?>();
      gateway.enableCompleter = enableCompleter;
      final future = controller.enable('token-123');
      expect(controller.status, ReminderSettingsStatus.enabling);

      enableCompleter.complete(gateway.subscriptionToReturn);
      await future;

      expect(controller.status, ReminderSettingsStatus.enabled);
    });

    test('resolves to permissionDenied when the user denies', () async {
      final gateway = _FakeWebPushGateway()..subscriptionToReturn = null;
      final controller = _controller(gateway: gateway);

      await controller.enable('token-123');

      expect(controller.status, ReminderSettingsStatus.permissionDenied);
    });

    test(
      'resolves to error and holds the typed error on repository failure',
      () async {
        final repository = _FakePushRepository()
          ..fetchError = const PushRequestFailed();
        final controller = _controller(repository: repository);

        await controller.enable('token-123');

        expect(controller.status, ReminderSettingsStatus.error);
        expect(controller.error, isA<PushRequestFailed>());
      },
    );

    test(
      'holds a PushReauthRequired distinctly from a generic failure',
      () async {
        final repository = _FakePushRepository()
          ..fetchError = const PushReauthRequired();
        final controller = _controller(repository: repository);

        await controller.enable('token-123');

        expect(controller.status, ReminderSettingsStatus.error);
        expect(controller.error, isA<PushReauthRequired>());
      },
    );

    test(
      'a second concurrent call is ignored while enabling is in flight',
      () async {
        final gateway = _FakeWebPushGateway();
        final controller = _controller(gateway: gateway);
        final enableCompleter = Completer<PushSubscription?>();
        gateway.enableCompleter = enableCompleter;

        final first = controller.enable('token-123');
        final second = controller.enable('token-123');
        expect(controller.status, ReminderSettingsStatus.enabling);

        enableCompleter.complete(gateway.subscriptionToReturn);
        await Future.wait([first, second]);

        expect(controller.status, ReminderSettingsStatus.enabled);
      },
    );
  });

  group('ReminderSettingsController.sendTest', () {
    test(
      'surfaces the sent/failed result and does not change status',
      () async {
        final repository = _FakePushRepository()
          ..testResult = const TestPushResult(sent: 3, failed: 1);
        final controller = _controller(repository: repository)
          ..status = ReminderSettingsStatus.enabled;

        await controller.sendTest('token-123');

        expect(controller.testResult!.sent, 3);
        expect(controller.testResult!.failed, 1);
        expect(controller.status, ReminderSettingsStatus.enabled);
        expect(controller.testError, isNull);
      },
    );

    test(
      'holds a typed testError on failure without leaving the enabled state',
      () async {
        final repository = _FakePushRepository()
          ..sendTestError = const PushRequestFailed();
        final controller = _controller(repository: repository)
          ..status = ReminderSettingsStatus.enabled;

        await controller.sendTest('token-123');

        expect(controller.testError, isA<PushRequestFailed>());
        expect(controller.status, ReminderSettingsStatus.enabled);
      },
    );

    test('a PushReauthRequired routes status to error and holds the typed '
        'error, in addition to testError', () async {
      final repository = _FakePushRepository()
        ..sendTestError = const PushReauthRequired();
      final controller = _controller(repository: repository)
        ..status = ReminderSettingsStatus.enabled;

      await controller.sendTest('token-123');

      expect(controller.testError, isA<PushReauthRequired>());
      expect(controller.status, ReminderSettingsStatus.error);
      expect(controller.error, isA<PushReauthRequired>());
    });

    test('re-entrancy is blocked while a test push is in flight', () async {
      final repository = _FakePushRepository();
      final sendTestCompleter = Completer<TestPushResult>();
      repository.sendTestCompleter = sendTestCompleter;
      final controller = _controller(repository: repository)
        ..status = ReminderSettingsStatus.enabled;

      final first = controller.sendTest('token-123');
      expect(controller.testInFlight, isTrue);
      final second = controller.sendTest('token-123');

      sendTestCompleter.complete(const TestPushResult(sent: 1, failed: 0));
      await Future.wait([first, second]);

      expect(controller.testInFlight, isFalse);
      expect(controller.testResult!.sent, 1);
    });
  });
}
