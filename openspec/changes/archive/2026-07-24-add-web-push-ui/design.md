# Design — Web Push UI (enable notifications + test push)

## Context & scope

Slice 1b of the reminders feature: the frontend that drives the (already live) Web
Push backend. It ships only **enable-notifications + send-test-push**; reminder types
and scheduling UI are later slices. Its whole purpose is to let the user prove, on a
real installed iOS/Android PWA, that a push is received — so the design keeps the
browser-specific glue thin and behind a port, and everything else testable.

## Architecture

New context `lib/contexts/notifications/` (mirrors the repo's context-first Clean
Arch; copy the `import` context layout):

```
domain/
  push_subscription.dart        # value: {endpoint, p256dh, auth}
  push_repository.dart          # PushRepository port (fetchVapidPublicKey, saveSubscription, sendTest) + typed errors
  web_push_gateway.dart         # WebPushGateway port (describeEnvironment, permissionStatus, enableAndSubscribe) + enums
application/
  enable_reminders.dart         # env-check → fetch key → gateway subscribe → save to backend
  send_test_push.dart
infrastructure/
  http_push_repository.dart     # HttpPushRepository (Bearer token, mirrors HttpImportRepository)
  browser_web_push_gateway.dart # BrowserWebPushGateway (package:web + dart:js_interop + push_sw.js)
presentation/
  reminder_settings_controller.dart
  reminder_settings_screen.dart
```

Plus `web/push_sw.js` (static) and a go_router route + a 更多-tab entry.

## Key decisions

- **D1 — `WebPushGateway` port isolates the browser.** The permission prompt, SW
  registration, and `pushManager.subscribe` cannot be exercised by `flutter test` and
  only truly work on a device. Hiding them behind a port keeps the controller/use
  cases fully testable with a fake gateway; `BrowserWebPushGateway` is the thin,
  on-device-verified adapter (the analogue of the backend's `WebPushSender`).

- **D2 — Push SW at a separate scope, never replacing Flutter's SW.** Flutter web
  ships `flutter_service_worker.js` controlling scope `/` (caching). Registering our
  push SW at `/` would clobber it. So `BrowserWebPushGateway` registers
  `navigator.serviceWorker.register('push_sw.js', { scope: '/push/' })` — a narrower
  scope than the script's location, always allowed, creating an independent
  registration that never controls app pages but still receives this subscription's
  push events. `subscribe()` is called on THAT registration.

- **D3 — Environment gating before any prompt.** `describeEnvironment()` reads the
  existing `window.pwaInstall` bridge (`standalone`, `iosHint`) plus feature
  detection (`'serviceWorker' in navigator`, `'PushManager' in window`,
  `'Notification' in window`). The controller resolves to `iosNeedsInstall`,
  `unsupported`, or `idle`.
  **iOS precedence is critical (and easy to get wrong):** on iOS Safari
  (non-standalone) `'PushManager' in window` is **false even on push-capable
  16.4+ devices** — PushManager is only exposed inside the installed standalone PWA.
  So the controller MUST check `iosNeedsInstall` (derived from the UA-based
  `pwaInstall.iosHint`, independent of PushManager detection) **before** resolving to
  `unsupported`; otherwise an iOS Safari user is told "not supported" and never
  reaches the install→enable path — defeating the slice's whole purpose. Order:
  `iosNeedsInstall` (iOS + not standalone) → then `unsupported` (no SW/Push/Notification
  support) → else `idle`.

- **D4 — Controller state machine.** `unsupported` → explain not supported;
  `iosNeedsInstall` → show Add-to-Home-Screen guidance; `permissionDenied` → explain
  how to re-enable in browser settings; `idle` → show Enable button; `enabling` →
  disable button, show progress; `enabled` → show Enabled + the Test-push button;
  `error` → localized, actionable message with retry. `enableReminders` transitions
  idle→enabling→(enabled | permissionDenied | error).

- **D5 — VAPID key → `applicationServerKey`.** The backend returns the public key as
  base64url; `BrowserWebPushGateway` decodes it to a `Uint8Array` for
  `subscribe({ userVisibleOnly: true, applicationServerKey })`.

- **D6 — Two accepted `/push/`-scope tradeoffs.** (a) `notificationclick` cannot
  focus an existing app tab: `clients.matchAll()` only returns clients within the
  registration's scope, and the app runs at `/`, not `/push/` — so `push_sw.js` just
  does `clients.openWindow('/')` (which may open a new tab). We do not claim
  focus-existing. (b) `web/index.html`'s `applyUpdate` currently unregisters **every**
  SW and reloads, which would destroy the `/push/` registration + its subscription on
  each PWA update (leaving a stale endpoint on the backend until re-enable). Scope that
  unregister-all to Flutter's `/` registration so an update no longer kills push. Both
  are consequences of the (correct) non-root scope that protects Flutter's SW.

## UI/UX 設計

- **使用者路徑**:已登入使用者 → 更多 頁點「提醒 / 通知」→ ReminderSettingsScreen。
  主路徑:狀態 `idle` → 點「開啟通知」→ 瀏覽器權限提示 → 允許 → 訂閱並存到後端 →
  狀態 `enabled` → 點「測試推播」→ 顯示送出結果(sent/failed)→ 使用者在裝置收到通知。
  例外路徑:iOS 未加到主畫面(`iosNeedsInstall`)→ 顯示「請先加到主畫面」引導,不顯示
  無效的開啟按鈕;拒絕權限(`permissionDenied`)→ 顯示如何在瀏覽器設定重新開啟;
  不支援(`unsupported`)→ 說明此裝置/瀏覽器不支援;網路/後端錯誤(`error`)→ 可行動訊息 + 重試。
- **介面與一致性**:沿用設計系統——標題與說明文字走 Theme 文字樣式,主要動作用
  `FilledButton`、次要動作用 `OutlinedButton`,卡片用標準圓角/外框;測試結果用 SnackBar
  呈現。進入點卡片與 更多 頁既有項目(設定、匯入)一致。所有字串走 ARB(en + zh-Hant)。
- **狀態設計**:`enabling` 時開啟按鈕轉 loading 且不可重複觸發;測試推播進行中同樣防重入;
  `enabled` 才顯示測試按鈕;各非可用狀態(unsupported / iosNeedsInstall / permissionDenied)
  都有明確說明而非空白或無效按鈕。
- **可及性/理解性**:每個錯誤/受阻狀態都告訴使用者「發生什麼 + 下一步怎麼做」(加到主畫面、
  去瀏覽器設定開權限、重試),不是單一通用錯誤;測試推播結果明確顯示成功/失敗數。

## Testing

- **Use cases / controller (unit)**: fake `WebPushGateway` (scriptable env +
  permission + subscribe-or-null) + fake `PushRepository`. Assert each transition:
  unsupported / iosNeedsInstall short-circuit; idle→enabling→enabled on grant;
  →permissionDenied on deny; →error on repository failure; sendTestPush surfaces the
  sent/failed result and re-entrancy is blocked.
- **`HttpPushRepository` (unit)**: mock `http.Client` — Bearer header, snake_case
  bodies, 401 → `PushReauthRequired`, non-2xx → `PushRequestFailed`, parse of
  vapid-public-key and `{sent, failed}`.
- **`ReminderSettingsScreen` (widget)**: inject a fake controller; assert each state
  renders its described UI (button enabled/disabled/loading, the four blocked-state
  messages, the test-result SnackBar) via `l10nTestApp`.
- **Out of scope for `flutter test`** (on-device only, Slice 1b success criterion):
  real SW registration, `pushManager.subscribe`, and push receipt on iOS/Android.
