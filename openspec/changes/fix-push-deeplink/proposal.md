## Why

Tapping a care push notification is supposed to open 今日照護 (`/care-today`). On Android
it does not, and the two failure modes turn out to be one design flaw:

- **Cold start (PWA task cleared)**: the app lands on the home screen. `push_sw.js` calls
  `clients.openWindow('/#/care-today')`, so the destination rides **only** on the URL
  fragment — and Chrome's WebAPK launch drops it, starting the PWA from the manifest's
  `start_url` (`.`) instead. Verified on device: after the tap, the PWA's "copy link" gives
  `https://life-os-6oo.pages.dev/` with no `#/` at all.
- **Already running (background or foreground)**: the app *does* reach 今日照護, but with
  **no back arrow** — the fragment change drives a URL-level *replace*, so go_router rebuilds
  the stack as a single `/care-today` entry with no parent to return to.

Ruled out by evidence: the deployed `push_sw.js` is the current version and is served
`cache-control: public, max-age=0, must-revalidate` (so devices are not running a stale
worker); the backend (`run-care-tick.ts`) sends only `{ title, body }` and relies on the
worker's default; and opening `https://life-os-6oo.pages.dev/#/care-today` by hand works,
so `resolveAuthRedirect`'s deep-link recovery is healthy.

## What Changes

- **`web/push_sw.js`**: on `notificationclick`, write the destination path into **Cache
  Storage** (same-origin, shared between the worker and the page) and await the write, then
  `matchAll({ type: 'window', includeUncontrolled: true })` — signal and `focus()` an existing
  app window (**without navigating it**, so the user's current page stack survives), or
  `openWindow('/')` when there is none or `focus()` rejects. The destination no longer
  depends on the URL surviving the WebAPK launch, and no longer rides on the hash at all.
- **New `lib/shared/pwa/pending_deep_link.dart`** (+ `_stub.dart` / `_web.dart`): an
  injectable `take()` over that Cache entry plus a `handoverSignals` stream over the worker's
  message event, following the existing conditional-export pattern used by `pwa_install` /
  `pwa_update` so non-web targets still compile.
- **New `PendingDeepLinkController`**: holds all the judgement — 5-minute TTL, clear-on-read
  (even when expired), never read while auth is unresolved or while the app sits on a
  transition screen, skip when already on the target route, single-flight guard, and
  re-check on `didChangeAppLifecycleState(resumed)` (mirroring `PwaUpdateController`) and on
  a worker signal.
- **`lib/app.dart`**: consume the pending link **only once auth has resolved and the user is
  signed in**, scheduled post-frame so go_router has finished its own redirect first, and
  navigate with `push` so 今日照護 stacks on top of the current page and gets a back arrow —
  the same result as entering it from the overview card.

The worker signal exists because Android shows care reminders as a heads-up banner over an
app that is already in the foreground; there `focus()` changes nothing, no `resumed` is
dispatched, and a lifecycle-only design would leave the tap doing nothing at all — a
regression against today's behaviour. The signal carries no destination, so Cache remains the
single source of truth and there is only ever one consumption path.

`resolveAuthRedirect` and its `pendingDeepLink` replay are **not touched**: they cover the
case where the URL *does* carry the deep link — a hand-typed address — which no longer
overlaps the notification path at all now that it always opens `/`. They stay covered by
`test/app_redirect_test.dart`.

Frontend only; no backend, copy, or l10n change. Gate = lint + `flutter analyze` +
`flutter test`.

## Capabilities

### Modified Capabilities

- `reminder-notifications-ui`: tapping a care notification SHALL open 今日照護 whether the app
  was closed, backgrounded, or already in the foreground, stacked so the user can navigate
  back.
