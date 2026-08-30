## Why

Tapping a care notification on the installed Android PWA (WebAPK) brings the app forward showing
its last painted frame, and it never repaints or responds to touch again until the user switches
to another app and back. This has been "fixed" three times by reasoning (#80, #193, #226 /
PR #221, PR #229) and is still broken. It is now **measured on device**, and the measurement
contradicts the fix that shipped:

- Frozen, via `chrome://inspect` on the WebAPK: `document.visibilityState === 'visible'`,
  `document.hasFocus() === true`, and `requestAnimationFrame` callbacks fire normally. The
  browser *is* handing out frames; Flutter is choosing not to draw.
- With a probe armed before backgrounding, the console after a freeze reads
  `probe armed / BLUR / VIS hidden / SW MSG {}`. Going away fires `blur` and
  `visibilitychange`→hidden. **Coming back fires neither `visibilitychange` nor `focus`** — only
  the worker's `postMessage` arrives. (That message arrives only after `target.focus()` resolves
  in `push_sw.js`, so `focus()` succeeded and the `openWindow` branch was not taken.)
- While frozen, running `document.dispatchEvent(new Event('visibilitychange'))` and
  `window.dispatchEvent(new Event('focus'))` by hand revives the app instantly.

So the platform behaviour is nameable: **an Android WebAPK returning to the foreground from a
notification tap flips `visibilityState` to `visible` without dispatching `visibilitychange`, and
dispatches no `focus`.** The Flutter web engine's own `visibilitychange` listener — the one that
drives `AppLifecycleState` — therefore never runs, the engine stays in a non-resumed state, and
`SchedulerBinding.framesEnabled` stays `false`.

That is exactly why #226's fix does nothing. `demandForegroundFrame()` calls
`binding.scheduleFrame()`, which returns immediately when `framesEnabled == false`, then
`platformDispatcher.scheduleFrame()`, which can force at most one frame — after which every
`setState` is dropped again. The mechanism was already described correctly in the doc comment on
`demandForegroundFrame()`; the remedy chosen was the wrong one. Asking for a frame does not fix a
lifecycle that is stuck.

## What Changes

- On a hand-over signal, the web adapter dispatches the synthetic DOM events the Flutter engine
  itself listens for (`visibilitychange` on `document`, `focus` on `window`), so the engine's own
  lifecycle listener runs and pushes `AppLifecycleState.resumed` — automating exactly what
  measurement three did by hand. This is **the only remedy with on-device evidence**, and it is
  the one this change ships.
- The synthetic-event approach depends on an engine implementation detail. That dependency is
  made explicit in code comments (what the engine listens for, why a synthetic event and not a
  real API, and what to check if a Flutter upgrade breaks it) and pinned by a test.
- `demandForegroundFrame()` is re-decided rather than assumed: design.md states whether the two
  `scheduleFrame` calls still do anything once the lifecycle is genuinely resumed, and the code
  follows that verdict (kept with a stated reason, or deleted with its seam).
- A cleaner alternative — pushing `AppLifecycleState.resumed` over the `flutter/lifecycle`
  channel via `ServicesBinding.instance.channelBuffers` — is recorded as a **rejected-for-now**
  option in design.md with the evidence it would need. It is not shipped: it has never been
  measured on a device, and this bug has already cost three unmeasured fixes.
- Device-verification steps become part of the change's acceptance, not an afterthought: the
  freeze only exists against a real WebAPK, so no VM test can close this issue.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `reminder-notifications-ui`: the requirement "A notification tap leaves the app usable, not
  just on the right screen" is strengthened from "the app asks to be painted" to "the app's
  lifecycle is restored to foreground, so it keeps painting" — one repaint is not
  responsiveness, and the requirement as written was satisfiable by a fix that measurably does
  not work. New scenarios cover repainting *after* the arrival frame and the specific platform
  case where no visibility or focus event is dispatched at all.

## Impact

- `lib/shared/pwa/pending_deep_link.dart` — the injectable foreground effect
  (`demandForegroundFrame`) and its doc comment; possibly renamed/replaced by a
  lifecycle-restoring effect.
- `lib/shared/pwa/pending_deep_link_web.dart` — web-only adapter (conditional import,
  unreachable from VM tests) where the synthetic events are dispatched.
- `lib/shared/pwa/pending_deep_link_stub.dart` — no behaviour change expected; checked for
  signature drift.
- `lib/app.dart` — the composition root's `onForegrounded` default (~line 431).
- `test/app_pending_deep_link_test.dart`,
  `test/shared/pwa/pending_deep_link_controller_test.dart` — guards for the seam, with mutation
  verification.
- **Unchanged:** `web/push_sw.js`. The Cache Storage hand-over contract and the
  `focus`/`postMessage`/`openWindow` ordering are a two-language single source of truth and the
  measurement shows they work; touching them is out of scope.
- Real acceptance is on-device (installed Android WebAPK + `chrome://inspect`). No CI signal can
  prove this fixed.
