import 'dart:js_interop';

import 'pwa_update.dart';

/// The `window.pwaUpdate` bridge object defined in `web/index.html`.
@JS('pwaUpdate')
external _PwaUpdateBridge? get _bridge;

extension type _PwaUpdateBridge(JSObject _) implements JSObject {
  external bool get available;
  external JSPromise apply();
}

/// Web implementation reading the live `window.pwaUpdate` bridge. `available`
/// reflects the bridge's current state (it flips to `true` asynchronously once
/// a new service worker has installed behind a controlling one), so the poller
/// re-reads the correct value.
class PwaUpdateImpl implements PwaUpdate {
  const PwaUpdateImpl();

  @override
  bool get updateAvailable => _bridge?.available ?? false;

  @override
  Future<void> applyUpdate() async {
    final bridge = _bridge;
    if (bridge == null) return;
    await bridge.apply().toDart;
  }
}
