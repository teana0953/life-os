## Why

Issue teana0953/life-os#193：「通知點進去後會到非預期的頁面且畫面會僵住都無法操作」。

實際跑過程式碼與探測測試後，這句抱怨對應到三個各自獨立、但會一起發作的缺陷：

1. **目的地與通知內容無關。** `web/push_sw.js` 的 `push` handler 對所有推播一律寫
   `data: { path: data.path || '/care-today' }`，而後端的 wire payload 是
   `{title, body, data:{ack}}`、從來不送 `path`（SW 自己的註解就寫著「No explicit path
   from the backend yet」）。但走同一支 SW 的推播不只照護提醒——**測試推播與預算警示也走
   同一條**（SW 內 ack 的註解明講「test pushes and budget alerts carry none」）。於是點一則
   預算警示會被丟到「今日照護」：一個跟該通知毫無關係的頁面。這就是「非預期的頁面」。

2. **交接的路徑沒有驗證，不匹配就整頁變成 go_router 的英文 `Page Not Found`。**
   探測測試證實：`PendingDeepLink(path: '/no-such-route')` 會讓 app 停在
   `Page Not Found`、首頁被蓋掉、**沒有任何例外被丟出**。`_buildRouter()` 沒有設
   `errorBuilder` 也沒有 `onException`（已 grep 確認）。這條路徑不是假想的：push SW 刻意
   **不**隨 app 更新被 unregister（前一次 change 的 design D6b），所以寫交接的 SW 與讀交接的
   Flutter app 可以是不同版本，一邊認得的路徑另一邊不一定有。

3. **載入卡住就永遠卡住，而且再點一次通知也救不回來。** 探測測試證實：`getToday` 停在
   in-flight（Workers/Neon 520 那種真實形狀）時，通知推開的 `CareTodayScreen`
   `status` 永遠停在 `loading`、spinner 永遠轉、沒有逾時、沒有錯誤、沒有重試；接著**再點一次
   通知**，因為 `CareTodayController._fetching` 這個共用 in-flight 旗標從沒被放掉，
   `reloadQuietly` 直接 return（實測 `calls` 停在 1，第二個請求根本沒送出去），畫面完全不動。
   同一形狀也存在於 `PendingDeepLinkController._checking`：`take()` 若永不 settle
   （Cache Storage 被封鎖／隱私模式），該旗標整個 session 都放不掉，之後每一次通知點擊都被靜默丟棄。
   這就是「畫面僵住都無法操作」。

另外兩個放大症狀的次要缺陷：每次交接都無條件 `push` 一層，探測測試量到連點 8 則通知要按 8 次返回
才回得到首頁；以及暖啟動的交接只靠 `postMessage` 信號與 `resumed`，兩者都沒發生時（`focus()`
失敗改走 `openWindow`，而 Android WebAPK 只是把既有視窗帶到前景、不重載也不送信號）交接會留在
Cache 裡，使用者被帶到前景卻停在原本那一頁——同樣是「非預期的頁面」。

## What Changes

- **通知帶著自己的目的地。** SW 顯示通知時把該通知**自己的**目的地存進
  `notification.data`；`notificationclick` 只轉交它。缺目的地的通知（舊版 SW 顯示、還留在
  匣裡的那些，以及後端還沒開始送 `path` 的種類）不再被硬塞成 `/care-today`，而是走一個明確的
  「沒有指定目的地」語意。
- **交接的路徑先驗證再導航。** app 只接受自己這個版本真的認得的路徑；認不得就當作沒有交接
  （安靜地正常開啟），永遠不會把使用者丟到 `Page Not Found`。
- **router 補上 `errorBuilder`：** 任何不匹配的位置（交接、舊書籤、手打網址）都落在一個本地化、
  有明確出口的畫面，而不是 go_router 的英文預設頁。
- **每一個會 block 畫面的等待都要有結局。** 今日照護的載入不能無限期停在 spinner：逾時後轉為
  可重試的錯誤狀態；共用的 in-flight 旗標不能因為一個永不 settle 的請求就永久鎖死，
  再點一次通知一定要重新發出請求。
- **交接的消費本身也不能被卡死的 in-flight 旗標吃掉**（`PendingDeepLinkController._checking`
  同一形狀）。
- **同一個目的地不重複疊層**：連續多則通知不會疊出一整疊畫面，返回鍵一次就回到使用者原本那一層。
- **暖啟動的交接不再只靠 `postMessage` + `resumed`**：補上不依賴這兩者的觸發點，讓「被帶到前景
  卻停在原本頁面」不再發生。
- **迴歸測試**針對上述每一條根因，且每一條都必須在修復前真的紅。

## Capabilities

### New Capabilities

（無——本次修的都是既有能力的行為。）

### Modified Capabilities

- `reminder-notifications-ui`：通知點擊的目的地必須來自通知本身而非固定預設；認不得的目的地
  必須安靜略過而非把畫面換成錯誤頁；交接的消費不得被永久卡死的 in-flight 狀態吞掉；同一目的地
  不重複疊層；暖啟動的交接不得只依賴 `postMessage`／`resumed`。
- `care-today-ui`：從通知進入的今日照護不得無限期停在載入中——載入必須有結局（成功、或可重試的
  錯誤），且再次點擊通知一定會重新發出請求。
- `web-navigation-history`：任何不匹配的位置都必須落在本地化、有出口的畫面，而不是框架預設的
  英文錯誤頁，也不得把使用者原本的堆疊變成無法操作的死路。

## Impact

- `web/push_sw.js`：`push` handler 存目的地的方式、`notificationclick` 的交接內容。
- `lib/shared/pwa/pending_deep_link.dart` / `pending_deep_link_controller.dart`：目的地驗證、
  in-flight 旗標的逾時／解鎖、去重與疊層規則、額外觸發點。
- `lib/app.dart`：`GoRouter` 的 `errorBuilder`、可導航路徑的白名單來源、交接接線。
- `lib/contexts/notifications/presentation/care_today_controller.dart` /
  `care_today_screen.dart`：載入逾時與可重試的終局狀態。
- `lib/l10n/*.arb`：新的錯誤畫面文案。
- 測試：`test/app_pending_deep_link_test.dart`、
  `test/shared/pwa/pending_deep_link_controller_test.dart`、
  `test/contexts/notifications/presentation/care_today_controller_test.dart`、
  `web/push_sw.js` 的契約測試。
- **後端相依（不在本 change 內）**：要讓非照護類推播真的連到對的頁面，後端最終必須在 payload 裡
  送 `path`。本 change 讓前端在後端還沒送之前就不再說謊（不再假裝每則通知都是照護提醒）。
