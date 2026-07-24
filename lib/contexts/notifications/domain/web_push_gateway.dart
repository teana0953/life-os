import 'push_subscription.dart';

/// The browser environment relevant to enabling Web Push.
class PushEnvironment {
  final bool supported;
  final bool standalone;
  final bool iosNeedsInstall;

  const PushEnvironment({
    required this.supported,
    required this.standalone,
    required this.iosNeedsInstall,
  });
}

enum PushPermissionStatus { granted, denied, prompt }

/// Port isolating the browser-specific Web Push glue (permission prompt, SW
/// registration, `pushManager.subscribe`) behind an interface so the
/// controller/use cases stay testable with a fake (design D1).
/// `BrowserWebPushGateway` is the real, on-device-verified adapter — not
/// exercised by `flutter test`. No `unsubscribe()` (YAGNI, later slice).
abstract class WebPushGateway {
  /// Reads the environment: whether the platform supports Web Push, whether
  /// the app is already installed/standalone, and whether it needs to be
  /// added to the Home Screen first. Callers MUST check [PushEnvironment.
  /// iosNeedsInstall] BEFORE [PushEnvironment.supported] — on iOS Safari,
  /// `PushManager` is hidden until the app is installed, so `supported` is
  /// (correctly) false there even on push-capable devices (design D3).
  PushEnvironment describeEnvironment();

  PushPermissionStatus permissionStatus();

  /// Requests notification permission and, on grant, registers the push
  /// service worker and subscribes. Returns the subscription, or `null` if
  /// the user denies permission.
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey);
}
