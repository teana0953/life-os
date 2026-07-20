// TEMPORARY on-screen keyboard/viewport metrics readout for debugging the
// Flutter-web dictionary-sheet keyboard occlusion on-device (the phone browser
// has no visible console). Conditional import: the web build shows the live
// `window.visualViewport` / `innerHeight` numbers; native shows the
// `MediaQuery` insets. Remove once the keyboard fix is verified on-device.
export 'keyboard_metrics_io.dart'
    if (dart.library.js_interop) 'keyboard_metrics_web.dart';
