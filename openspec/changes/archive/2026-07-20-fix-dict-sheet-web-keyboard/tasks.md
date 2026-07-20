# Tasks — Dictionary sheet keyboard inset (Flutter web)

## 1. Keyboard-inset helper (conditional import)
- [x] 1.1 New module (e.g. `lib/shared/platform/keyboard_inset.dart`) exporting a
      `KeyboardInsetBuilder(builder: (context, double bottomInset) => …)` widget,
      with a conditional import
      `export 'keyboard_inset_io.dart' if (dart.library.js_interop) 'keyboard_inset_web.dart';`.
      Add an optional injectable override (a provider/notifier) so widget tests
      can drive the inset on native.
- [x] 1.2 Pure function `double computeKeyboardInset({required double layoutHeight,
      required double viewportHeight, required double offsetTop})` =
      `(layoutHeight - viewportHeight - offsetTop).clamp(0.0, double.infinity)`,
      in the shared file (testable on native).
- [x] 1.3 Native stub (`keyboard_inset_io.dart`): inset =
      `MediaQuery.of(context).viewInsets.bottom` (0 inside a resized Scaffold
      body) — no native behavior change.
- [x] 1.4 Web impl (`keyboard_inset_web.dart`, `package:web` + `dart:js_interop`):
      subscribe to `window.visualViewport` `resize` (+`scroll`); on each, compute
      the inset via `computeKeyboardInset` and push to the builder. Add listeners
      in `initState`, **remove them in `dispose`** (same callback ref). Add `web`
      to `pubspec.yaml` dependencies if not already direct.

## 2. Apply to the dictionary results list
- [x] 2.1 `dictionary_screen.dart`: wrap the results list so its
      `ListView.builder` padding is `EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset)`
      from the helper; search field stays pinned at top. Do NOT touch
      `resizeToAvoidBottomInset` (per design D3 — native reads 0, web is the only
      source; changing resize risks the native path).

## 3. Tests (the testable parts)
- [x] 3.1 Unit test `computeKeyboardInset`: no keyboard → 0; keyboard occupies
      bottom → positive; offsetTop > 0 subtracted; over-subtract clamps to 0.
- [x] 3.2 Widget test (native): dictionary sheet with `viewInsets == 0` keeps the
      list's original bottom padding (zero-impact / no regression). With an
      injected fake inset `N`, the list bottom padding becomes `16 + N` (wiring
      exercised deterministically on native). Do NOT fake-verify browser keyboard
      behavior.

## 4. Verify
- [x] 4.1 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
- [x] 4.2 `flutter build web` compiles (interop errors often only surface in the
      web build).

> Acceptance note: the real web keyboard behavior (search results actually
> reachable above the on-screen keyboard) is verified by the user **on-device
> after deploy** — it cannot be exercised by widget tests. If it misbehaves,
> iterate with the observed `visualViewport` values.
