import '../domain/push_repository.dart';
import '../domain/web_push_gateway.dart';

enum EnableRemindersOutcome {
  enabled,
  permissionDenied,
  unsupported,
  iosNeedsInstall,
}

/// Enables reminders: checks the environment first — [PushEnvironment.
/// iosNeedsInstall] BEFORE [PushEnvironment.supported] (design D3) — then
/// fetches the VAPID key, asks the gateway to subscribe, and, if the user
/// grants permission, saves the subscription to the backend.
class EnableReminders {
  final PushRepository _repository;
  final WebPushGateway _gateway;

  EnableReminders(this._repository, this._gateway);

  Future<EnableRemindersOutcome> call(String idToken) async {
    final env = _gateway.describeEnvironment();
    if (env.iosNeedsInstall) return EnableRemindersOutcome.iosNeedsInstall;
    if (!env.supported) return EnableRemindersOutcome.unsupported;

    final vapidPublicKey = await _repository.fetchVapidPublicKey(idToken);
    final subscription = await _gateway.enableAndSubscribe(vapidPublicKey);
    if (subscription == null) return EnableRemindersOutcome.permissionDenied;

    await _repository.saveSubscription(idToken, subscription);
    return EnableRemindersOutcome.enabled;
  }
}
