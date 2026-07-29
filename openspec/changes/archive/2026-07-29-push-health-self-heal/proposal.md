## Why

2026-07-29 早上 08:00 的用藥提醒沒送達。查到底：

- 後端一切正常 —— cron 準時 materialize（08:00:22）、nag 照跑（08:06:21）、
  `care_occurrence.last_send_outcome = 'sent'`、`last_send_detail` 是 null。
- 但 `sent` 只代表 push service 回 2xx（`web-push-sender.ts:135`）。FCM 收下了，
  訊息死在裝置端。
- 真正原因：使用者為了驗 PWA 捷徑而**移除重裝 PWA**，Android 把站台通知權限重設。
  瀏覽器不再顯示推播，`push_subscription` 裡 2026-07-24 建的那筆卻還在。

**這是一種資料上完全看不見的失效**：後端每天都說送出去了，使用者每天都沒收到。

前端本來有一道防線 —— `care_items_screen.dart:252` 的「通知未開」banner，
由 `care-reminders-ui` 的 "Warn when reminders won't be delivered because notifications
are off" 那條需求驅動。它沒攔到，因為**它只掛在照護管理頁**，而使用者平常不開那頁：
提醒本來就是推來的，使用者只在總覽和今日照護之間活動。

而且那條需求的判斷（`ReminderSettingsController.pushOn`）**只看瀏覽器權限**。
權限是 granted 但訂閱已經漂掉的情況（重裝、清站台資料、SW 被換掉），它會說「正常」。

## What Changes

**訂閱層的不一致由程式靜默修復，只有作業系統層權限被關才警告使用者。**

這條分界是整個提案的核心。訂閱漂掉時使用者唯一能做的事就是進提醒設定「關掉再打開」，
那就是 re-subscribe —— App 自己做得到，不該叫使用者做。反過來，通知權限被關掉是
系統設定，程式改不了，只能告訴使用者並帶他過去。

具體：

- **新增 `PushHealthController`**：**登入狀態確立時**、每次 App 回前景時、
  以及提醒設定頁啟用成功的當下檢查。權限 granted 就重跑既有的 `EnableReminders`
  （fetch VAPID → `subscribe()` → `POST /api/push/subscribe`）把訂閱補回來；
  權限沒給就標記為需要使用者處理，**不發任何網路請求**。
  觸發點綁「登入確立」而不是「App 啟動」——Firebase 在 web 上還原登入是非同步的，
  冷啟當下查 `currentUser` 會拿到 null，然後就再也不會檢查了。
  提醒設定頁那條也是必要的：banner →「去開啟」→ 設定頁 → 啟用 → 返回總覽
  全程在同一個 SPA 頁面內，**不會產生 `resumed`**，沒有它 banner 會賴著不走。
- **`EnableReminders` 原封不動重用**，這是本提案幾乎不長程式碼的原因：權限已 granted 時
  `requestPermission()` 直接 resolve 不跳提示、`subscribe()` 帶同一組 VAPID key 冪等回傳
  既有訂閱、`POST /api/push/subscribe` 是 upsert on endpoint。
- **警告改掛在使用者真的會看的地方**：總覽照護卡上方、今日照護清單頂端，
  照護管理頁那條改用同一個共用元件與同一個狀態來源。
- **總覽與今日照護以「今天有 care 排程」為前提**：那兩個畫面每個健康模組使用者都會看到
  （`CareTodaySummaryCard` 對零排程使用者也會渲染 setup prompt），
  沒有前提的話，從不使用提醒的人會長期被告知通知沒開 —— 他們沒有提醒可漏。
  管理頁不設前提：進得去就已經表態要用提醒。
- **只有權限兩態會出 banner**：被關掉（去開啟）、**從沒被問過**（開啟通知）。
  `prompt` 與 `denied` 必須分開 —— 併起來必有一種是謊話，而且
  **這次事故的實際狀態正是 `prompt`**（Android 重裝是把權限重設，不是拒絕）。
- **同步失敗完全不顯示，靜默重試。** 同步失敗不代表推播壞掉：後端訂閱還在、
  照常送達，我們只是這次沒補成，而最常見的觸發是**離線開 PWA**。顯示等於對使用者說
  「可能收不到」但其實收得到，而且沒有任何使用者動作能清掉它。
  這條也讓 banner 回到本提案自己立的分界：**只有作業系統層權限才警告**。
- 不支援 Web Push 的環境（iOS 未安裝到主畫面、瀏覽器沒有 PushManager）一律不顯示 ——
  在那些環境掛「通知被關掉了」是謊話。
- **三個畫面都要訂閱 `PushHealthController`**：檢查是非同步的，
  畫面沒訂閱的話狀態變了也不會重繪，「修好權限後 banner 消失」就不會發生。

**零後端改動。** 不需要「查詢自己訂閱」的 API：不比對、直接冪等重送，不一致就不存在。

## Capabilities

### Modified Capabilities

- `reminder-notifications-ui`（既有 capability，本 change 加兩條需求）—— (1) 登入確立時、回前景時、啟用成功時
  SHALL 自動把推播訂閱同步回後端（權限已授予時），成功與失敗都 SHALL 對使用者無感，
  節流 SHALL 只在成功後套用，啟用觸發 SHALL 是邊緣觸發；(2) 推播無法送達時 SHALL 在
  使用者日常會看到的畫面（總覽、今日照護、照護管理）呈現一致的警告，SHALL 區分
  「權限被關」與「從沒被問過」，SHALL NOT 呈現同步失敗，總覽與今日照護 SHALL 以
  「今天有 care 排程」為前提，且畫面 SHALL 隨狀態改變即時更新。

- `care-reminders-ui`: "Warn when reminders won't be delivered because notifications are off"
  改成讀共用的 push health 狀態（不再自己用 `pushOn` 判斷）、區分「被關掉」與「從沒問過」、
  並明確排除「環境不支援」的情況。管理頁仍然顯示警告，只是不再是唯一顯示的地方，
  且明確不套用其他兩處的「有排程才顯示」前提。

## 順帶清掉的孤兒

- **`ReminderSettingsController.pushOn`**：唯一的消費者就是 `care_items_screen.dart:252`
  那條 banner（提醒設定頁自己走的是 `status`），改讀 push health 之後它就是本次改動
  製造的孤兒，照 CLAUDE.md §3 要清掉，連同它的測試
  （`reminder_settings_controller_test.dart:212` 的 `pushOn` 群組）。

## 不做

- **後端「連續漏回應」偵測**（同一格連續 nag N 次都沒有 `care_log` 就標記可疑）：
  這是本次事故的另一半 —— 後端資料看不出靜默失效。價值獨立、屬於後端 repo，另案。
- **後端查詢自己訂閱的 API**：自我修復讓比對變得沒必要。
- **節流時間持久化**：冷啟本來就檢查一次，存起來省不到什麼。
- **banner 直接觸發權限請求**：`prompt` 狀態技術上做得到（`denied` 則不行，
  瀏覽器不會再跳提示），但那會多一條與提醒設定頁重複的啟用路徑，
  兩邊的錯誤處理要各維護一份。統一導到 `/reminders`。

## 已知限制（明知接受）

- **VAPID key 輪換會讓自我修復永久失敗**：`subscribe()` 的冪等只在 key 相同時成立，
  不同時規格是丟 `InvalidStateError`，而 `WebPushGateway` 刻意沒有 `unsubscribe()` 出口。
  目前沒有輪換計畫；真要輪換得先補那個出口。
- **自我修復不可觀測**：反覆靜默重送訂閱的 App 跟真的健康的 App 長得一模一樣 ——
  正是本次事故「後端說 sent，其實沒人看到」的同構翻版，只是搬到前端。
  「零後端改動」是划算的取捨，但這個風險是被明知接受的。
