import 'push_subscription.dart';

/// Thrown by a push repository when the backend rejects the lifeos ID token
/// (HTTP 401) — the caller must sign in again.
class PushReauthRequired implements Exception {
  const PushReauthRequired();
}

/// Thrown by a push repository for any other non-2xx response, network
/// error, or unparseable body.
class PushRequestFailed implements Exception {
  const PushRequestFailed();
}

/// The outcome of a test push: how many subscriptions it was sent to
/// successfully and how many failed.
class TestPushResult {
  final int sent;
  final int failed;

  const TestPushResult({required this.sent, required this.failed});
}

/// Port for the backend's `/api/push/*` Web Push endpoints. No
/// `deleteSubscription` — this slice has no disable action (YAGNI; lands
/// with the disable UI later).
abstract class PushRepository {
  Future<String> fetchVapidPublicKey(String idToken);

  Future<void> saveSubscription(
    String idToken,
    PushSubscription subscription,
  );

  Future<TestPushResult> sendTest(String idToken);
}
