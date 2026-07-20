# Design — Dictionary sheet keyboard inset (Flutter web)

## Context

The add-food dictionary sheet is `_DictionarySheet` (in `diet_shell_screen.dart`)
opened via `showModalBottomSheet(isScrollControlled: true)` wrapped in a
`FractionallySizedBox(heightFactor: 0.9)`. Its body is a `Scaffold`;
`DictionaryScreen` (in `dictionary_screen.dart`) is itself a
`Scaffold(body: SafeArea(Column[ …search TextField (pinned) …,
Expanded(ListView.builder(padding: EdgeInsets.all(16))) ]))`. On a phone the
app runs as Flutter **web**. When the search field is focused the browser
raises the on-screen keyboard, which on web resizes the **visual viewport**
(not the layout viewport); Flutter's `MediaQuery.viewInsets.bottom` stays 0, so
the `Scaffold` doesn't resize and the bottom of the results list sits behind
the keyboard, unreachable. (Confirmed by `fix-diet-mobile-ux`'s QA: a
`viewInsets.bottom`-based padding is a no-op on web.) Follow the frontend
CLAUDE.md.

## Decisions

### D1 — Keyboard-inset helper (conditional import)

A small module exposing the current bottom keyboard inset (logical px) to the
widget tree, split by platform via a conditional import
(`export 'keyboard_inset_io.dart' if (dart.library.js_interop)
'keyboard_inset_web.dart';`):

- **Shared API**: a `KeyboardInsetBuilder({required Widget Function(BuildContext,
  double bottomInset) builder})` widget (or an `InheritedWidget`/`ValueListenable`
  the list can read). It also accepts an optional injected override so widget
  tests can drive the inset value on native (see Testing).
- **Native/non-web stub** (`keyboard_inset_io.dart`, the default): the inset is
  `MediaQuery.of(context).viewInsets.bottom`. Inside the already-resized
  `Scaffold` body this is 0, so native behavior is unchanged.
- **Web** (`keyboard_inset_web.dart`, `package:web` + `dart:js_interop`):
  subscribes to `web.window.visualViewport`'s `resize` (and `scroll`) events;
  on each, computes the inset via the pure function below and pushes it to the
  builder (via a `ValueNotifier` + `setState`, or `ValueListenableBuilder`).
  Listeners are added in `initState` and **removed in `dispose`** (pair
  `addEventListener`/`removeEventListener` with the same JS callback ref).
- **Pure function** (in the shared file so it's testable on native):
  ```dart
  double computeKeyboardInset({
    required double layoutHeight,   // window.innerHeight (or MediaQuery size.height)
    required double viewportHeight, // visualViewport.height
    required double offsetTop,      // visualViewport.offsetTop
  }) => (layoutHeight - viewportHeight - offsetTop).clamp(0.0, double.infinity);
  ```
  Use `window.innerHeight` for `layoutHeight` (same browser source as
  `visualViewport.height`/`offsetTop`) so the subtraction is apples-to-apples —
  do **not** mix in `MediaQuery.size`, whose logical-pixel basis can differ.

### D2 — Apply the inset to the results list

In `dictionary_screen.dart`, the results `ListView.builder`'s padding becomes
`EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset)` where `bottomInset` comes
from the helper. The search field stays pinned at the top of the Column
(outside the scroll view), so raising the keyboard never hides it; the results
scroll, and the extra bottom padding lets the last item scroll up into the
visible (visual-viewport) area above the keyboard.

### D3 — Avoid double-counting the inset

Only one source of the inset must apply at a time:
- **Native**: the outer `Scaffold`(s) already resize for the keyboard, so the
  helper (reading `viewInsets.bottom` within the resized body) returns 0 → the
  list padding is unchanged. No double count. Leave native resize behavior
  as-is.
- **Web**: `viewInsets.bottom` is 0 and the Scaffolds don't resize, so the only
  inset is the visualViewport one we add as padding — no double count.
- **Default: do NOT touch `resizeToAvoidBottomInset`.** Changing it risks
  altering the native path (the native stub reads `viewInsets` through the same
  Scaffolds). Only if on-device testing later shows a genuine double-count on
  web should we revisit it — and then guarded to web, not applied blindly. This
  change ships without that toggle.

## Testing

- **Unit** — `computeKeyboardInset`: no keyboard (viewportHeight == layoutHeight,
  offsetTop 0 → 0); keyboard occupies the bottom (→ positive); viewport scrolled
  up (offsetTop > 0 subtracted); over-subtraction clamps to 0.
- **Widget (native, no real web path)** — the dictionary sheet with
  `viewInsets == 0` renders the results list with its original bottom padding
  (helper adds 0): asserts **native zero-impact / no regression**. Plus, by
  injecting a fake inset provider (the helper's optional override), assert the
  list's bottom padding becomes `16 + N` for an injected `N` — this exercises
  the padding wiring deterministically on native without pretending to test the
  browser keyboard.
- **Not tested here (inherent)** — the actual web keyboard behavior: the
  `visualViewport` event wiring and real occlusion are verified by the user
  on-device after deploy. `flutter build web` must compile (interop errors
  often only surface there) — run it in apply as an extra check.
