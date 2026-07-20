# Keep dictionary-sheet search results above the keyboard (Flutter web)

## Why

On a phone (the app runs as Flutter **web** on Cloudflare Pages), focusing the
add-food dictionary sheet's search field raises the browser's on-screen
keyboard, which covers the results list — the user can't see or scroll to the
results below the fold. This was the 5th mobile issue reported during
on-device testing, descoped from `fix-diet-mobile-ux` because it is
**Flutter-web-specific**: on web the on-screen keyboard is handled by the
browser's *visual viewport*, and `MediaQuery.viewInsets.bottom` typically
reports 0 (the `Scaffold` never resizes), so the naive "add `viewInsets.bottom`
padding" fix is a no-op. It needs a web-side fix that reads the actual keyboard
overlap from the browser.

## What Changes

- A **keyboard-inset helper** with a conditional (web vs. non-web) import:
  - Native/non-web: reports `MediaQuery.viewInsets.bottom` (0 inside an
    already-resized `Scaffold` body) — **no behavior change** on native.
  - Web: listens to `window.visualViewport` resize/scroll and computes the
    keyboard overlap (`layout height − viewport height − viewport offset`),
    exposing it to the widget tree.
- The dictionary results list adds that keyboard inset to its **bottom
  padding**, so the last results can be scrolled up above the keyboard. The
  search field stays pinned at the top.
- The pure inset math is a small testable function; the web event wiring
  cannot be exercised by widget tests.

## Impact

- Affected spec: `health-diet` — narrow-screen requirement (MODIFIED) to add
  that dictionary search results stay reachable above the on-screen keyboard.
- Affected code: a new keyboard-inset helper (conditional import; likely
  `lib/shared/…`), `dictionary_screen.dart` (results-list bottom padding),
  possibly `diet_shell_screen.dart` (`_DictionarySheet` resize handling to
  avoid double-counting). `pubspec.yaml` may gain `web` as a direct dependency.
  Frontend only.
- **Verification note**: the real web keyboard behavior can only be confirmed
  by the user on-device after deploy (widget tests cover native no-op + the
  pure math + the padding wiring, not the browser keyboard). This is inherent
  to the platform issue.
