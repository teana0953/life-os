# Tasks

## 1. Pending deep-link store (interface + platform impls)
- [ ] `lib/shared/pwa/pending_deep_link.dart`: `class PendingDeepLink { final String path; final DateTime savedAt; }` plus `abstract class PendingDeepLinkStore { Future<PendingDeepLink?> take(); }`, with `export 'pending_deep_link_stub.dart' if (dart.library.js_interop) 'pending_deep_link_web.dart';` — same three-file shape as `pwa_install` / `pwa_update`.
- [ ] `take()` contract, documented on the interface: read the entry, **delete it, then** return it. It is consumed exactly once even when the caller decides not to act on it (TTL/dedupe are the caller's judgement, not the store's).
- [ ] `pending_deep_link_stub.dart`: `PendingDeepLinkStoreImpl` returning `null`. Keeps android/ios/VM-test builds compiling without `dart:js_interop`.
- [ ] `pending_deep_link_web.dart`: read `caches.open('lifeos-deeplink')` → `match('/pending')` → parse `{ path, savedAt }` JSON → `delete('/pending')` → return. Any failure (no cache, no entry, malformed JSON) returns `null` rather than throwing — a broken hand-over must not break app startup. Thin adapter, **not** unit-tested (same call as `BrowserWebPushGateway`).

## 2. PendingDeepLinkController (TDD — the judgement lives here)
- [ ] Test first (red): `test/shared/pwa/pending_deep_link_controller_test.dart` against a fake store + injected `now`/`canNavigate`/`currentPath`/`navigate`:
  - a fresh pending path within the TTL navigates to that path
  - a pending path older than the TTL does **not** navigate — and was still taken from the store (consumed, not left to fire later)
  - `canNavigate()` false → the store is **not** read at all (nothing consumed while auth is still bootstrapping, so it survives to the post-sign-in check)
  - `currentPath()` already equal to the pending path → no navigation (no duplicate 今日照護 on top of itself)
  - a `null` from the store → no navigation, no throw
  - a second `check()` after a successful one does not navigate again (store now empty)
  - `didChangeAppLifecycleState(AppLifecycleState.resumed)` triggers a check; other lifecycle states do not
- [ ] `lib/shared/pwa/pending_deep_link_controller.dart`: `class PendingDeepLinkController with WidgetsBindingObserver`, constructed with the store and `{Duration ttl = const Duration(minutes: 5), DateTime Function() now = DateTime.now, required bool Function() canNavigate, required String Function() currentPath, required void Function(String path) navigate}`.
- [ ] `Future<void> check()`: bail when `!canNavigate()` (before touching the store); else `take()`; bail on `null`; bail when `now().difference(pending.savedAt) > ttl`; bail when `currentPath() == pending.path`; else `navigate(pending.path)`.
- [ ] `start()` registers the observer and runs one `check()`; `dispose()` removes it. Idempotent, mirroring `PwaUpdateController.start()`. Tests drive `check()` directly so they never register a real observer.

## 3. Wire it into the app (TDD)
- [ ] Test first (red): in `test/app_test.dart` (or a sibling), with a fake store holding a fresh `/care-today` and a signed-in fake auth — the app ends up on 今日照護 **and** the route below it is still the home screen (a `push`, not a `go`: assert the back affordance / that popping returns home). A second test: an expired entry leaves the app on home.
- [ ] `lib/main.dart`: construct `const PendingDeepLinkStoreImpl()` and pass it into `App`.
- [ ] `lib/app.dart`: `_AppState` builds the `PendingDeepLinkController` from the injected store, wiring `canNavigate: () => !_authNotifier.loading && !_authNotifier.error && _authNotifier.signedIn`, `currentPath` from the router's current configuration, and `navigate: (path) => _router.push(path)`. `start()` it in `initState`, add a `_authNotifier` listener that re-runs `check()` on auth transitions (covers "tapped while signed out, then signed in"), and dispose both.
- [ ] Do **not** touch `resolveAuthRedirect` or its `pendingDeepLink` replay — `test/app_redirect_test.dart` must stay green as-is.

## 4. Service worker hand-over
- [ ] `web/push_sw.js` `notificationclick`: write `{ path, savedAt: Date.now() }` into `caches.open('lifeos-deeplink')` under `'/pending'`, then `clients.matchAll({ type: 'window', includeUncontrolled: true })` → if a same-origin app window exists, `client.focus()` (**never** `navigate()` — it would wipe the page stack the back arrow depends on, and is disallowed for a window this worker doesn't control); otherwise `clients.openWindow(url)`.
- [ ] Keep `openWindow`'s url as the hash form `/#/care-today`: harmless on Android (the fragment is dropped anyway) and a working fallback in a desktop browser tab. Duplicate navigation is already prevented by the `currentPath` check in task 2.
- [ ] Store the *path* (`/care-today`), not the hash URL — the app router navigates by path. Derive it from `data.url` when the backend eventually sends one, defaulting to `/care-today`.
- [ ] Update the stale comment claiming a `/push/`-scoped worker cannot see `/`-scope windows — it can, with `includeUncontrolled: true`.

## 5. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.

## 6. On-device verification (manual — needs the user's Android phone, after deploy)
- [ ] Cold start: clear the PWA from recents → send a test push → tap it → 今日照護 opens **with a back arrow**, back returns to home.
- [ ] Warm resume: leave the app on another screen (e.g. 飲食) → tap a notification → 今日照護 stacks on top, back returns to 飲食.
