import 'package:flutter_test/flutter_test.dart';
import 'package:life_os/contexts/notifications/application/send_test_push.dart';
import 'package:life_os/contexts/notifications/domain/push_repository.dart';
import 'package:life_os/contexts/notifications/domain/push_subscription.dart';

class _FakePushRepository implements PushRepository {
  Object? sendTestError;
  TestPushResult result = const TestPushResult(sent: 2, failed: 1);
  String? capturedIdToken;

  @override
  Future<String> fetchVapidPublicKey(String idToken) =>
      throw UnimplementedError();

  @override
  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  ) => throw UnimplementedError();

  @override
  Future<TestPushResult> sendTest(String idToken) async {
    capturedIdToken = idToken;
    if (sendTestError != null) throw sendTestError!;
    return result;
  }
}

void main() {
  group('SendTestPush', () {
    test('passes through the repository\'s sent/failed result', () async {
      final repository = _FakePushRepository();
      final useCase = SendTestPush(repository);

      final result = await useCase('token-123');

      expect(repository.capturedIdToken, 'token-123');
      expect(result.sent, 2);
      expect(result.failed, 1);
    });

    test('propagates a PushReauthRequired from the repository', () async {
      final repository = _FakePushRepository()
        ..sendTestError = const PushReauthRequired();
      final useCase = SendTestPush(repository);

      expect(() => useCase('token-123'), throwsA(isA<PushReauthRequired>()));
    });

    test('propagates a PushRequestFailed from the repository', () async {
      final repository = _FakePushRepository()
        ..sendTestError = const PushRequestFailed();
      final useCase = SendTestPush(repository);

      expect(() => useCase('token-123'), throwsA(isA<PushRequestFailed>()));
    });
  });
}
