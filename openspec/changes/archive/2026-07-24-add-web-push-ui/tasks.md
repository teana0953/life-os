# Tasks

## 1. Domain: ports + values
- [ ] `domain/push_subscription.dart`: value `{ endpoint, p256dh, auth }`.
- [ ] `domain/push_repository.dart`: `PushRepository` port (`fetchVapidPublicKey`,
      `saveSubscription`, `sendTest` → `{sent, failed}`) + typed errors
      `PushReauthRequired`, `PushRequestFailed` (no localized text). No
      `deleteSubscription` — no disable action this slice (YAGNI).
- [ ] `domain/web_push_gateway.dart`: `WebPushGateway` port
      (`describeEnvironment()` → `PushEnvironment{ supported, standalone,
      iosNeedsInstall }`, `permissionStatus`, `enableAndSubscribe(vapidPublicKey)` →
      `PushSubscription?`) + supporting enums. No `unsubscribe()` (YAGNI, later slice).

## 2. Use cases (TDD, fake gateway + fake repo)
- [ ] `enable_reminders.dart`: env-check short-circuits (unsupported / iosNeedsInstall);
      else fetchVapidPublicKey → gateway.enableAndSubscribe → if a subscription is
      returned, repo.saveSubscription; returns an outcome the controller maps to state.
      Test: subscribe-then-save happy path; denied (null) → not saved; env short-circuits.
- [ ] `send_test_push.dart`: calls repo.sendTest, returns `{sent, failed}`. Test the
      pass-through + that a `PushReauthRequired` propagates.

## 3. Infrastructure: HttpPushRepository (TDD, mock http.Client)
- [ ] `infrastructure/http_push_repository.dart` (mirror `HttpImportRepository`:
      injected `baseUrl` + `http.Client`, `Authorization: Bearer <idToken>`,
      snake_case bodies). Test: GET vapid-public-key parses `{public_key}`; POST
      subscribe sends `{endpoint,p256dh,auth}`; POST test parses `{sent,failed}`;
      401 → `PushReauthRequired`; other non-2xx → `PushRequestFailed`.

## 4. Infrastructure: BrowserWebPushGateway (browser glue, thin)
- [ ] `infrastructure/browser_web_push_gateway.dart` using `package:web` +
      `dart:js_interop`: `describeEnvironment` reads `window.pwaInstall`
      (standalone/iosHint) + feature-detects serviceWorker/PushManager/Notification;
      `enableAndSubscribe` registers `push_sw.js` at scope `/push/`, requests
      Notification permission, and `pushManager.subscribe({ userVisibleOnly: true,
      applicationServerKey: <base64url→Uint8Array> })`, returning the endpoint +
      p256dh/auth keys (or null on deny). `describeEnvironment` MUST resolve
      `iosNeedsInstall` (from `pwaInstall.iosHint`) BEFORE `unsupported`, since iOS
      Safari hides `PushManager` until installed (design D3). NOTE: not covered by
      `flutter test` (on-device); keep it a thin adapter, no business logic.
- [ ] `web/push_sw.js`: `push` handler → `self.registration.showNotification(title,
      { body })` from `event.data.json()`; `notificationclick` → `clients.openWindow('/')`
      (a `/push/`-scoped SW can't focus the `/`-scope app tab — design D6a).
- [ ] `web/index.html`: scope `applyUpdate`'s unregister-all to Flutter's `/`
      registration so a PWA update doesn't destroy the `/push/` push subscription
      (design D6b).

## 5. Presentation: controller + screen (TDD)
- [ ] `presentation/reminder_settings_controller.dart` (ChangeNotifier) state machine
      unsupported / iosNeedsInstall / permissionDenied / idle / enabling / enabled /
      error, driving `enableReminders` + `sendTestPush`; holds typed error, not text;
      re-entrancy guard on enable + test. Unit-tested with fakes.
- [ ] `presentation/reminder_settings_screen.dart`: renders per state (status text,
      Enable `FilledButton`, Test `OutlinedButton` when enabled, iOS/denied/unsupported
      guidance, test-result SnackBar). All strings via ARB; colors/text via Theme;
      `TextField` convention n/a (no inputs). Widget-tested per state with `l10nTestApp`.

## 6. Wiring + entry point + i18n
- [ ] go_router: add a nested, DI-built route to `ReminderSettingsScreen` (per
      `lifeos-web-nav-go-router`); add a reminders entry card in `_MoreBody`
      (`health_scaffold.dart`) navigating to it.
- [ ] `main.dart`: construct `HttpPushRepository(baseUrl: apiBaseUrl, client)`,
      `BrowserWebPushGateway`, the use cases, and the controller factory; obtain the
      Firebase idToken the same way `ChaodaysImportController` does.
- [ ] i18n: add en + zh-Hant (+ zh fallback) strings for all new copy; run
      `flutter gen-l10n` and commit `lib/l10n/generated/*`.

## 7. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` green.
