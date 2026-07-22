import 'dart:js_interop';

import 'pwa_install.dart';

/// The `window.pwaInstall` bridge object defined in `web/index.html`.
@JS('pwaInstall')
external _PwaInstallBridge? get _bridge;

extension type _PwaInstallBridge(JSObject _) implements JSObject {
  external bool get available;
  external bool get iosHint;
  external bool get standalone;
  external JSPromise prompt();
}

/// Web implementation reading the live `window.pwaInstall` bridge. Each getter
/// reflects the bridge's current state (it mutates as `beforeinstallprompt` /
/// `appinstalled` fire), so the Settings UI re-reads correct values on build.
class PwaInstallImpl implements PwaInstall {
  const PwaInstallImpl();

  @override
  bool get canInstall => _bridge?.available ?? false;

  @override
  bool get isIosHint => _bridge?.iosHint ?? false;

  @override
  bool get isStandalone => _bridge?.standalone ?? false;

  @override
  Future<void> promptInstall() async {
    final bridge = _bridge;
    if (bridge == null) return;
    await bridge.prompt().toDart;
  }
}
