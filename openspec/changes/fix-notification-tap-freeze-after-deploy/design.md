## Context

See proposal.md — Why for the report and the three user-confirmed facts. What follows is the
state of the code those facts have to be reconciled with.

The notification-tap path, end to end, as it exists today:

```
push_sw.js notificationclick
  → caches.put('/pending', {path, savedAt})            (only if the payload had a path)
  → clients.matchAll({includeUncontrolled:true})
  → target.focus()  →  target.postMessage({})          (focus succeeded)
     else clients.openWindow('/')                      (focus rejected)

pending_deep_link_web.dart  handoverSignals
  ← serviceWorker 'message'   ← document 'visibilitychange' (visible)  ← window 'focus'
  → PendingDeepLinkController.check()
       gates: auth ready, not a transition screen, entry fresh (5 min), path recognized
  → app.dart _navigateToHandover → _popTo / push / pushReplacement

index.html, independently
  → navigator.serviceWorker.ready → registration.update() on load,
    on every visibilitychange→visible, and every 30 min
  → a newly installed worker behind a controlling one flips window.pwaUpdate.available
  → PwaUpdateController polls that flag every 15 s and shows the banner
  → applyUpdate() (banner button ONLY) → unregister Flutter's SW → location.reload()
```

Three constraints shape everything below:

- **Fact 3 is a measurement, not a symptom.** Recovery by backgrounding and returning means
  the UI isolate was alive the whole time and the app's state was intact. A wedged isolate, a
  crashed engine, or a lost route stack cannot be repaired by a foreground transition.
- **Fact 2 rules out "nothing is there".** Content was painted. Whatever the last frame drew
  is still on screen.
- **Fact 1 is a correlation the user observed, not a mechanism.** "Just deployed, not yet
  reloaded" is a strong hint, and the deploy-shaped work on that path is real
  (`registration.update()` fires from the very `visibilitychange` a tap produces), but nothing
  in the report proves the deploy *causes* the freeze rather than lengthening a window in
  which it is likely. The design must not assume more than that.

## Goals / Non-Goals

**Goals:**

- Reach a verdict on every candidate cause with evidence someone else can re-run, before
  changing product code.
- Make foregrounding restore interactivity as its own effect, not as a side effect of
  consuming a hand-over.
- Remove the two places where the tap path can be blocked: the update check on the
  foregrounding event, and the unbounded pop loops.

**Non-Goals:**

- Changing the D2 Cache hand-over contract between `push_sw.js` and
  `pending_deep_link_web.dart`, the `focus`/`postMessage`/`openWindow` ordering, or the
  gates in `PendingDeepLinkController`. Issue #193 / PR #221 settled those and they are
  guarded; nothing in this report implicates them.
- Building a diagnostics screen, an in-app log viewer, or telemetry. The on-device evidence
  this needs is obtainable with Chrome remote DevTools against the deployed build.
- Claiming an on-device reproduction. Every device step in tasks.md is the user's to run.

## Decisions

### D1 — Falsify first; the verdict table is part of the deliverable

Each candidate gets an explicit verdict backed by evidence that survives this change (a
committed test, or a command anyone can re-run). Hypotheses eliminated on paper are recorded
so the next person does not re-walk them.

| # | Hypothesis | Verdict | Evidence |
|---|---|---|---|
| H1 | `_popTo`'s `while` loop / the `popUntil` above it spin forever on the UI thread | **Real bug, NOT this one** | Both loops assume every pop removes a route. `Navigator.pop` is a no-op under `PopScope(canPop: false)` — one exists at `shared_food_item_sheet.dart:401` (`canPop: !submitting`), the only such site in `lib/` (`grep -rn "canPop: " lib/` → 1 hit). A widget test can drive it. Eliminated as *the* report by fact 3: a spinning UI isolate never yields, so no amount of backgrounding recovers it. |
| H2 | The boot splash (`#lifeos-splash`, `position:fixed; inset:0; z-index:2147483647`) is left covering the page and swallows every tap | **Eliminated** | It is opaque (`background-color: var(--lifeos-cream)`), so the symptom would be a cream screen, contradicting fact 2. It is also removed by a 600 ms `setTimeout` fallback independent of `transitionend`, and only ever exists before the first frame. |
| H3 | The offline bar (`#lifeos-offline`) covers the app | **Eliminated** | Geometry: it is a top strip (`top/left/right`, no `bottom`), `display:none` unless `navigator.onLine` is false. It cannot cover the content the user reports seeing. |
| H4 | `applyUpdate()` ran, unregistered the Flutter worker, and the page is a zombie waiting on `location.reload()` | **Eliminated for this report** | `pwaUpdate.apply()` has exactly one path to it: the banner's button (`pwa_update_banner.dart:51` → `PwaUpdateController.applyUpdate` → `PwaUpdateImpl.applyUpdate`). Fact 1 says the banner is not necessarily even visible. Nothing calls it automatically. |
| H5 | The new Flutter worker claimed the running page and old-hash assets now 404, hanging a lazy load | **Weakened, needs device evidence** | `grep -rn "deferred as" lib/` → 0 hits: there is no deferred/split Dart, so all app code is already parsed in the loaded `main.dart.js`. What remains lazily fetched is per-widget (images, font subsets), and a failure there is a broken picture, not a global input freeze. Cannot be fully closed without a DevTools network trace on the device. |
| H6 | **The frame pipeline is stalled.** The window is brought forward by `client.focus()` without a genuine `hidden → visible` transition reaching the engine (Chrome's freeze/resume on a backgrounded WebAPK, or a transition consumed before the engine re-attaches), so Flutter never schedules another frame. The DOM keeps showing the last painted frame; taps hit-test and mutate state, but nothing repaints, so the app *looks* dead. Backgrounding and returning forces a real transition, frames resume, and the queued state paints. | **Primary surviving hypothesis** | Fits all three facts, and fact 3 is what it predicts. Supported statically: `grep -rc scheduleFrame lib/` → 0 — the app has three foreground signals wired (`message`, `visibilitychange`, `focus`, `pending_deep_link_web.dart`) and every one of them is spent asking "is there a destination pending?"; when the answer is no, the code path ends, having never asked the engine to paint. Confirmation is on-device (task 5). |
| H7 | The deploy is causal via the update check | **Contributing, not sole** | `web/index.html` calls `checkForUpdate()` → `registration.update()` from the same `visibilitychange` a notification tap produces (3 call sites; one is that listener). On a fresh deploy that is a full worker install — download plus cache write — kicked off at the exact instant the user is trying to use the app. That plausibly widens the H6 window and explains fact 1 without being a freeze by itself. |

### D2 — Fix H6 where the signals already are, not in a new lifecycle layer

`pending_deep_link_web.dart` already owns the three foreground signals and already
demonstrated (design D7 of the earlier change) that no single one of them is reliable. The
fix belongs there and in the controller they feed: every such signal must produce a demand for
a frame, unconditionally and before any of the hand-over gates run — the gates are exactly
what swallow the signal today when nothing is pending.

Alternative considered — a lifecycle-only fix, e.g. reacting to `AppLifecycleState.resumed`:
rejected on the same evidence that motivated the multi-signal design. The reported case is the
one where no lifecycle transition arrives.

Alternative considered — forcing a repaint by rebuilding the tree (`setState` at the root):
rejected. A rebuild still needs a frame to be scheduled to show anything, so it does not
address the stall, and it discards scroll/focus/animation state for every screen on every
foregrounding.

### D3 — Move the update check off the foregrounding event, keep the check

`registration.update()` stays — the banner must still appear — but it must not run *as* the
foregrounding. Delay it behind the visible transition so the app paints and accepts input
first; keep the existing on-load and periodic checks unchanged. This addresses H7 without
weakening the update path, and it is independently correct regardless of which hypothesis
wins: the first thing a reminder tap triggers should not be a worker install.

### D4 — Bound the pops instead of special-casing the sheet

`_popTo` must terminate. The rule is structural, not per-screen: stop when a pop does not
change the stack. Reading the stack depth before and after each pop and stopping when it does
not shrink covers both loops' assumption and both refusal modes (a `PopScope` that declines,
and a route that is not a `GoRoute` and so never shrinks `matches`) without naming any screen.
The user-visible consequence, per the spec, is "left on a usable screen" — never a freeze.

Alternative considered — a fixed iteration cap: rejected. A magic number is a guess about
stack depth that goes wrong quietly in both directions; "the stack stopped changing" is the
actual invariant.

### D5 — On-device evidence is the user's, and the code change does not wait on it

H6's confirmation and H5's closure both need a real deploy, a real WebAPK, and a real push.
The three fixes (D2, D3, D4) are each independently justified by static evidence and are safe
if H6 turns out to be wrong — they add a frame request, defer a background check, and
terminate a loop. So they ship, and the device steps in tasks.md verify rather than gate them.
Nothing here is reported as verified on a device until the user says it is.

## Risks / Trade-offs

- **H6 is confirmed only by symptom fit until the device test runs** → The fixes are cheap,
  local, and harmless if it is wrong; task 5 records the actual result and task 6 revisits H5
  if the freeze survives.
- **Asking for a frame on every visibility/focus event costs work on a page that was fine
  anyway** → One frame per foregrounding, on an app that already runs a periodic update poll
  and a hand-over store read on the same events. Not a regression worth trading a freeze for.
- **Deferring the update check slightly delays the banner after a deploy** → The banner is
  already polled on a 15 s interval and re-checked on resume; a short delay after
  foregrounding changes nothing a user can perceive, and the on-load and periodic checks are
  untouched.
- **Bounding the pop loop can leave the user above the destination** when a screen refuses to
  be dismissed → That is the specified behavior (an unchanged, usable screen) and strictly
  better than the freeze it replaces. The ordinary path is guarded by its own scenario so the
  bound cannot silently stop the normal case short.
- **The deploy correlation may be a red herring** and the freeze may be reproducible without a
  deploy at all → Task 5 asks the user to try both, so a negative result is informative
  rather than ambiguous.

## Open Questions

- Whether H5 needs a follow-up (asset 404s after a mid-session worker activation) depends
  entirely on the device trace in task 5. It cannot change the specs or the fixes above, so it
  is deferrable: if the freeze survives them, it becomes its own issue with a network trace
  attached.
