# Tasks

## 1. `PushHealthController` (TDD)

- [ ] Test first：`test/contexts/notifications/presentation/push_health_controller_test.dart`。
      fake `WebPushGateway`（可設 `describeEnvironment` / `permissionStatus`）、
      fake `EnableReminders`（記錄呼叫次數、可設回傳 outcome 或丟例外）、
      fake `AuthRepository`（可設 `idToken()` 回 null 或字串，`authStateChanges` 可推值）、
      可控的 `ReminderSettingsController`
- [ ] `lib/contexts/notifications/presentation/push_health_controller.dart`：
      `enum PushHealth { unknown, ok, permissionPrompt, permissionDenied, syncFailed, unsupported }`
      + `PushHealthController extends ChangeNotifier with WidgetsBindingObserver`
- [ ] **`permissionPrompt` 與 `permissionDenied` 一定要是兩個狀態。**
      合併成一個「權限沒開」會讓文案對其中一種是謊話，而**這次事故的實際狀態是
      `prompt`**（Android 重裝 PWA 是把權限重設，不是拒絕）
- [ ] `check({bool force = false})` 的四步順序（**順序本身就是設計，不可重排**）：
      1. `describeEnvironment()` → `iosNeedsInstall` **先於** `supported`（同
         `enable_reminders.dart:22`；iOS Safari 未安裝時 `PushManager` 是隱藏的，
         `supported` 會是 false 但那不是「不支援」）→ `unsupported`
      2. `await authRepository.idToken()` 為 null → **直接 return，狀態不動**
         （不是 `unknown`；登出瞬間把狀態打掉會閃一下 banner）
      3. `permissionStatus()`：`denied` → `permissionDenied`、`prompt` → `permissionPrompt`。
         **return 前不呼叫 `EnableReminders`**（測試要斷言這件事，不能只斷言狀態）
      4. granted → 節流檢查 → `await EnableReminders(idToken)`；`enabled` → `ok`；
         其他 outcome **或丟例外** → `syncFailed`
- [ ] 節流：**只有上一次是 `ok` 才套用**，未滿 1 小時跳過**第 4 步**且**狀態維持不變**；
      非 `ok` 狀態一律重試（權限剛從 denied/prompt 切回 granted 時瀏覽器已作廢舊訂閱，
      那正是最需要重訂閱的時刻，用「距上次檢查」當基準會把它擋掉）。
      `force: true` 略過節流。時間來源用可注入的 `DateTime Function()`（預設 `DateTime.now`），
      否則節流測試只能靠 sleep。**只存記憶體**，不要碰 `shared_preferences`
- [ ] **節流只能跳過第 4 步，絕不能寫成 `check()` 開頭的 early return。**
      第 1–3 步每次都要跑，否則「上次 ok → 使用者關掉權限 → 回前景落在節流窗內 →
      停在 `ok`、不出 banner」，正是 07-29 那次事故原樣重演。
      **要有一條專門釘這件事的測試**：`ok` 之後把 `permissionStatus` 改成 `denied`、
      在節流窗內再 `check()`，斷言狀態變成 `permissionDenied`。
      只驗「節流窗內沒呼叫 `EnableReminders`」的測試對 early-return 寫法照樣會過
- [ ] 重入保護：一次只跑一個 `check`，比照 `reminder_settings_controller.dart:79`
- [ ] **三個觸發點**：
      - `authRepository.authStateChanges` 收到 `true` → `check()`。
        **不是在 `runApp` 當下呼叫一次** —— Firebase 在 web 上還原登入是非同步的，
        冷啟當下 `currentUser` 通常是 null，第 2 步會 return、狀態永遠停在 `unknown`
      - `didChangeAppLifecycleState(AppLifecycleState.resumed)` → `check()`，
        寫法照 `pwa_update_controller.dart:42`。**只有 `resumed` 觸發**
      - 監聽 `ReminderSettingsController`，`status` **從非 `enabled` 變成 `enabled`**
        → `check(force: true)`。
        **這條是必要的不是保險**：banner →「去開啟」→ `/reminders` → 啟用 → 返回總覽
        全程在同一個 SPA 頁面內，不會產生 `resumed`；沒有它 banner 會賴著不走
- [ ] **邊緣觸發，不可寫成 `if (settings.status == enabled) check(force: true)`**：
      記住上一次的 `status`，只在轉換的那一刻動作。`sendTest`
      （`reminder_settings_controller.dart:102`）在 `status` 已是 `enabled` 時
      每次呼叫都會 `notifyListeners` 兩次，level-triggered 會變成兩次**繞過節流**的
      完整 subscribe + POST
- [ ] 覆蓋清單：`iosNeedsInstall` / `!supported` / 登出 / `denied` / `prompt`
      （後兩者含「零呼叫 `EnableReminders`」斷言）/ granted+enabled / granted+丟例外 /
      granted+非 enabled outcome / `ok` 後節流跳過（狀態仍是 `ok`）/
      **節流窗內權限翻成 `denied` → 狀態變 `permissionDenied`** /
      **`syncFailed` 後不節流** / `force` 穿透節流 / 重入 /
      `authStateChanges` 觸發 / `resumed` 觸發 / settings 轉 `enabled` 觸發 /
      **settings 已是 `enabled` 時再 notify，呼叫次數不變**

## 2. `PushOffBanner` 共用元件 (TDD)

- [ ] Test first：`test/contexts/notifications/presentation/push_off_banner_test.dart`
- [ ] `lib/contexts/notifications/presentation/push_off_banner.dart`：
      **只吃 `PushHealth`**，依狀態渲染或回 `SizedBox.shrink()`。
      沒有 `onRetry` 參數 —— `syncFailed` 不顯示，就沒有任何使用者動作要回呼
- [ ] 視覺沿用 `care_items_screen.dart:252` 既有那段：`LedgeCard` 包
      `Icons.notifications_off_outlined`（`colorScheme.error`）+ 文字 + 尾端 `TextButton`。
      **原樣搬過來，不要順手改版型** —— 三處要長得一樣，改版是另一件事
- [ ] `permissionPrompt` →「通知未開啟，提醒不會送達」+「開啟通知」→
      `context.push('/reminders')`
- [ ] `permissionDenied` →「手機通知被關掉了，提醒不會跳出來」+「去開啟」→
      `context.push('/reminders')`
- [ ] **`syncFailed` 不顯示**，沒有「重試」鍵。同步失敗不代表推播壞掉
      （後端訂閱還在、照常送達），最常見的觸發是離線開 PWA；顯示等於對使用者說謊，
      而且按幾次重試都不會好。靜默重試，下次觸發再試
- [ ] `ok` / `unknown` / `unsupported` / `syncFailed` → 不顯示（四個狀態各一條測試，
      **`unsupported` 與 `syncFailed` 兩條最重要**：前者在 iOS 未安裝的環境掛
      「通知被關掉了」是謊話，後者是離線誤報）
- [ ] 訊息不靠顏色傳達 —— 純文字讀起來就完整（可及性驗收條件）
- [ ] l10n：**三個 ARB 檔都要改**（`app_en.arb` 含 `@` 描述、`app_zh.arb`、`app_zh_Hant.arb`）。
      `app_zh.arb` 在這個 repo **不是空殼**，是全量同步的
- [ ] **既有 key 給 `permissionPrompt` 用，不是給 `denied`**：
      `careRemindersPushOffBanner` / `careRemindersPushOffAction`
      （`app_en.arb:1789/1793` = "Notifications aren't on — reminders won't be delivered" /
      "Turn on notifications"；`app_zh.arb:402/403`、`app_zh_Hant.arb` 對應處）
      的字面就是「還沒開啟」，語意上是 `prompt`
- [ ] **只新增 `permissionDenied` 的兩個 key**（訊息 + 動作），共兩個新 key。
      `syncFailed` 不需要文案，`retry` 也不再需要

## 3. 掛載三處 (TDD)

- [ ] `health_scaffold.dart:380`：`CareTodaySummaryCard` **上方**插入 `PushOffBanner`，
      **前提 `careTodayController.slots.isNotEmpty`**
- [ ] `care_today_screen.dart:450`：ListView **首項**插入，同一個前提
- [ ] **前提條件不可省略**：`CareTodaySummaryCard` 對零排程使用者也會渲染
      （setup-prompt 分支），所以總覽是每個健康模組使用者都會看到的畫面；
      沒有前提的話，所有從不用提醒的人都會長期看到「還沒開啟通知」
- [ ] **今日照護的 loading / error 分支刻意不顯示**（那兩個分支是各自 return 的獨立
      `Scaffold`，見 `care_today_screen.dart:425` 附近）。空清單雖然在同一個 ListView 內
      也不會顯示 —— 空清單就代表 `slots` 是空的，被前提擋掉；寫測試釘住這個結果
- [ ] `care_items_screen.dart:252`：既有那段換成 `PushOffBanner`，改讀
      `PushHealthController` 而不是 `reminderSettingsController.pushOn`，
      **且不套用 `slots.isNotEmpty` 前提**（進到管理頁已經表態要用提醒）
- [ ] `care_items_screen.dart` 的 `reminderSettingsController` 參數：確認拿掉之後
      該畫面還有沒有用到它（`initState` 有 `load()` 與 listener），沒有就一併移除
      —— **屬於本次改動造成的孤兒**（CLAUDE.md §3）；還有用到就留著
- [ ] **移除 `ReminderSettingsController.pushOn`**（`reminder_settings_controller.dart:49`）
      與它的測試（`reminder_settings_controller_test.dart:212` 的 `pushOn` 群組）。
      實查過：唯一消費者就是 `care_items_screen.dart:252` 這條 banner，
      提醒設定頁自己走的是 `status` —— 改讀 push health 之後它就是本次製造的孤兒
- [ ] **三個畫面都要訂閱 `PushHealthController`，漏掉的話整個功能白做。**
      `check()` 第 4 步是 await、settings 那條觸發更是百分之百非同步 ——
      狀態變了畫面不重建的話，「修好權限後 banner 消失」不會發生：
      - 總覽：`_OverviewBody`（`health_scaffold.dart:356`）是 `StatelessWidget`，
        只有 `_HealthScaffoldState._overviewControllers`（`health_scaffold.dart:165`，
        目前六個）notify 才 `setState` —— **把 `pushHealthController` 加進那個清單**
      - 今日照護：`_CareTodayScreenState.initState`（`care_today_screen.dart:228`）
        目前只 `widget.controller.addListener` —— **多加一個**，`dispose` 也要移除
      - 照護管理：`care_items_screen.dart:116` 已有現成的雙 listener 寫法，換掉即可
- [ ] 三個畫面各一組 widget 測試：`permissionPrompt` / `permissionDenied` 出現、
      `ok` / `unknown` / `unsupported` / `syncFailed` 不出現、點擊導向 `/reminders`；
      **總覽與今日照護額外驗「零排程時不顯示」**
- [ ] **三處各補一條「狀態改變後畫面跟著更新」的測試**：先渲染成 `ok`，
      把狀態改成 `permissionDenied` 並 `notifyListeners`，pump 後 banner 出現。
      沒有這條就測不出「畫面沒訂閱 controller」這個失效 ——
      只設好狀態再 pump 的測試會過，實機卻不動
- [ ] 既有測試 `care_items_screen_test.dart:389` / `:423`（`pushOn=false/true` 的
      banner 斷言）斷言的是被取代的判斷來源，**要改寫成新行為，不是刪掉**

## 4. DI 接線

- [ ] `main.dart`：建一個 `PushHealthController`（`webPushGateway`、既有的
      `EnableReminders`、`authRepository`、`reminderSettingsController`），
      `WidgetsBinding.instance.addObserver(...)`
- [ ] 訂閱 `authStateChanges` 觸發首次 `check()`（**不要在 `runApp` 當下直接呼叫**）
- [ ] `EnableReminders` 目前建在 `main.dart:239` 的 `ReminderSettingsController`
      建構子引數裡 —— 抽成具名變數共用同一個實例，不要 new 第二個
- [ ] **傳遞路徑比看起來長**，三個畫面沒有一個是 `main.dart` 直接建的：
      `main.dart` → `App`（`app.dart:201` 建構子加一個 required 欄位）→
      go_router builder（`/care-items` 在 `app.dart:460`、`/care-today` 在 `app.dart:467`、
      `/health` 在 `app.dart:487`）→ `HealthScaffold`（`health_scaffold.dart:106`）→
      `_OverviewBody`（`health_scaffold.dart:363`）
- [ ] 連帶要改的既有測試建構點（不先列出來會在 §5 最後才一次炸開）：
      `test/app_test.dart`、`test/app_pending_deep_link_test.dart`、
      `test/contexts/health/presentation/health_scaffold_test.dart:610`、
      `test/contexts/notifications/presentation/care_today_screen_test.dart`、
      `test/contexts/notifications/presentation/care_items_screen_test.dart:389/423`

## 5. 收尾

- [ ] `flutter analyze` 零警告
- [ ] `flutter test` 全綠，且看到 `All tests passed!`（沒有紅字不等於通過）
- [ ] `bash scripts/lint-actions.sh`
