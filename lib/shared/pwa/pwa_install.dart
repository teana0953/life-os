/// A UI-agnostic, injectable view over the browser's PWA install state.
///
/// Reads the small `window.pwaInstall` bridge exposed by `web/index.html`.
/// The concrete implementation is resolved by conditional import: the web
/// impl on web builds, a no-op stub everywhere else (mobile/desktop/VM tests)
/// so those targets still compile. Widget tests inject a fake instead.
library;

export 'pwa_install_stub.dart'
    if (dart.library.js_interop) 'pwa_install_web.dart';

abstract class PwaInstall {
  /// A `beforeinstallprompt` event is pending — an install prompt can be shown
  /// (Android/desktop Chromium).
  bool get canInstall;

  /// iOS Safari, which has no `beforeinstallprompt`; the user must add to the
  /// home screen manually, so show an instruction instead of a button.
  bool get isIosHint;

  /// The app is already running as an installed/standalone PWA — nothing to
  /// install.
  bool get isStandalone;

  /// Triggers the stashed browser install prompt. No-op when not [canInstall].
  Future<void> promptInstall();
}
