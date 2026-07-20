/// Keyboard-inset helper (design.md D1): exposes the current bottom
/// keyboard inset (logical px) to the widget tree via `KeyboardInsetBuilder`,
/// split by platform through a conditional export. On native platforms the
/// inset is read from `MediaQuery.viewInsets.bottom` (a no-op inside a
/// resized `Scaffold`); on web it's derived from the browser's visual
/// viewport, which the layout viewport doesn't otherwise account for.
library;

export 'keyboard_inset_calc.dart';
export 'keyboard_inset_io.dart'
    if (dart.library.js_interop) 'keyboard_inset_web.dart';
