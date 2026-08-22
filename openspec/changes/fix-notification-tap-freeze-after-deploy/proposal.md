## Why

Issue #226: after a new version is deployed, a still-open app window that has not been
reloaded yet becomes **unresponsive when brought forward by a notification tap** — the screen
still shows content, but nothing reacts to touch. Backgrounding the app and returning to it
restores it. This is a regression window that opens on every deploy, and it hits exactly the
users who kept the app open — the ones reminders are for. Issue #193 / PR #221 fixed *where*
a notification tap lands; this is about the app being usable once it lands.

The three facts the user confirmed bound the search:

1. **Trigger**: a new version was just deployed and this window has not reloaded since. The
   update banner is not necessarily on screen.
2. **Shape**: content is painted, but taps do nothing. Not a blank page, not a spinner.
3. **Recovery**: switching to another app and back fixes it. No reload needed.

Fact 3 is the sharpest instrument: a recovery that costs nothing but a foreground transition
means the app's state is intact and its UI isolate is *not* wedged — whatever went wrong is
undone by the browser producing a genuine `hidden → visible` transition. That rules out a
whole class of "it hung" explanations before any code is written, and it is why this change
starts by falsifying hypotheses rather than by patching the most suspicious-looking code.

## What Changes

- **Falsify before fixing.** Each candidate cause named in the investigation surface
  (`web/push_sw.js`, `web/index.html`, `lib/shared/pwa/pending_deep_link_*.dart`,
  `lib/app.dart`'s `_navigateToHandover` / `_popTo`) is either eliminated by evidence that can
  be re-run, or carried forward. design.md records the verdict and the evidence for each.
- **Foregrounding always yields an interactive frame.** Today the app treats becoming visible
  purely as a *hand-over* signal: it reads the pending-destination store and, finding nothing,
  stops. Nothing ever asks the engine to paint. The app SHALL make being brought to the
  foreground restore interactivity on its own, whether or not a destination was pending and
  whether or not the browser delivered a lifecycle transition.
- **The version check stops competing with the tap.** `web/index.html` calls
  `registration.update()` from the same `visibilitychange` that a notification tap produces,
  which is precisely the deploy-shaped moment in fact 1. That check SHALL be moved off the
  foregrounding path so downloading a new version is never the first thing that happens when
  the user taps a reminder.
- **`_popTo` can no longer spin forever.** Its `while` loop and the `popUntil` above it both
  assume every pop removes a route; a route that declines to pop (`PopScope(canPop: false)` —
  `shared_food_item_sheet.dart` has one) makes both loops non-terminating on the UI thread.
  This is **not** the reported bug (fact 3 rules it out — a pegged isolate does not recover on
  resume) but it is a real freeze with the same on-screen shape, reachable from the same code
  path, and it is cheap to bound.
- **On-device confirmation is called out as the user's, not ours.** The reproduction depends
  on a real deploy, a real WebAPK, and a real push. Every step that needs a device is marked
  as requiring user verification and is never claimed as verified here.

No new user-visible UI, no new strings, no backend change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `reminder-notifications-ui`: adds requirements that a notification tap leaves the app
  **usable**, not merely on the right screen — the app recovers interactivity when
  foregrounded regardless of which browser signal arrived, navigation to a handed-over
  destination never blocks the UI thread, and checking for a new app version never runs as
  part of foregrounding.

## Impact

- `lib/shared/pwa/pending_deep_link_web.dart` — the visibility/focus/message signals it
  already owns.
- `lib/shared/pwa/pending_deep_link_controller.dart` — the foreground path that currently
  ends in "nothing pending, stop".
- `lib/app.dart` — `_navigateToHandover` / `_popTo` loop bounds.
- `web/index.html` — when `registration.update()` runs.
- `test/shared/pwa/*`, `test/app_pending_deep_link_test.dart` — falsification and regression
  guards.
- Not touched: `web/push_sw.js`'s hand-over contract (the D2 Cache protocol and the
  focus/postMessage/openWindow ordering are load-bearing and already guarded), the backend,
  and every localized string.
