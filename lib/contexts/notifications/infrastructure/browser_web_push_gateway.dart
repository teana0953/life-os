import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import '../domain/push_subscription.dart';
import '../domain/web_push_gateway.dart';

/// The `window.pwaInstall` bridge object defined in `web/index.html`
/// (mirrors `PwaInstallImpl`'s binding), read directly here because
/// `iosHint` feeds straight into [PushEnvironment].
@JS('pwaInstall')
external _PwaInstallBridge? get _installBridge;

extension type _PwaInstallBridge(JSObject _) implements JSObject {
  external bool get iosHint;
}

/// [WebPushGateway] driven adapter: the real, on-device browser glue — SW
/// registration at the scoped `/push/` path (design D2), Notification
/// permission, and `pushManager.subscribe`. NOT exercised by `flutter test`;
/// kept deliberately thin, with no business logic (design D1).
class BrowserWebPushGateway implements WebPushGateway {
  const BrowserWebPushGateway();

  @override
  PushEnvironment describeEnvironment() {
    final bridge = _installBridge;
    final window = web.window;
    // Feature detection. iOS Safari hides `PushManager` until the app is
    // installed, so `iosNeedsInstall` (read independently from the UA-based
    // bridge above) MUST be checked by the caller BEFORE `supported`
    // (design D3).
    final supported =
        window.navigator.has('serviceWorker') &&
        window.has('PushManager') &&
        window.has('Notification');
    return PushEnvironment(
      supported: supported,
      iosNeedsInstall: bridge?.iosHint ?? false,
    );
  }

  @override
  PushPermissionStatus permissionStatus() {
    switch (web.Notification.permission) {
      case 'granted':
        return PushPermissionStatus.granted;
      case 'denied':
        return PushPermissionStatus.denied;
      default:
        return PushPermissionStatus.prompt;
    }
  }

  @override
  Future<PushSubscription?> enableAndSubscribe(String vapidPublicKey) async {
    final permission = await web.Notification.requestPermission().toDart;
    if (permission.toDart != 'granted') return null;

    // A narrower scope than the script's own location — `/push/` for
    // `web/push_sw.js`, served at `/` — is always allowed and creates an
    // independent registration that never controls `/`-scoped app pages, so
    // it can't clobber Flutter's own service worker (design D2). The
    // subscription is created on this registration.
    final registration = await web.window.navigator.serviceWorker
        .register('push_sw.js'.toJS, web.RegistrationOptions(scope: '/push/'))
        .toDart;

    // First-run race: register() resolves while the worker is still installing,
    // but pushManager.subscribe needs an ACTIVE worker — otherwise the very
    // first "enable" tap throws and only a retry (worker now active) succeeds.
    await _whenActivated(registration);

    final subscription = await registration.pushManager
        .subscribe(
          web.PushSubscriptionOptionsInit(
            userVisibleOnly: true,
            applicationServerKey: _base64UrlToBytes(vapidPublicKey).toJS,
          ),
        )
        .toDart;

    return PushSubscription(
      endpoint: subscription.endpoint,
      p256dh: _keyToBase64Url(subscription.getKey('p256dh')),
      auth: _keyToBase64Url(subscription.getKey('auth')),
    );
  }
}

/// Resolves once [registration] has an active service worker. On the first
/// registration the worker is still `installing`/`waiting` when `register()`
/// resolves; we wait for its `statechange` to `activated` before subscribing.
Future<void> _whenActivated(web.ServiceWorkerRegistration registration) async {
  if (registration.active != null) return;
  final worker = registration.installing ?? registration.waiting;
  if (worker == null) return;
  final completer = Completer<void>();
  late final JSFunction listener;
  void check() {
    if (worker.state == 'activated' && !completer.isCompleted) completer.complete();
  }

  listener = ((web.Event _) => check()).toJS;
  worker.addEventListener('statechange', listener);
  check();
  await completer.future;
  worker.removeEventListener('statechange', listener);
}

/// Decodes a base64url-encoded VAPID public key (as returned by the backend)
/// into the raw bytes `pushManager.subscribe` expects for
/// `applicationServerKey`.
Uint8List _base64UrlToBytes(String value) {
  final padLength = (4 - value.length % 4) % 4;
  return base64Url.decode(value + ('=' * padLength));
}

/// Encodes a subscription key (`ArrayBuffer`, from `PushSubscription.getKey`)
/// as base64url — the form the backend stores/uses. A missing key means the
/// subscription is malformed, so this fails visibly rather than sending an
/// empty p256dh/auth to the backend.
String _keyToBase64Url(JSArrayBuffer? buffer) {
  if (buffer == null) throw StateError('missing push subscription key');
  return base64Url.encode(buffer.toDart.asUint8List()).replaceAll('=', '');
}
