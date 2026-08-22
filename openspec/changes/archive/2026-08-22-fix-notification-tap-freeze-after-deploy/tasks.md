## 1. Close the hypotheses with re-runnable evidence

- [x] 1.1 Record the H2/H3/H4 eliminations as a committed assertion rather than prose: extend
  `test/shared/pwa/pwa_update_banner_test.dart` (or add `test/shared/pwa/pwa_update_apply_call_site_test.dart`)
  with a guard that `applyUpdate` is only ever reached from the banner's own action — verify by
  mutating the banner to call `applyUpdate` from `initState` and confirming the guard turns red.
- [x] 1.2 Prove H1 is a real freeze: add a widget test in `test/app_pending_deep_link_test.dart`
  that puts a popup route refusing `didPop` above a handed-over destination and drives the
  hand-over. Verify by watching the test hang (or trip its own timeout) **before** task 3.1 lands,
  and pass after it. Separately, add a `PopScope(canPop: false)` fixture (a route that refuses
  only when popped via `maybePop`, not `didPop`) above a destination that the `matches.length`
  loop — not the popup loop — has to unwind past; verify it survives the hand-over instead of
  being force-closed by `GoRouter.pop()`/`NavigatorState.pop()`, which ignores `PopScope`.
- [x] 1.3 Write the H5 static findings into `design.md`'s table if `grep -rn "deferred as" lib/`
  ever returns a hit — verify by re-running that grep and confirming it is still 0.

## 2. Foregrounding restores interactivity (spec: "A notification tap leaves the app usable")

- [x] 2.1 In `lib/shared/pwa/pending_deep_link_web.dart`, make every foreground signal
  (`message`, `visibilitychange`→visible, `focus`) demand a frame from the engine before it is
  turned into a hand-over signal, so a signal that finds nothing pending still leaves the app
  painting. Verify with `flutter analyze` clean and a manual read that no gate sits between the
  signal and the frame request.
- [x] 2.2 Give `PendingDeepLinkController` a seam for "the app was brought forward" that is
  independent of the hand-over outcome, so the frame demand is testable on the VM (the web store
  itself is a thin, untested adapter). Verify with new cases in
  `test/shared/pwa/pending_deep_link_controller_test.dart`: a foreground signal with an **empty**
  store, with an **expired** entry, and with an **unrecognized** path each still produce the
  foreground effect.
- [x] 2.3 Wire the seam in `lib/app.dart` / `lib/main.dart` composition so it is active in the
  real app. Verify with a widget test in `test/app_pending_deep_link_test.dart` that asserts the
  injected `onForegrounded` seam is called once per foreground signal — not that a driven tap
  fails, which a widget test cannot make happen regardless of whether the seam is wired (the
  binding always services a frame on `pump`/`tap`) — and mutate the wiring away to confirm the
  seam-call assertion goes red. `demandForegroundFrame()`'s own body (the two `scheduleFrame`
  calls) has no VM-side guard; it is verifiable only on-device, by steps 5.1/5.4.
- [x] 2.4 `TZ=UTC flutter test test/shared/pwa/pending_deep_link_controller_test.dart` — the TTL
  and `savedAt` comparisons in these tests are date/time-carrying and this repo is UTC+8 locally,
  UTC in CI. Verify both `flutter test` and the `TZ=UTC` run report `All tests passed!`.

## 3. Arriving at a destination never blocks (spec: "Arriving at a handed-over destination never blocks the app")

- [x] 3.1 Bound both loops in `_popTo` (`lib/app.dart`) on "the stack stopped changing" rather
  than on depth alone — covering the `popUntil` for popup routes and the `while` on
  `matches.length`, per design D4. Verify 1.2's test now passes and completes.
- [x] 3.2 Add the ordinary-case guard: a destination already in the stack under normal
  dismissible screens is still reached, and the app stays responsive. Verify by mutating the new
  bound to stop after the first iteration and confirming this test — not only 1.2's — turns red.

## 4. The update check stops competing with the tap (spec: "A newly deployed version never makes a running window unusable")

- [x] 4.1 In `web/index.html`, move the `visibilitychange`→visible `checkForUpdate()` off the
  foregrounding transition (design D3), leaving the on-load and 30-minute checks untouched.
  Verify by reading the three `checkForUpdate()` call sites and confirming none of them runs
  synchronously inside the visibility handler.
- [x] 4.2 Confirm the banner still appears after a deploy: `flutter test test/shared/pwa/pwa_update_banner_test.dart`
  plus a manual read that `window.pwaUpdate.available` still flips from the `statechange` /
  `registration.waiting` paths, which this task does not touch.

## 5. On-device reproduction and confirmation — REQUIRES USER VERIFICATION

> Everything below needs a real deploy, a real installed WebAPK, and a real push. None of it can
> be run or claimed from this session; results go back into `design.md`'s verdict table.

- [ ] 5.1 **(user)** Before deploying the fix: reproduce on the current build — leave the app
  open, deploy a new version, background the app, send a reminder, tap the notification, and
  confirm the frozen-but-painted state and that backgrounding + returning recovers it.
- [ ] 5.2 **(user)** With Chrome remote DevTools attached to the frozen window, capture (a) a
  Performance trace across the tap — H6 predicts no frames between the focus and the recovery —
  and (b) the Network tab for any 404 on a hashed asset, which is H5's signature.
- [ ] 5.3 **(user)** Try the same sequence **without** a deploy in between. A freeze here means
  fact 1 is a correlation, not a cause, and H7 drops out.
- [ ] 5.4 **(user)** After deploying this change: repeat 5.1 and confirm the app comes forward
  tappable, on the correct screen, with no background-and-return needed.
- [ ] 5.5 Record 5.1–5.4's actual outcomes in `design.md`'s verdict table, replacing "primary
  surviving hypothesis" with the measured result. If the freeze survives 5.4, open a follow-up
  issue carrying the 5.2 network trace (design.md — Open Questions) rather than guessing again.

## 6. Gate

- [x] 6.1 `flutter analyze` reports no issues.
- [x] 6.2 `flutter test` reports `All tests passed!` — read the line, do not infer it from the
  absence of red.
- [x] 6.3 `npx openspec validate fix-notification-tap-freeze-after-deploy --strict` passes.
