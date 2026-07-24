import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/enable_reminders.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';
import 'package:life_os/contexts/notifications/domain/web_push_gateway.dart';

class _FakePushRepository implements PushRepository {
  String vapidPublicKey = 'fake-vapid-key';
  Object? fetchError;
  Object? saveError;
  PushSubscription? savedSubscription;
  String? savedIdToken;

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
    savedIdToken = idToken;
    savedSubscription = subscription;
  }

  @override
  Future<TestPushResult> sendTest(String idToken) =>
      throw UnimplementedError();
}

class _FakeWebPushGateway implements WebPushGateway {
  PushEnvironment environment = const PushEnvironment(
    supported: true,
    standalone: true,
    iosNeedsInstall: false,
  );
  PushSubscription? subscriptionToReturn = const PushSubscription(
    endpoint: 'https://push.example/abc',
    p256dh: 'p256dh-key',
    auth: 'auth-key',
  );
  String? capturedVapidPublicKey;

  @override
  PushEnvironment describeEnvironment() => environment;

  @override
  PushPermissionStatus permissionStatus() => PushPermissionStatus.prompt;

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) async {
    capturedVapidPublicKey = vapidPublicKey;
    return subscriptionToReturn;
  }
}

void main() {
  group('EnableReminders', () {
    test(
      'fetches the VAPID key, subscribes via the gateway, and saves the '
      'subscription on the happy path',
      () async {
        final repository = _FakePushRepository();
        final gateway = _FakeWebPushGateway();
        final useCase = EnableReminders(repository, gateway);

        final outcome = await useCase('token-123');

        expect(outcome, EnableRemindersOutcome.enabled);
        expect(gateway.capturedVapidPublicKey, 'fake-vapid-key');
        expect(repository.savedIdToken, 'token-123');
        expect(repository.savedSubscription!.endpoint, 'https://push.example/abc');
        expect(repository.savedSubscription!.p256dh, 'p256dh-key');
        expect(repository.savedSubscription!.auth, 'auth-key');
      },
    );

    test(
      'returns permissionDenied and does not save when the gateway returns '
      'no subscription',
      () async {
        final repository = _FakePushRepository();
        final gateway = _FakeWebPushGateway()..subscriptionToReturn = null;
        final useCase = EnableReminders(repository, gateway);

        final outcome = await useCase('token-123');

        expect(outcome, EnableRemindersOutcome.permissionDenied);
        expect(repository.savedSubscription, isNull);
      },
    );

    test(
      'short-circuits to iosNeedsInstall without calling the gateway to '
      'subscribe or the repository',
      () async {
        final repository = _FakePushRepository();
        final gateway = _FakeWebPushGateway()
          ..environment = const PushEnvironment(
            supported: false,
            standalone: false,
            iosNeedsInstall: true,
          );
        final useCase = EnableReminders(repository, gateway);

        final outcome = await useCase('token-123');

        expect(outcome, EnableRemindersOutcome.iosNeedsInstall);
        expect(gateway.capturedVapidPublicKey, isNull);
        expect(repository.savedSubscription, isNull);
      },
    );

    test('short-circuits to unsupported when the platform lacks support', () async {
      final repository = _FakePushRepository();
      final gateway = _FakeWebPushGateway()
        ..environment = const PushEnvironment(
          supported: false,
          standalone: false,
          iosNeedsInstall: false,
        );
      final useCase = EnableReminders(repository, gateway);

      final outcome = await useCase('token-123');

      expect(outcome, EnableRemindersOutcome.unsupported);
      expect(gateway.capturedVapidPublicKey, isNull);
    });

    test(
      'iosNeedsInstall takes precedence over unsupported when both are true '
      '(design D3)',
      () async {
        final repository = _FakePushRepository();
        final gateway = _FakeWebPushGateway()
          ..environment = const PushEnvironment(
            supported: false,
            standalone: false,
            iosNeedsInstall: true,
          );
        final useCase = EnableReminders(repository, gateway);

        final outcome = await useCase('token-123');

        expect(outcome, EnableRemindersOutcome.iosNeedsInstall);
      },
    );

    test('propagates a PushReauthRequired from fetchVapidPublicKey', () async {
      final repository = _FakePushRepository()
        ..fetchError = const PushReauthRequired();
      final gateway = _FakeWebPushGateway();
      final useCase = EnableReminders(repository, gateway);

      expect(
        () => useCase('token-123'),
        throwsA(isA<PushReauthRequired>()),
      );
    });

    test('propagates a PushRequestFailed from saveSubscription', () async {
      final repository = _FakePushRepository()
        ..saveError = const PushRequestFailed();
      final gateway = _FakeWebPushGateway();
      final useCase = EnableReminders(repository, gateway);

      expect(
        () => useCase('token-123'),
        throwsA(isA<PushRequestFailed>()),
      );
    });
  });
}
