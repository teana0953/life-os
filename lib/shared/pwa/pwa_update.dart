/// A UI-agnostic, injectable view over the browser's PWA update state.
///
/// Reads the small `window.pwaUpdate` bridge exposed by `web/index.html`,
/// which flips `available` to `true` once a new service-worker version has
/// installed while an old one is still controlling the page. The concrete
/// implementation is resolved by conditional import: the web impl on web
/// builds, a no-op stub everywhere else (mobile/desktop/VM tests) so those
/// targets still compile. Widget tests inject a fake instead.
library;

export 'pwa_update_stub.dart'
    if (dart.library.js_interop) 'pwa_update_web.dart';

abstract class PwaUpdate {
  /// A newer version of the app has been downloaded in the background and is
  /// ready to be loaded (needs a reload to take effect).
  bool get updateAvailable;

  /// Reliably loads the new version: best-effort skip-waiting, then
  /// unregisters the service workers and reloads. No-op when nothing is
  /// waiting.
  Future<void> applyUpdate();
}
