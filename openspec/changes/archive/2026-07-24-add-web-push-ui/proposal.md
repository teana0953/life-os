## Why

Frontend of the reminders/notifications feature's first slice. The Web Push
transport is live on the backend (merged: `GET /api/push/vapid-public-key`,
`POST`/`DELETE /api/push/subscribe`, `POST /api/push/test`). This gives the user an
in-app screen to **turn on notifications** (grant permission + subscribe) and **send
a test push**, so the riskiest unknown — whether an installed iOS/Android PWA
actually receives a push — can be proven on-device before any reminder scheduling is
built. No Firebase; standard Web Push (VAPID).

## What Changes

- New `notifications` context (`lib/contexts/notifications/`):
  - **`PushRepository`** port + typed errors (`PushReauthRequired`, `PushRequestFailed`)
    and **`HttpPushRepository`** (patterned on `HttpImportRepository`): calls the
    backend endpoints this slice uses with the Firebase Bearer token —
    `fetchVapidPublicKey`, `saveSubscription`, `sendTest` → `{sent, failed}`; 401 →
    `PushReauthRequired`, other non-2xx → `PushRequestFailed`. (No `deleteSubscription`
    — there is no disable action in this slice; it lands with the disable UI later, YAGNI.)
  - **`WebPushGateway`** port (browser glue, isolated behind an interface):
    `describeEnvironment()` → `{ supported, standalone, iosNeedsInstall }` (reads the
    existing `window.pwaInstall` bridge); `permissionStatus`; `enableAndSubscribe(vapidPublicKey)`
    → subscription `{endpoint,p256dh,auth}` or null when the user denies.
    **`BrowserWebPushGateway`** implements it with `package:web` + `dart:js_interop`.
  - **`enableReminders`** / **`sendTestPush`** use cases.
  - **`ReminderSettingsController`** (ChangeNotifier) — a state machine:
    `unsupported` / `iosNeedsInstall` / `permissionDenied` / `idle` / `enabling` /
    `enabled` / `error`.
  - **`ReminderSettingsScreen`** — status text, an "Enable notifications" primary
    button (permission + subscribe), a "Send test push" secondary button (enabled once
    subscribed; shows the sent/failed result), and, on iOS-not-installed, an
    "Add to Home Screen first" hint.
- **`web/push_sw.js`** — a static service worker handling `push` (show the
  notification) and `notificationclick` (open the app via `clients.openWindow('/')`).
  Registered by `BrowserWebPushGateway` at a **separate scope (`/push/`)** so it never
  replaces Flutter's `/`-scope caching service worker (`flutter_service_worker.js`);
  the push subscription is created on that registration. `web/index.html`'s existing
  `applyUpdate` (which unregisters **every** SW on a PWA update) is scoped to skip the
  `/push/` registration so an app update doesn't silently destroy the push subscription.
- **Entry point**: the health module's 更多 (More) tab gains a reminders entry that
  routes (go_router, nested + DI-built screen) to `ReminderSettingsScreen`; DI wired
  in `main.dart`.
- New i18n strings (en + zh-Hant + zh), regenerated localizations.

Frontend only. **No** reminder types or scheduling UI (medication / rehab / glucose /
missed-meal — later slices). The real service-worker registration, `pushManager.subscribe`,
and on-device push receipt are **not** exercised by `flutter test` (the browser glue is
isolated behind `WebPushGateway` and verified on-device — the point of this slice);
tests cover the controller state machine, use cases, `HttpPushRepository` (mock
`http.Client`), and each `ReminderSettingsScreen` state (fake controller). Gate =
`bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`.

## Capabilities

### Added Capabilities

- `reminder-notifications-ui`: from the health module's More tab, a user can enable
  browser notifications (grant permission + subscribe to Web Push) and send a test
  push, with clear guidance when the platform needs the PWA installed first (iOS) or
  when permission is denied.
