## 1. Replace the frame demand with a lifecycle restoration

- [x] 1.1 Delete `demandForegroundFrame()` from `lib/shared/pwa/pending_deep_link.dart` and
      declare `restoreForegroundLifecycle()` in its place, resolved by the existing conditional
      export (design D1/D3/D5). Keep the doc comment's description of the stall — it was already
      correct — and correct the remedy it describes: the engine's lifecycle is stuck at `hidden`,
      not the frame queue. Verify `flutter analyze` is clean and no reference to
      `demandForegroundFrame` remains (`grep -rn demandForegroundFrame lib/ test/` → 0 hits).
- [x] 1.2 Add a no-op `restoreForegroundLifecycle()` to `lib/shared/pwa/pending_deep_link_stub.dart`
      with a comment saying why there is nothing to restore off the web. Verify `flutter test`
      compiles and passes (the VM build is the stub).
- [x] 1.3 Implement `restoreForegroundLifecycle()` in `lib/shared/pwa/pending_deep_link_web.dart`:
      return unless `document.visibilityState == 'visible'`, then dispatch
      `Event('visibilitychange')` on `document` and `Event('focus')` on `window`, in that order
      (design D3). Comment must name the engine listeners it targets
      (`flutter_web_sdk/lib/_engine/engine/platform_dispatcher/app_lifecycle_state.dart`,
      `_BrowserAppLifecycleState`), the Flutter version measured against, why a synthetic event
      rather than an API, and that reducing to one event needs a new device measurement. Verify
      `flutter analyze` clean and `flutter build web --release` succeeds (the only compiler that
      sees this file).
- [x] 1.4 In the same file, make the adapter's own `visibilitychange` and `focus` listeners
      return early on `!event.isTrusted`, with the loop it prevents spelled out (design D4).
      Verify `flutter build web --release` succeeds.
- [x] 1.5 Remove the direct foreground-effect call from `signal()` in
      `pending_deep_link_web.dart` so the effect has exactly one call site — the controller's
      injected seam (design D5) — and update `signal()`'s comment, which currently explains the
      now-removed ordering. Verify `flutter build web --release` succeeds.
- [x] 1.6 Point the composition root's default at the new effect in `lib/app.dart` (~line 431,
      `onForegrounded: widget.onForegrounded ?? …`) and update the `onForegrounded` doc on the
      `App` widget (~line 306-314), which still promises a frame. Verify `flutter analyze` clean
      and `flutter test` passes.
- [x] 1.7 Update the `_onForegrounded` and `_foregrounded()` comments in
      `lib/shared/pwa/pending_deep_link_controller.dart`: they cite issue #226 and "asks the
      engine for a frame". Behaviour here does not change — the effect still runs first and
      unconditionally — only what it is. Verify `flutter analyze` clean.

## 2. Guards (VM-testable half only)

- [x] 2.1 In `test/shared/pwa/pending_deep_link_controller_test.dart`, assert the foreground
      effect runs on **both** signal paths (`handoverSignals` and
      `didChangeAppLifecycleState(resumed)`) and on every outcome the gates can produce:
      nothing pending, stale entry, unrecognized path, `canNavigate` false, transition screen.
      Mutation-verify each: move `_onForegrounded()` below the corresponding gate in
      `_runCheck`/`_foregrounded` and confirm **that** case goes red, then restore.
- [x] 2.2 Assert the effect runs exactly once per signal and never after `dispose()`.
      Mutation-verify: call it twice, and remove the `_disposed` early return; both must go red.
- [x] 2.3 Rewrite the stale half of the issue-#226 test in
      `test/app_pending_deep_link_test.dart` (~line 650-707): its comment claims the tap is not
      a repaint guard, which stays true, but the surrounding text describes the deleted frame
      demand. State instead what the VM can and cannot see here (design D6) so the next reader
      does not mistake a green run for a fixed freeze.
- [x] 2.4 Add no test that pretends to cover `pending_deep_link_web.dart`. Verify by inspection
      that every new assertion's expected value comes from somewhere other than the code under
      test, and that no new test would still pass with the dispatch deleted **because** it never
      reaches it — record in the PR which mutations were run and which test each turned red.
- [x] 2.5 Full suite green in both timezones: `flutter test` and `TZ=UTC flutter test` (this
      change touches no dates, so this is a regression check, not a target), plus
      `flutter analyze`.

## 3. Spec and docs

- [x] 3.1 `openspec validate fix-notification-tap-frozen-lifecycle --strict` passes and
      `openspec status --change fix-notification-tap-frozen-lifecycle` shows four artifacts
      complete.
- [x] 3.2 Confirm `web/push_sw.js` is untouched in the diff (`git diff --stat web/` → empty).
      The Cache Storage hand-over is a two-language single source of truth and this change has
      no reason to move it.
      Verified as `web/push_sw.js` untouched, not as an empty `web/` diff: task 1.3/1.4 landed a
      comment-only edit in `web/index.html` (7+/3-, no behaviour change) recording the synthetic
      `visibilitychange` this change now sends through that file's own listener, and correcting a
      sentence there that the device measurement disproved. `git diff --stat web/` therefore
      shows `web/index.html` only.

## 4. On-device acceptance (the only proof that counts)

- [ ] 4.1 Deploy the build and **reinstall** the WebAPK on the Android device, then connect via
      `chrome://inspect`. Verify the console is attached to the installed app, not a browser tab.
- [ ] 4.2 Arm the probe from measurement two before backgrounding — listeners on `document`
      `visibilitychange`, `window` `focus`/`blur`, and `navigator.serviceWorker` `message` with
      `startMessages()` — and confirm it prints `probe armed`.
- [ ] 4.3 Background the app, trigger a real care push, tap the notification. Verify: the app
      comes forward, the console shows `SW MSG` (with still no trusted `VIS visible` / `FOCUS`
      from the platform — the platform behaviour is not what changed), and the screen responds
      to touch immediately.
- [ ] 4.4 **Distinguish "fixed" from "#226 again":** after the tap, keep using the app for at
      least three further interactions that change what is on screen (open a sheet, mark a care
      item done, switch tab). Every one must repaint as it happens. One frame followed by a dead
      screen is the failure mode this change exists to rule out and it looks identical on the
      first tap.
- [ ] 4.5 Verify `document.hidden`-driven behaviour is not broken by the synthetic events:
      background the app normally (home button, no notification), return by tapping the launcher
      icon, and confirm the app is responsive and did not double-navigate.
- [ ] 4.6 Tap a notification while the app is already in the foreground on 今日照護, and tap two
      notifications for the same destination in a row. Verify no duplicate screens stack and the
      back button returns to where the user was (the issue #193 behaviour must be unchanged).
- [ ] 4.7 Record the console transcript and the Flutter version in the PR. If the fix does not
      hold, do **not** substitute approach B on reasoning — design D2 says what evidence B needs
      first.
