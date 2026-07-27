# Tasks

> The Cache hand-over contract (cache name, key, payload shape, `path` form) is defined
> **once** in design.md D2. Both the SW (task 4) and the Dart adapter (task 1) implement
> that table — do not restate or improvise it.

## 1. Pending deep-link store (interface + platform impls)
- [ ] `lib/shared/pwa/pending_deep_link.dart`: `class PendingDeepLink { final String path; final DateTime savedAt; }`, `abstract class PendingDeepLinkStore { Future<PendingDeepLink?> take(); Stream<void> get handoverSignals; }`, and `export 'pending_deep_link_stub.dart' if (dart.library.js_interop) 'pending_deep_link_web.dart';` — same three-file shape as `pwa_install` / `pwa_update`.
- [ ] `take()` contract, documented on the interface: read the entry, **delete it, then** return it. Consumed exactly once even when the caller decides not to act on it (TTL/dedupe are the caller's judgement, not the store's). Note that the *caller* is responsible for not calling `take()` at all while auth is unresolved — see task 2.
- [ ] `handoverSignals` contract: fires when the service worker says "there may be something to read"; carries **no destination** (Cache stays the single source of truth per D4).
- [ ] `pending_deep_link_stub.dart`: `PendingDeepLinkStoreImpl` returning `null` / `Stream.empty()`. Keeps android/ios/VM-test builds compiling without `dart:js_interop`.
- [ ] `pending_deep_link_web.dart`: `take()` reads the D2 cache/key, parses the payload, `DateTime.fromMillisecondsSinceEpoch(savedAt)`, deletes the key, returns. Any failure (no cache, no entry, malformed JSON) returns `null` rather than throwing — a broken hand-over must not break app startup. `handoverSignals` bridges `navigator.serviceWorker`'s message event. Thin adapter, **not** unit-tested (same call as `BrowserWebPushGateway`).

## 2. PendingDeepLinkController (TDD — all judgement lives here)
- [ ] Test first (red): `test/shared/pwa/pending_deep_link_controller_test.dart` against a fake store + injected `now` / `canNavigate` / `currentPath` / `navigate`:
  - a fresh pending path within the TTL navigates to that path
  - a pending path older than the TTL does **not** navigate — and was still taken from the store (consumed, not left to fire later)
  - `canNavigate()` false → the store is **not** read at all (nothing consumed while auth is bootstrapping, so it survives to the post-sign-in check)
  - `currentPath()` on `/splash`, `/auth-error`, `/login`, `/register` → store **not** read, no navigation (D6 gate 2)
  - `currentPath()` already equal to the pending path → no navigation (no duplicate 今日照護 on top of itself)
  - a `null` from the store → no navigation, no throw
  - a second `check()` after a successful one does not navigate again (store now empty)
  - **two concurrent `check()`s navigate exactly once** (D8 in-flight guard; the fake store must be able to hold its read open so both calls overlap)
  - a `handoverSignals` event triggers a check
  - `didChangeAppLifecycleState(AppLifecycleState.resumed)` triggers a check; other lifecycle states do not
- [ ] `lib/shared/pwa/pending_deep_link_controller.dart`: `class PendingDeepLinkController with WidgetsBindingObserver`, constructed with the store and `{Duration ttl = const Duration(minutes: 5), DateTime Function() now = DateTime.now, required bool Function() canNavigate, required String Function() currentPath, required void Function(String path) navigate}`.
- [ ] `Future<void> check()`: return if a check is already in flight (D8); return if `!canNavigate()`; return if `currentPath()` is a transition location (`/splash`, `/auth-error`, `/login`, `/register`); then `take()`; return on `null`; return when `now().difference(pending.savedAt) > ttl`; return when `currentPath() == pending.path`; else `navigate(pending.path)`. Clear the in-flight flag in a `finally`.
- [ ] `start()` registers the lifecycle observer, subscribes to `handoverSignals`, and runs one `check()`; `dispose()` removes the observer and cancels the subscription. Idempotent, mirroring `PwaUpdateController.start()`. Tests drive `check()` directly so they never register a real observer.

## 3. Wire it into the app (TDD)
- [ ] Test first (red): in `test/app_test.dart` (or a sibling), with a fake store holding a fresh `/care-today` and a signed-in fake auth — the app ends up on 今日照護 **and** the route below it is still the home screen (a `push`, not a `go`: assert the back affordance / that popping returns home). Second test: an expired entry leaves the app on home. Third: a store that throws leaves the app on home without an error surfacing.
- [ ] `lib/main.dart`: construct `const PendingDeepLinkStoreImpl()` and pass it into `App`.
- [ ] `lib/app.dart`: `_AppState` builds the `PendingDeepLinkController` from the injected store, wiring `canNavigate: () => !_authNotifier.loading && !_authNotifier.error && _authNotifier.signedIn`, `currentPath` from the router's current configuration, and `navigate: (path) => _router.push(path)`. `start()` it in `initState`; add a `_authNotifier` listener that **schedules** a re-check via `WidgetsBinding.instance.addPostFrameCallback` rather than checking inline (D6 timing — go_router's own `refreshListenable` registers later than ours, so an inline check can push onto a not-yet-redirected `/splash`); dispose the controller and remove the listener.
- [ ] The `App` constructor gains one **optional** store arg so existing test call sites keep working — construction sites to update: `lib/main.dart` and `test/app_test.dart`'s `pumpApp` helper.
- [ ] Do **not** touch `resolveAuthRedirect` or its `pendingDeepLink` replay — `test/app_redirect_test.dart` must stay green as-is.

## 4. Service worker hand-over
- [ ] `web/push_sw.js` `notificationclick`, as one `event.waitUntil` promise chain, **in this order**:
  1. write the D2 payload into the D2 cache/key and **await it** (never open a window before the write lands);
  2. `clients.matchAll({ type: 'window', includeUncontrolled: true })`;
  3. if a window exists — pick the `focused === true` one, else the first — `postMessage` the no-payload signal, then `client.focus()`; if `focus()` rejects, fall back to `clients.openWindow('/')`;
  4. if no window exists, `clients.openWindow('/')`.
- [ ] Never call `client.navigate()`: it would wipe the page stack the back arrow depends on, and is disallowed for a window this worker doesn't control.
- [ ] `openWindow` opens `'/'`, **not** the hash form (D9) — every platform now goes through the same Cache path so the back-arrow guarantee holds unconditionally.
- [ ] Store the *path* (`/care-today`), not a URL. Derive it from `data.url` when the backend eventually sends one, defaulting to `/care-today`.
- [ ] Update the stale comment claiming a `/push/`-scoped worker cannot see `/`-scope windows — it can, with `includeUncontrolled: true`.

## 5. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.

## 6. On-device verification (manual — needs the user's Android phone, after deploy)
- [ ] Cold start: clear the PWA from recents → send a test push → tap it → 今日照護 opens **with a back arrow**, back returns to home.
- [ ] Background: leave the app on another screen (e.g. 飲食), switch away → tap a notification → 今日照護 stacks on top, back returns to 飲食.
- [ ] Foreground: while actively using the app on another screen, tap the heads-up notification → 今日照護 stacks on top immediately, back returns to that screen.
