# 推播失效偵測與自我修復（push-health-self-heal）

## 背景：一次真實的靜默失效

2026-07-29 早上 08:00 的用藥提醒沒有送達。追查結果：

- 後端 `care_occurrence` 記 `last_send_outcome='sent'`、`last_send_detail=null`，cron 準時
  materialize（08:00:22）、nag 也照跑（08:06:21）。
- `web-push-sender.ts:135` 的 `sent` 只代表 push service 回 2xx。FCM 收下了，訊息死在裝置端。
- 真正原因：使用者為了驗 PWA 捷徑而移除重裝 PWA，Android 把站台通知權限重設。
  瀏覽器端不再顯示推播，但 `push_subscription` 裡 2026-07-24 建的那筆還在。

兩個結構性問題：

1. **後端資料看不出來。** `sent` 對「權限被關」這種失效模式完全無感，SQL 查不出「其實沒人看到」。
2. **前端的警告攔不到。** 「通知未開」banner 只掛在照護管理頁（`care_items_screen.dart:252`），
   使用者平常不會開那頁。

本 change 處理第 2 點（前端）。第 1 點（後端連續漏回應偵測）另案，見「刻意不做」。

## 設計原則：能自己修的就不要叫使用者修

訂閱漂掉時，使用者唯一能做的事就是進提醒設定「關掉再打開」——那就是 re-subscribe，
App 自己就做得到。所以：**訂閱層的不一致由程式靜默修復，只有真正需要人操作的
（作業系統層權限）才出警告。**

這也是為什麼不需要「後端查詢自己訂閱」的 API：不比對、直接冪等重送，不一致就不會存在。

## 元件

### 1. `PushHealthController`（新）

`lib/contexts/notifications/presentation/push_health_controller.dart`

`ChangeNotifier` + `WidgetsBindingObserver`。依賴 `WebPushGateway`、`EnableReminders`、
`AuthRepository`、`ReminderSettingsController`。

狀態：

```dart
enum PushHealth {
  unknown,            // 還沒檢查完 —— 不顯示任何東西
  ok,                 // 訂閱有效
  permissionPrompt,   // 從沒被問過（瀏覽器 default）
  permissionDenied,   // 被使用者/系統關掉
  syncFailed,         // 權限有，但訂閱同步失敗
  unsupported,        // 這個環境根本不支援 Web Push
}
```

**`prompt` 與 `denied` 必須分開**，不能像初版那樣併成一個 `permissionOff`：

- 兩者文案不同（「還沒開啟」vs「被關掉了」），併起來必有一種是謊話。
- **這次事故的實際狀態是 `prompt`** —— Android 重裝 PWA 是把權限**重設**，不是拒絕。
  `prompt` 可以在 App 內用 `Notification.requestPermission()` 直接問回來，`denied` 不行。
  初版 proposal 那句「權限被關掉後瀏覽器不會再跳提示」只對 `denied` 成立。

`check({bool force = false})` 的順序（順序本身就是設計，不可重排）：

1. `describeEnvironment()` → `iosNeedsInstall` 或 `!supported` → `unsupported`。
   `iosNeedsInstall` 要在 `supported` 之前判，同 `enable_reminders.dart:22`
   （iOS Safari 未安裝時 `PushManager` 是隱藏的，`supported` 會是 false 但那不是「不支援」）。
2. `await authRepository.idToken()` 為 null → **直接返回，狀態不動**（登出中，不是失效）。
3. `permissionStatus()`：`denied` → `permissionDenied`；`prompt` → `permissionPrompt`。
   兩者都**不發任何網路請求** —— 權限沒給時 subscribe 必定失敗。
4. granted → 節流檢查（見下）→ `await EnableReminders(idToken)`。
   回 `enabled` → `ok`；其他 outcome 或丟例外 → `syncFailed`。

`EnableReminders`（`enable_reminders.dart:21`）**原封不動重用**，這是整個設計省下大量程式碼的關鍵：

- 權限已 granted 時 `Notification.requestPermission()` 直接 resolve，不跳提示。
- `pushManager.subscribe()` 帶**同一組** VAPID key 會回傳既有訂閱，沒有訂閱時才真的建一個。
- `POST /api/push/subscribe` 是 upsert on endpoint（`push.ts:26`），重複打零成本。

**零後端改動。**

#### 節流

**只有上一次結果是 `ok` 才套用節流**，且未滿 1 小時就跳過第 4 步；跳過時**狀態維持不變**
（上次是 `ok`，現在仍然是 `ok`）。第 1–3 步是同步且免費的，每次都做。

「只在 `ok` 時節流」這條是刻意的：權限從 `denied`/`prompt` 剛切回 `granted` 的那一刻，
正是最需要立刻重訂閱的時刻（瀏覽器在權限被撤銷時會作廢既有 subscription），
若用「距上次檢查」當節流基準就會把它擋掉。

節流**只跳過第 4 步**，絕不是 `check()` 開頭的 early return —— 第 1–3 步每次都要跑。
否則「上次 `ok` → 使用者關掉權限 → 回前景落在節流窗內 → 停在 `ok`、不出 banner」，
正是 07-29 那次事故原樣重演。這需要一條專門的測試釘住
（`ok` 之後把權限改成 `denied`，在節流窗內 `check()`，斷言狀態變 `permissionDenied`）；
只驗「窗內沒呼叫 `EnableReminders`」對 early-return 寫法照樣會過。

`force: true` 略過節流，只給「設定頁啟用成功」那條觸發用。時間來源用可注入的
`DateTime Function()`（預設 `DateTime.now`），否則節流測試只能靠 sleep。
**只存在記憶體** —— 冷啟本來就會做一次，持久化沒有價值。

重入保護：一次只跑一個 `check`，比照 `reminder_settings_controller.dart:79` 的 `enabling` 守衛。

#### 觸發時機（三條，缺一不可）

1. **登入完成** —— 訂閱 `authRepository.authStateChanges`，收到 `true` 就 `check()`。
   **不是在 `runApp` 當下呼叫一次**：Firebase 在 web 上還原登入狀態是非同步的，
   冷啟當下 `currentUser` 通常還是 null，第 2 步會直接 return、
   狀態永遠停在 `unknown`。綁 `authStateChanges` 同時解決「冷啟」與「剛登入」兩種情況。
2. **回前景** —— `didChangeAppLifecycleState(AppLifecycleState.resumed)`，
   寫法照 `pwa_update_controller.dart:42`。PWA 常連開好幾天不關，
   「App 開著的時候權限被關掉」不是邊角情況。
3. **提醒設定頁啟用成功** —— `PushHealthController` 監聽 `ReminderSettingsController`，
   在 `status` **從非 `enabled` 變成 `enabled`** 的那一刻 `check(force: true)`。

   **第 3 條是必要的，不是保險。** banner →「去開啟」→ `/reminders` → 按 Enable → 回總覽，
   全程在同一個 SPA 頁面內，**不會產生 `resumed`**。沒有這條，最常見的修復動線做完之後
   banner 會賴著不走 —— 使用者會以為沒修好。依賴方向是 health 監聽 settings，
   不是反過來（`ReminderSettingsController` 不該知道有誰在看它）。

   **必須是邊緣觸發**（記住上一次的 `status`，只在轉換時動作），不能寫成
   `if (settings.status == enabled) check(force: true)`。`sendTest`
   （`reminder_settings_controller.dart:102`）在 `status` 已經是 `enabled` 時
   每次呼叫都會 `notifyListeners` 兩次 —— level-triggered 會變成兩次
   **繞過節流**的完整 subscribe + POST。

   邊緣觸發之後仍然會在啟用成功的當下多跑一次 subscribe + POST，
   跟設定頁剛做完的事重複。冪等所以無害，刻意接受：換來的是 banner 一定會消失。

### 2. `PushOffBanner`（新共用 widget）

把 `care_items_screen.dart:252` 那段抽出來共用。依 `PushHealth` 顯示兩種文案：

| 狀態 | 訊息 | 動作 |
|---|---|---|
| `permissionPrompt` | 通知未開啟，提醒不會送達 | 開啟通知 → `context.push('/reminders')` |
| `permissionDenied` | 手機通知被關掉了，提醒不會跳出來 | 去開啟 → `context.push('/reminders')` |

`ok` / `unknown` / `unsupported` / **`syncFailed`** 一律不顯示。

#### 為什麼 `syncFailed` 不顯示

**同步失敗不代表推播壞掉。** 後端那筆訂閱還在、還會正常送達，我們只是「這次沒補成」。
而最常見的觸發不是後端掛掉，是**離線開 PWA** —— 每次回前景都跑 `check()`，
離線時第 4 步必定丟例外。若顯示 banner，三個畫面會同時告訴使用者「可能收不到」，
但推播其實照常會來，「重試」按幾次也不會好。

這跟「對從沒開過通知的人說被關掉了」是同一類假警報。本設計的分界是
**只有作業系統層權限才警告** —— `syncFailed` 是訂閱／網路層，違反自己立的規則。

`syncFailed` 仍然是一個真實狀態（它讓節流不生效、下次觸發會再試），只是不呈現給使用者。

**代價（明知接受）**：真的永久同步不了（例如 VAPID key 輪換，見「已知限制」）會完全靜默。
本輪接受，因為沒有輪換計畫，而且分不出「暫時離線」與「永久壞掉」就必然誤報其一。

#### 文案與 ARB

`permissionPrompt` **沿用既有的 `careRemindersPushOffBanner` / `careRemindersPushOffAction`**
（`app_en.arb:1789/1793`、`app_zh.arb:402/403`、`app_zh_Hant.arb` 對應處）——
那兩個 key 的現值就是「通知未開啟，提醒不會送達」/「開啟通知」，
語意上正好是 `prompt` 而不是 `denied`。

`permissionDenied` **新增兩個 key**（訊息 + 動作），這是本 change 唯一新增的文案。

**三個 ARB 檔都要改** —— `app_zh.arb` 在這個 repo 不是空殼，是全量同步的。

### 3. 掛載三處與「有排程才顯示」的前提

- `health_scaffold.dart:380` 總覽的 `CareTodaySummaryCard` 上方 —— **有排程才顯示**
- `care_today_screen.dart:450` ListView 首項 —— **有排程才顯示**
- `care_items_screen.dart:252` 改用共用元件 —— **不設前提，永遠依狀態顯示**

前提條件：`careTodayController.slots.isNotEmpty`。

**為什麼總覽與今日照護要設前提**：`CareTodaySummaryCard` 對零排程使用者也會渲染
（它的 setup-prompt 分支），所以總覽是**每個健康模組使用者都會看到的畫面**。
沒有前提的話，所有從來不用提醒的使用者都會長期看到「還沒開啟通知」——
他們沒有提醒可漏，這對他們純粹是噪音。既有 banner 之所以沒這個問題，
正是因為它只掛在 `care_items_screen`（使用者已經表態要用提醒的畫面），
而管理頁因此不需要前提。

`slots.isNotEmpty` 剛好就是「setup prompt vs 真的有摘要」的分界，跟卡片自己的分支一致。

**已知取捨**：只有週一排程的使用者，週二在總覽看不到 banner。可接受——
當天沒有任何提醒要送，也就沒有東西會漏；他週一還是會看到。

**今日照護的 loading / error 分支不顯示 banner**，這是刻意的：那兩個分支是各自 return 的
獨立 `Scaffold`（`care_today_screen.dart:425` 附近），banner 掛在 ListView 首項。
在「連今天有什麼都還沒讀到」的畫面上疊一條推播警告，會讓使用者分不清是哪件事壞了。

空清單（`_EmptyState`）雖然在同一個 ListView 內，但**也不會顯示** —— 空清單就代表
`slots` 是空的，被上面的前提擋掉了。這與「今天沒排程就不警告」一致，不是遺漏。

`ReminderSettingsController.pushOn`（`reminder_settings_controller.dart:49`）
**一併移除**：它唯一的消費者就是 `care_items_screen.dart:252` 這條 banner
（提醒設定頁自己走的是 `status` 那條路），改讀 push health 之後它就是
本次改動製造的孤兒，照 CLAUDE.md §3 要清掉，連同它的測試。

### 4. 三個畫面都必須訂閱這個 controller

**這是最容易漏掉、漏掉就整個功能白做的一步。** `check()` 的第 4 步是 await（網路），
第 3 條觸發點（設定頁啟用成功）更是百分之百非同步 —— 狀態變了但畫面不重建的話，
「修好權限後 banner 消失」在總覽與今日照護根本不會發生。

- 總覽：`_OverviewBody`（`health_scaffold.dart:356`）是 `StatelessWidget`，
  只有 `_HealthScaffoldState` 的 `_overviewControllers`（`health_scaffold.dart:165`，
  目前六個）notify 時才 `setState` 重建 —— **`pushHealthController` 要加進那個清單**。
- 今日照護：`_CareTodayScreenState.initState`（`care_today_screen.dart:228`）
  目前只 `widget.controller.addListener` —— **要多加一個 listener**（並在 `dispose` 移除）。
- 照護管理：`care_items_screen.dart:116` 已經有「多監聽一個 controller」的現成寫法，
  把 `reminderSettingsController` 換成 `pushHealthController` 即可。

### 5. DI

`main.dart` 建一個 `PushHealthController`、`WidgetsBinding.instance.addObserver`、
訂閱 `authStateChanges`。`EnableReminders` 目前建在 `main.dart:239` 的
`ReminderSettingsController` 建構子引數裡 —— 抽成具名變數共用同一個實例，不要 new 第二個。

**傳遞路徑比看起來長**，三個畫面沒有一個是 `main.dart` 直接建的：
`main.dart` → `App`（`app.dart:201` 的建構子要多一個 required 欄位）→
go_router 的 builder（`/care-items` 在 `app.dart:460`、`/care-today` 在 `app.dart:467`、`/health` 在 `app.dart:487`）→ `HealthScaffold`（`health_scaffold.dart:106`）→
`_OverviewBody`（`health_scaffold.dart:363`）。

連帶要改的既有測試建構點：`test/app_test.dart`、`test/app_pending_deep_link_test.dart`、
`test/contexts/health/presentation/health_scaffold_test.dart:610`、
`test/contexts/notifications/presentation/care_today_screen_test.dart`、
`test/contexts/notifications/presentation/care_items_screen_test.dart:389/423`。

## UI/UX 設計

### 使用者路徑

**主路徑（權限被關或從沒開過）**：使用者某天發現提醒沒跳 → 開 App 進總覽 →
照護卡上方一條 banner（依狀態說「被關掉了」或「還沒開啟」）→ 點動作 → 提醒設定頁 →
按啟用（`prompt` 會跳系統權限對話框，`denied` 則依頁面指示去系統設定）→
啟用成功的當下 `PushHealthController` 被通知並重檢 → 回總覽時 banner 已經消失。

**主路徑（訂閱漂掉）**：使用者完全不會看到任何東西。App 回前景時靜默補上訂閱，
下一則提醒正常送達。這是刻意的 —— 使用者無從得知也無須得知。

**例外路徑（修復失敗，例如離線）**：**同樣什麼都不顯示。** 後端訂閱還在、推播照常送達，
只是這次沒補成；下次回前景自動再試。詳見「為什麼 `syncFailed` 不顯示」。

**不出現的情況**：推播正常、還沒檢查完、同步失敗、iOS 未安裝到主畫面、
瀏覽器不支援 Web Push、使用者登出中、今天沒有任何 care 排程
（總覽與今日照護；管理頁不受排程前提限制）。

### 介面與一致性

沿用 `care_items_screen.dart:252` 既有 banner 的視覺語彙：`LedgeCard` 包
`Icons.notifications_off_outlined`（`colorScheme.error` 色）+ 文字 + 尾端 `TextButton`。
抽成共用元件後三處長相一致，使用者在哪一頁看到都是同一個東西。

不使用 SnackBar 或 Dialog：這是持續狀態不是一次性事件，被滑掉或按掉之後
問題還在，使用者卻再也看不到。

### 狀態設計

- **loading**：`check` 執行中不顯示任何過渡狀態。第 1–3 步是同步的，第 4 步在背景，
  為它閃一個 spinner 只會製造視覺噪音。**沒有使用者主動觸發的動作**（`syncFailed`
  不顯示、也就沒有「重試」鍵），所以不存在「按了沒反應」的問題。
- **錯誤**：`syncFailed` 不呈現給使用者，靜默重試。
- **空/未知**：`unknown`（尚未檢查完）不顯示 banner —— 寧可晚一秒出現，
  也不要在還不知道的時候先嚇使用者一跳。
- **邊界**：登出中（`idToken()` 為 null）維持前一個狀態不動，避免登出瞬間閃一下 banner。
  節流跳過時同樣維持前一個狀態。
- **狀態改變一定要重繪**：三個畫面都訂閱 `PushHealthController`（見上面第 4 節），
  否則 banner 只會在剛好被別的 controller 連帶重建時才更新。

### 可及性/理解性

- 訊息講**後果**不講機制：「提醒不會跳出來」而不是「push subscription 失效」。
- **會顯示的每種狀態都附可執行的下一步**（開啟通知／去開啟），不留死路。
  反過來說，沒有可執行下一步的狀態（`syncFailed`）就不顯示。
- banner 是一般 widget 樹節點，螢幕閱讀器可讀；icon 有語意色，
  但**訊息本身不靠顏色傳達** —— 拿掉顏色後文字仍然說得完整。

## 測試策略

`PushHealthController` 配 fake `WebPushGateway` / fake `EnableReminders` /
fake `AuthRepository` / fake `ReminderSettingsController`：

- `unsupported`：`iosNeedsInstall=true`、`supported=false` 各一
- 登出（`idToken()` 回 null）→ 狀態不動、不呼叫 gateway
- `denied` → `permissionDenied`；`prompt` → `permissionPrompt`；
  兩者都**斷言沒有呼叫 `EnableReminders`**
- granted + `EnableReminders` 回 `enabled` → `ok`
- granted + `EnableReminders` 丟例外 → `syncFailed`
- granted + `EnableReminders` 回非 `enabled` outcome → `syncFailed`
- 節流：`ok` 後 1 小時內再 `check()` 不呼叫 `EnableReminders` 且狀態仍是 `ok`；
  `force: true` 會呼叫；**上次是 `syncFailed` 時不套用節流**
- 重入：`check()` 執行中再呼叫一次，`EnableReminders` 只被呼叫一次
- 觸發：`authStateChanges` 發 `true` → `check`；`resumed` → `check`；
  `ReminderSettingsController.status` 從非 `enabled` 變 `enabled` → `check(force: true)`
- **邊緣觸發**：`status` 已經是 `enabled` 時再 `notifyListeners`，
  `EnableReminders` 的呼叫次數**不變**（這條專門釘 `sendTest` 的重複通知）

三個畫面各一組 widget 測試：banner 在 `permissionPrompt` / `permissionDenied` 出現、
在 `ok` / `unknown` / `unsupported` / **`syncFailed`** 不出現、點擊導向 `/reminders`；
總覽與今日照護額外驗**零排程時不顯示**；
三處都要有一條「controller 狀態改變後畫面跟著更新」的測試
（先渲染成 `ok`，改成 `permissionDenied` 並 notify，pump 後 banner 出現）——
沒有這條就測不出「畫面沒訂閱 controller」這個失效。

`BrowserWebPushGateway` 照舊不寫自動化測試（真實瀏覽器 API，實機才驗）。

## 實機驗證（自動化測不到）

**第 1 項要最先驗** —— 整條「回前景重新同步」押在它成立：

1. App 開著不關，切到系統設定關掉通知權限，切回 App → banner 出現。
   **若不成立**（`didChangeAppLifecycleState` 在 Flutter web 沒送達），
   退路是改用 web 的 `visibilitychange` 事件當觸發來源，其餘設計不變。
   引用的 `pwa_update_controller.dart:42` 證明不了這件事 —— 它同時掛了 15 秒的
   `Timer.periodic`（`pwa_update_controller.dart:38`），兩條路任一條成立它都會動。
2. 關掉系統通知權限 → 開 App → 總覽與今日照護都看得到 banner。
3. 點動作 → 到提醒設定頁 → 啟用 → **不重開 App 直接返回總覽，banner 已消失**。
4. 飛航模式 + 權限開著 → 三個畫面**都沒有** banner（同步失敗是靜默的）；
   關掉飛航模式後回前景 → 一樣沒有 banner，推播照常送達。
5. 沒有任何 care 排程的帳號 + 權限關著 → 總覽**沒有** banner，管理頁**有**。

## 已知限制（接受，不在本輪處理）

- **VAPID key 輪換會讓自我修復永久失敗。** `pushManager.subscribe()` 的冪等只在
  `applicationServerKey` 與既有訂閱**相同**時成立；不同時規格是丟 `InvalidStateError`，
  而 `WebPushGateway` 刻意沒有 `unsubscribe()`（`web_push_gateway.dart:20` 明寫 YAGNI）。
  後端換 key 之後每次 `check()` 都會落到 `syncFailed`，而 `syncFailed` 是靜默的 ——
  使用者與程式都不會察覺，提醒就這樣停了。目前沒有輪換計畫；
  真要輪換時得先補 `unsubscribe()` 出口，並重新考慮「永久失敗要不要出聲」。
- **自我修復沒有留下任何可觀測痕跡。** 一個每小時靜默重送訂閱的 App，
  跟一個真的健康的 App，在任何地方都長得一模一樣 —— 這正是本次事故
  「後端說 sent，其實沒人看到」的同構翻版，只是搬到前端。
  「零後端改動」是划算的取捨，但這個風險是被明知接受的，不是沒想到。

## 刻意不做（YAGNI）

- **後端查詢自己訂閱的 API**：自我修復讓比對變得沒必要。
- **連續漏回應偵測**（同一格連續 nag N 次都沒有 `care_log` 就標記可疑）：
  這是後端的事，價值獨立，另案。
- **節流時間持久化**：冷啟本來就檢查一次，存起來省不到什麼。
- **banner 直接觸發權限請求**（`prompt` 狀態技術上做得到）：多一條與提醒設定頁
  重複的啟用路徑，兩邊的錯誤處理要各維護一份。統一導到 `/reminders`。
