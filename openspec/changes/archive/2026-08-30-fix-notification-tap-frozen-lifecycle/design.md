## Context

See proposal.md — Why for the three on-device measurements. This section is only the code and
engine state those measurements have to be reconciled with.

The measurements narrow the fault to one seam, and the engine source in the installed SDK
closes it. `flutter/bin/cache/flutter_web_sdk/lib/_engine/engine/platform_dispatcher/app_lifecycle_state.dart`
(`_BrowserAppLifecycleState`) is the whole of Flutter web's lifecycle input:

```
activate():
  window  'focus'           → onAppLifecycleStateChange(resumed)
  window  'blur'            → onAppLifecycleStateChange(inactive)
  document 'visibilitychange' → visible ? resumed : hidden ? hidden : (ignored)

onAppLifecycleStateChange(s): if (s != _appLifecycleState) { _appLifecycleState = s; notify }
```

There is no polling and no other source. The engine never reads `document.visibilityState`
except from inside that `visibilitychange` listener, so a `visibilityState` that changes
without an event is invisible to it — which is precisely the measured WebAPK behaviour.

Downstream, in `packages/flutter/lib/src/scheduler/binding.dart`:

- `handleAppLifecycleStateChanged` (line 415) returns early when the state is unchanged, then
  maps `resumed`/`inactive` → `_setFramesEnabledState(true)` and `hidden`/`paused`/`detached`
  → `_setFramesEnabledState(false)`.
- `_setFramesEnabledState` (line 877) is itself deduped, and **calls `scheduleFrame()` when it
  enables frames**.
- `scheduleFrame` (line 949) is `if (_hasScheduledFrame || !framesEnabled) return;`.

Put together with measurement two (`BLUR` then `VIS hidden` on the way out, nothing on the way
back), the frozen state is fully determined: `blur` → `inactive`, `visibilitychange`→hidden →
`hidden` → `framesEnabled = false`. Coming back, no event is dispatched, so the engine stays at
`hidden` forever. `WidgetsBinding.scheduleFrame()` returns at the `!framesEnabled` guard,
`platformDispatcher.scheduleFrame()` bypasses the framework and yields at most one frame, and
every later `setState` dies at the same guard. That is `demandForegroundFrame()` in full, and it
is exactly what the user saw: painted, dead, revived only by a real foreground transition.

The current wiring of the foreground effect:

```
push_sw.js notificationclick → focus() → postMessage({})        (unchanged by this change)
pending_deep_link_web.dart handoverSignals
   'message' | 'visibilitychange'(visible) | 'focus'
      → signal(): demandForegroundFrame(); controller.add(null)   ← call site 1
PendingDeepLinkController._foregrounded()
      → _onForegrounded(); check()                                ← call site 2 (injected seam)
app.dart: onForegrounded: widget.onForegrounded ?? demandForegroundFrame
```

## Goals / Non-Goals

**Goals:**

- Put the engine back into a `resumed` lifecycle state on arrival, so frames stay enabled for
  the rest of the session — see specs/reminder-notifications-ui.
- Ship only the remedy that has been observed to work on the affected device.
- Leave behind, in code, enough of the mechanism that the next person does not have to
  re-derive it — including what to check first if a Flutter upgrade breaks it.

**Non-Goals:**

- Touching `web/push_sw.js`, the D2 Cache Storage hand-over, or the
  `focus`/`postMessage`/`openWindow` ordering. The measurement shows this path working.
- Changing the gates in `PendingDeepLinkController` (TTL, dedupe, transition screens, auth).
- Fixing the freeze for arrivals that produce no signal at all. If `focus()` rejects, the
  worker calls `openWindow`, which loads or reloads a window — that window's engine starts
  `resumed` and there is nothing to repair. No third channel is invented for a case that has
  not been observed.
- Proving the fix in CI. It cannot be done; D6 says exactly which part is testable.

## Decisions

### D1 — The fix is a lifecycle restoration, not a frame request

Root cause: the engine's lifecycle is stuck at `hidden` because the browser dispatched no
event; frames are disabled as a consequence. A frame request cannot fix a disabled scheduler
(Context, `scheduleFrame` line 949). The change replaces "ask for a frame" with "make the
engine believe, correctly, that it is in the foreground again".

Rejected: keeping the frame request as well. A single forced frame after the lifecycle is
genuinely resumed is redundant (`_setFramesEnabledState(true)` already calls `scheduleFrame()`),
and keeping it would preserve a second explanation for any future partial recovery. See D5.

### D2 — Approach A (synthetic DOM events) ships; approach B (lifecycle channel) does not

**A:** on the hand-over signal, dispatch `new Event('visibilitychange')` on `document` and
`new Event('focus')` on `window`. The engine's own listeners — the ones enumerated in Context —
run and drive `AppLifecycleState` exactly as a real transition would.

Evidence: measurement three. Those two dispatches, typed by hand into the console of a frozen
WebAPK, revived the app immediately. Nothing else in this change has evidence of that strength.

**B (rejected for now):** push `AppLifecycleState.resumed` onto the `flutter/lifecycle` channel
(`ServicesBinding.instance.channelBuffers.push`), which reaches
`ServicesBinding._handleLifecycleMessage` → `handleAppLifecycleStateChanged` without touching
the DOM. It is cleaner: no dependency on engine-internal listeners, and it works identically on
any platform.

It is not shipped because it has never been run on the affected device, and because it is
*differently* wrong in a way A is not: it would update the framework's `lifecycleState` and
`framesEnabled` while leaving the engine's own `_appLifecycleState` still at `hidden`. The two
would then disagree, and the next genuine `visibilitychange`→hidden would be a no-op transition
in the engine (`hidden == hidden`, no notification), so the framework could be left believing it
is resumed while the page is not — the same class of desync as the bug being fixed. A also has
the property that it drives the *single* source of lifecycle truth on web rather than a second
one.

This bug has cost three unmeasured fixes (#80, #193, #226). B may be adopted later, but only
behind a device measurement of its own on an installed WebAPK, with the engine/framework state
desync above explicitly checked. It is not shipped alongside A: two mechanisms for one effect
would make the next failure unattributable, which is the exact condition that made this bug
take four attempts.

### D3 — Both events, dispatched from a conditionally-imported effect

`demandForegroundFrame()` in `pending_deep_link.dart` is replaced by
`restoreForegroundLifecycle()`, resolved by the same conditional import that already resolves
`PendingDeepLinkStoreImpl`: the web file dispatches, the stub is a documented no-op (there is no
DOM and no engine lifecycle to repair off the web).

Both events are dispatched, not one. The engine maps either to `resumed`, so one would very
likely be enough — but measurement three used the pair, and "very likely enough" reasoning is
what produced the last three fixes. Reducing to one requires a device measurement, and the code
comment says so.

Order: `visibilitychange` first, then `focus`. The `visibilitychange` listener re-reads
`document.visibilityState`, so it is the honest one — it can only report what is actually true.

Precondition: dispatch only while `document.visibilityState == 'visible'`. A synthetic `focus`
maps to `resumed` unconditionally, so dispatching it at a moment when the page is genuinely
hidden would enable frames for an invisible page and put the engine's state at odds with
reality. `visible` is also the measured precondition of the freeze (measurement one).

### D4 — The adapter ignores untrusted events, or the fix is an infinite loop

`handoverSignals` listens for `visibilitychange` and `focus` itself. Dispatching those same
events from the effect the signal triggers is a cycle:

```
signal → restoreForegroundLifecycle → dispatch 'focus'
       → our own window 'focus' listener → signal → dispatch → …
```

The engine deduplicates (`onAppLifecycleStateChange` ignores an unchanged state) but our adapter
does not, so this loop never terminates on the engine's behalf. The adapter's own
`visibilitychange` and `focus` listeners therefore return immediately for an event with
`isTrusted == false`. Only the browser can produce a trusted event; every synthetic one is ours.

Rejected alternatives:

- A re-entrancy flag around the dispatch. Works (dispatch is synchronous), but it is state that
  has to stay correct as the file changes, and it would still let a *different* piece of code's
  synthetic event drive a hand-over read.
- Dispatching only from the service-worker `message` listener, which is the one path with no
  cycle. Tempting, and it is the measured path — but it moves the effect out of the injected
  `onForegrounded` seam, which is the only part of this a VM test can observe at all (D6), in
  exchange for a guard that is one line.

### D5 — `demandForegroundFrame()` is deleted, and so is its second call site

Verdict on the two `scheduleFrame` lines under the new fix: **no remaining effect, delete
them.** Once the lifecycle is genuinely `resumed`, `_setFramesEnabledState(true)` calls
`scheduleFrame()` itself (binding.dart:883) — the frame is already asked for, by the framework,
as part of the transition. In the case the fix does not repair (no signal at all), the two lines
do what they have measurably always done: nothing that the user can see. There is no third case
in which they help.

Separately, the effect drops from two call sites to one. `signal()` in the web adapter calls it
directly *and* the controller calls `_onForegrounded()` unconditionally at the top of
`_foregrounded()`, before every gate — the direct call was defence against gates that the
controller no longer applies to it. One call site keeps the injected seam and the real behaviour
the same thing, which is what makes the VM guards in D6 mean anything.

### D6 — What is testable, and what is only a comment plus a device

`pending_deep_link_web.dart` is a `dart.library.js_interop` conditional import: `flutter test`
runs on the VM and compiles the stub, so **no VM test can reach a line of the dispatch, the
`isTrusted` guard, or the visibility precondition.** Saying otherwise is how a guard that cannot
fail gets written.

Testable on the VM, and to be guarded:

- The controller runs the injected foreground effect on every foreground signal — worker signal
  and lifecycle `resumed` alike — before every gate, and regardless of whether anything was
  pending, stale, unrecognized, or refused. (Extends existing coverage in
  `test/shared/pwa/pending_deep_link_controller_test.dart`.)
- Exactly once per signal, and never after `dispose()`.
- `test/app_pending_deep_link_test.dart` continues to prove the composition root wires the seam
  at all.

Not testable, and to be written down instead:

- That the engine still listens for these two events. The comment names the engine file and the
  version measured against; a Flutter upgrade is the trigger to re-verify on device.
- That the dispatch actually revives a frozen WebAPK. Only D7 shows that.
- That the composition root's *default* (`restoreForegroundLifecycle`, not a no-op) is the right
  function. A tear-off default is not observable from a test that injects a fake; it is a
  compile-time fact only.

Every new guard is mutation-verified: break the specific line it claims to protect, watch that
test go red, restore. A guard whose expected value comes from the same source as the value under
test does not count.

### D7 — Acceptance is on device; the protocol is part of the change

The freeze does not exist off a real installed WebAPK, so the change is not done when CI is
green. tasks.md carries the steps: probe armed before backgrounding, real push, tap, and the
console reading that distinguishes "fixed" from "one frame then dead again" — the failure mode
of #226, which looks identical for the first tap.

## Risks / Trade-offs

- **The engine's listeners are internal and may change in a Flutter upgrade.** → The dependency
  is named in a comment at the dispatch site, pointing at the exact engine file, and the upgrade
  checklist is a device re-verification. Symptom if it breaks is the original bug, unmistakable
  and already understood; approach B is the documented next step.
- **Synthetic events are visible to any other listener on `document`/`window`.** → Bounded: the
  app's own listener for these is the one in `pending_deep_link_web.dart`, which D4 makes ignore
  untrusted events; `web/index.html`'s `visibilitychange` listener drives
  `registration.update()`, which is idempotent and off the critical path. That
  listener does not check `isTrusted`, so after this change every notification
  tap schedules one extra service-worker update check — deferred by 10s, which
  is exactly the deferral issue #226 added to keep the check off the moment the
  user starts using the app, so the interaction is accepted rather than
  filtered. Both sides say so in a comment; no `isTrusted` filter is added to
  `index.html` without a concrete failure to point at.
- **A synthetic `focus` asserts `resumed` unconditionally.** → D3's `visibilityState == 'visible'`
  precondition; and the pair is only dispatched on a signal that means the app is in front of
  the user.
- **The whole fix lives in a file no test executes.** → Accepted and stated (D6). The
  compensation is one device protocol (D7) and a comment that explains the mechanism rather than
  the code.
- **Deleting the frame request removes the only thing that made the first tap look partly
  alive.** → Intentional. If the fix regresses, it should look broken immediately rather than
  produce one frame and mislead the next investigation.

## Migration Plan

No data, storage, or contract migration: `web/push_sw.js`, the Cache Storage entry, and every
push already in flight are untouched. A worker registered by an older app version keeps working
unchanged. Rollback is a revert of the Dart changes; it restores the current, broken-but-safe
behaviour.
