# 下拉重新整理 + 各畫面顯示上次載入時間（pull-to-refresh）

## 背景

issue #104：健康模組沒有整批「重來一次」的動作。`HealthScaffold._load()` 並行載 13 個
controller，只在 `initState` 與 `DataRevision.bump()`（chaodays 匯入成功、照護紀錄編輯
兩個呼叫點）跑。分頁是 `IndexedStack`（刻意，保捲動位置），切走切回不重載。
全 repo `RefreshIndicator` 用量 0。網路斷又回來、四張總覽卡全失敗時，只能點四次單卡重試
或關 app 重開。使用者追加：頁面顯示上次拉資料的時間。

## 兩個載入世界（這決定了整個設計）

- **總覽 + 趨勢**共用 `HealthScaffold._load()`（一次載 13 個 controller）。它們一起載，
  所以**共用一個時間戳**成立。
- **4 個追蹤畫面**（水／體徵／排便／運動）是獨立 route，各自用 `TrackerDayScreen` mixin
  的 `reloadDay(day)` 載自己的 day-keyed 資料，**不歸 `_load()` 管**，各自在不同時間載。

**所以不能用單一全局時間戳** —— 追蹤畫面顯示 `_load()` 的時間會謊報。各源記自己的。

## 元件

### 1. `HealthScaffold`：`_scheduleLoad()` 回 Future + `lastOverviewLoadAt`

現況：`_scheduleLoad()`（`health_scaffold.dart:198`）fire-and-forget、不回 Future，
但已有合併去重 —— 載入中再觸發設 `_reloadPending`，當前 `_load()` 完成後再跑一次。

改法（**沿用同一套 `_loading`/`_reloadPending`，不另立第二套**）：

- `_scheduleLoad()` 改成回 `Future<void>`，在**這一輪（含被 coalesce 掉、稍後補跑的那輪）
  真正結束時**才 resolve。作法：持一個 `Completer<void>? _refreshCompleter`，
  **在整個 in-flight 期間重用同一個**（不是每輪建新的）：
  - 進來時若 `_refreshCompleter == null` 才建一個；否則回既有那個的 future。
  - `_load` 的 `whenComplete`：還有 `_reloadPending` → 清旗標、續跑 `_load`，
    **completer 不動、也不重建**（續跑那輪不碰 `_refreshCompleter`）。
  - 沒有 pending → `_refreshCompleter!.complete()` 一次，然後 `_refreshCompleter = null`。
  - 這樣「載入中再觸發」的兩次呼叫回**同一個** future，只 complete 一次，也不會永不 complete
    （proposal review 的 non_blocking：不可每輪建新 completer，否則手勢等到的 future 永不 resolve
    或被 complete 兩次）。
  - `initState`/`_onRevisionChanged` 的既有呼叫點丟棄回傳值即可（`unawaited` 或不接）。
- `RefreshIndicator.onRefresh` 直接 `return _scheduleLoad()` —— 手勢的 spinner 會等到
  future resolve 才收，正好是「這輪載完」。
- 新增 `DateTime? _lastOverviewLoadAt`，在 `_load()` 之後**只有這輪至少一張卡真的載成功時**
  才寫 `widget.clock()`。透過 `_OverviewBody` 與 `_TrendBody` 傳下去顯示。
  - **不能用「`Future.wait` 有沒有丟例外」當成功判斷**（proposal review 的 blocking）：
    四張卡的 controller 各自 catch 錯、**不 rethrow**，所以斷網時只要 token fetch 成功
    （Firebase 常回快取 token）→ 四卡全失敗，`Future.wait` 仍然 resolve → 時間戳照跳到
    現在。這正好在 issue #104 要救的情境下謊報「剛更新」，也違反 spec「只在成功時更新」。
  - **決策**：時間戳看 controller 的 **status**，不看 `Future.wait`。`_load()` 之後檢查
    overview/trend 的六個 controller，**至少一個是 `loaded`**（`WeightGoalStatus.loaded` /
    `TrendStatus.loaded` / `HealthCalendarStatus.loaded` / `MenstrualStatus.loaded` /
    `CareTodayLoadStatus.loaded`；care adherence 同理）才更新 `_lastOverviewLoadAt`。
    全部失敗（含斷網四卡全紅）→ **不更新**，時間戳保留上次成功值。
  - 這也讓總覽/趨勢的時間戳語意跟追蹤畫面**一致**（都看 controller status 的成功），
    消掉原設計「scaffold 看 Future.wait、tracker 看 status」的不對稱。
  - 語意 = 「這批資料上次至少載到一部分的時間」。對總覽誠實：它們一起載，
    有東西新鮮就代表這個時間點抓到過資料；全失敗就不動，使用者看到的是舊時間 + #103 的
    「沒更新到」標記，兩者一致。

### 2. `TrackerDayScreen` mixin：`reloadDay` 回 Future + 內建 RefreshIndicator + 時間戳

`lib/shared/widgets/tracker_day_nav.dart`。

- `reloadDay(String day)` 由 `void` 改成 `Future<void>`。四個實作
  （water/vitals/bowel/exercise screen）本來就是 `controller.load(idToken, day)`
  （回 Future），加個 `return` 即可，或 `=> widget.controller.load(...)`。
- mixin 新增包裝方法 `Widget refreshable({required Widget child, Future<void> Function()? onRefresh})`
  回 `RefreshIndicator(onRefresh: onRefresh ?? () => reloadDay(viewedDay), child: child)`。
  預設走 `reloadDay(viewedDay)`（water/bowel/exercise 三畫面直接用）；
  **vitals 傳自己的 `onRefresh`**（帶 `hasUnsavedChanges` 確認閘，見下方「vitals 邊界」）。
  **統一在 mixin 做一次**，三個無 draft 的畫面不各寫一份。
- 時間戳：mixin 記 `DateTime? _lastLoadedAt`。但 `reloadDay` 是抽象方法、mixin 不知道
  controller 有沒有載成功 —— **時間戳的真相在 controller**。
  **決策**：`lastLoadedAt` 記在**各 controller**（water/vitals/bowel/exercise controller），
  在 status 轉成功那一刻寫 `_clock()`；失敗分支不寫。mixin/畫面從 controller 讀來顯示。
  這樣「成功才更新、失敗保留」由 controller 的既有 status 流程自然保證，不必 mixin 猜。

### 3. 各 controller 的 `lastLoadedAt`（水／體徵／排便／運動）

每個 controller 加 `DateTime? lastLoadedAt` + 可注入 `DateTime Function() _clock`
（預設 `DateTime.now`，建構子選填，比照既有慣例）。`load()` 成功分支
（status = loaded 之前/之後）寫 `lastLoadedAt = _clock()`；needsReauth/error 分支不寫。

總覽/趨勢的時間戳走 `HealthScaffold` 的 `_lastOverviewLoadAt`（見元件 1），
不動那 6 個 overview controller —— 它們共用 `_load()`，時間戳屬於 scaffold 不屬於個別卡。

### 4. 顯示：共用一個小 widget `LastLoadedLabel`

`lib/shared/widgets/last_loaded_label.dart`。吃一個 `DateTime?`，null 時回
`SizedBox.shrink()`（從沒載成功過就不顯示），否則顯示「上次更新 HH:mm」。
`HH:mm` 用 `TimeOfDay.format(context)` 或 `MaterialLocalizations`，跟隨系統 12/24 制。
文案的固定部分（「上次更新 」）走 ARB placeholder。
- 總覽/趨勢：擺在各自 `ListView` 頂端（下拉區之內，跟著捲）。
- 追蹤畫面：擺在 `dayNavHeader` 之下、內容之上。

## UI/UX 設計

### 使用者路徑

**主路徑（下拉重整）**：使用者發現卡片是舊的（或標了「沒更新到」）→ 在總覽/趨勢/追蹤畫面
下拉 → spinner 轉 → 該畫面的資料重載 → 成功則卡片更新、頂端時間戳跳到現在；
失敗則卡片保留舊內容（#103 已有的標記），時間戳**不動**（仍是上次成功的時間）。

**例外路徑（載入中再下拉）**：合併去重 —— 不會併發第二次載入，spinner 等到最終那輪載完才收。

**不出現下拉的地方**：記錄分頁（純導覽磁貼）。

### 介面與一致性

- `RefreshIndicator` 用 Material 預設（`Theme.of(context)` 的 primary 色），
  不自訂顏色。全 app 首次引入，之後其他清單沿用同一套。
- **內容短於視窗時 `RefreshIndicator` 預設不觸發**（proposal review 的 non_blocking）：
  `ListView` 不可捲時下拉手勢接不到。所有包進去的 `ListView` 都要設
  `physics: const AlwaysScrollableScrollPhysics()`，否則短內容（趨勢只有兩張卡、
  追蹤畫面當天沒資料）在實機下拉會**靜默失效** —— 測試看不出來，要特別釘。
- 時間戳是一行小字（`textTheme.bodySmall` / `labelSmall`，`onSurfaceVariant` 之類的弱化色），
  不搶卡片焦點。三個畫面同一個 `LastLoadedLabel`，長相一致。

### 狀態設計

- **從沒載成功過**（`lastLoadedAt == null`）：不顯示時間戳（不是顯示「從未」）——
  首次進入正在載時、或一直失敗時，寧可不顯示也不要顯示假資訊或嚇人。
- **載入中**：`RefreshIndicator` 的 spinner 是唯一過場；時間戳維持上一個值不閃動。
- **失敗**：時間戳保留上次成功值；卡片層級的錯誤/標記由 #103 的機制處理，這裡不重複。

### vitals 未存草稿的邊界（proposal review 的 non_blocking）

vitals controller 把當天資料載進**可編輯 draft**，畫面在本地改、`save` 才 upsert；
`reloadDay`→`load` 會 `_applyRecord` **覆寫 draft**（同 day 也是）。所以在 vitals 畫面
下拉重整，會靜默吃掉還沒存的輸入。

**決策**：vitals 畫面的下拉 `onRefresh`，若 `controller.hasUnsavedChanges` 為 true，
**先跳一個確認**（「有未儲存的變更，重新整理會捨棄，要繼續嗎？」走 ARB），
使用者確認才 `reloadDay`；否則不重載、手勢直接收。沒有未存變更就照常重載。
其餘三個追蹤畫面（water/bowel/exercise）沒有這個 draft-覆寫問題，不需確認 ——
所以這段確認邏輯放在 **vitals 畫面覆寫 mixin 的 `onRefresh`**，不是塞進共用 mixin
（避免為單一畫面的邊界污染四畫面共用路徑）。

### 可及性

- 時間戳是純文字，螢幕閱讀器讀得到；不靠顏色傳達（它只是輔助資訊，不是警告）。
- `RefreshIndicator` 是 Flutter 內建、本身支援輔助技術的重整語意。

## 測試策略

- `HealthScaffold._scheduleLoad()` 回的 Future：載一次會在載完 resolve；
  **載入中再觸發，兩個 future 都等到最終那輪**（合併去重下 completer 只 complete 一次）；
  token fetch 丟例外時 future 仍 resolve（不能卡住 spinner）。
- `_lastOverviewLoadAt`：成功後 = 注入 clock 的值；`_load` 丟例外時不更新。
- 總覽/趨勢 widget 測試：`RefreshIndicator` 存在、下拉觸發重載；`LastLoadedLabel` 顯示注入
  clock 的時分字串；`lastLoadedAt==null` 時不顯示。
- 4 個 controller：`load` 成功寫 `lastLoadedAt`、needsReauth/error 不寫（用注入 clock 驗）。
- `TrackerDayScreen` mixin / 四個畫面：`reloadDay` 回 Future；下拉會呼叫 `reloadDay(viewedDay)`；
  時間戳顯示 controller 的 `lastLoadedAt`。
- widget 測試比照既有慣例：`l10nTestApp`、注入 fake controller、`setSurfaceSize` 記得
  `addTearDown(() => tester.binding.setSurfaceSize(null))`。

## 刻意不做（YAGNI）

- 記錄分頁下拉（不載資料）。
- 自動偵測網路恢復重載（要連線依賴，且「網路回來」≠「後端回來」）。
- 切分頁時重載（`IndexedStack` 刻意保捲動位置，改掉每次切分頁打 13 個請求）。
- 單一全局時間戳（追蹤畫面不共用 `_load()`，會謊報）。
- 相對時間「3 分鐘前」（要 tick 更新，成本不成比例；絕對 `HH:mm` 就夠）。
- 記錄分頁以外、菜單/設定等純導覽畫面的時間戳（沒有「資料」概念）。
