## Why

[issue #104](https://github.com/teana0953/life-os/issues/104)：健康模組沒有整批「重來一次」的動作。

`HealthScaffold._load()` 並行載 13 個 controller，只在兩個時候跑：`initState` 與
`DataRevision.bump()`（全 repo 只有 chaodays 匯入成功、照護紀錄編輯兩個呼叫點）。
分頁容器是 `IndexedStack`（刻意，保捲動位置），切走切回不重載。全 repo `RefreshIndicator`
用量是 **0**。

所以使用者在捷運上打開 app、四張總覽卡全失敗之後，唯一復原路徑是：分別點四張卡的重試
（[#103](https://github.com/teana0953/life-os/pull/103) 之後才有），或關 app 重開。
趨勢分頁兩張卡、各追蹤器也一樣。

#103 讓單張卡失敗那條路很好走，但**全部失敗**（最常見的：網路斷）反而暴露出沒有整批重來。

使用者追加：**頁面要顯示上次拉資料的時間** —— 斷網保留舊資料時，使用者需要知道「這是幾點的」。

## What Changes

**下拉重新整理 + 各畫面顯示自己那次載入的時間。**

- **下拉重整範圍**：總覽、趨勢兩個分頁（共用 `_load()`）+ 4 個追蹤畫面
  （水／體徵／排便／運動，共用 `TrackerDayScreen` mixin）。**記錄分頁不做** ——
  它只是導覽磁貼、不載資料。
- **總覽 + 趨勢**的 `ListView` 各包一層 `RefreshIndicator`，`onRefresh` 走
  `HealthScaffold` 新開的「回傳 `Future` 的重載路徑」。既有的 `_scheduleLoad()` 是
  fire-and-forget，但已有合併去重（`_loading`/`_reloadPending`）；新路徑**沿用同一套狀態**，
  只是回一個會在該輪（含被 coalesce 的第二輪）完成時 resolve 的 `Future`，不另立第二套機制。
- **4 個追蹤畫面**在 `TrackerDayScreen` mixin 統一加一層 `RefreshIndicator`，
  `onRefresh` 走 `reloadDay(viewedDay)` 並等它完成。`reloadDay` 目前是 `void`，
  改成回 `Future<void>`，四個實作跟著改（它們本來就是 `await controller.load(...)`）。
- **上次載入時間**：每個載入來源記自己的 `lastLoadedAt`，顯示在該畫面頂端。
  **不做單一全局時間戳** —— 追蹤畫面不共用 `_load()`，各自在不同時間載不同東西，
  一個全局數字會謊報。總覽/趨勢共用 `_load()` 完成時間（它們確實一起載）；
  每個追蹤畫面顯示自己那次 `reloadDay` 的時間。`lastLoadedAt` **只在載入成功時更新**，
  失敗不覆蓋（顯示的是上次成功拉到的時間，跟 #103「保留舊資料 + 標記」一致）。
- 時間來源用可注入的 `clock`（`DateTime Function()`，預設 `DateTime.now`），
  比照 repo 既有慣例（home greeting clock、reminders 節流 clock），否則測不了。
  顯示走三個 ARB，講人話（「上次更新 HH:mm」），不是 ISO。

## Capabilities

### Modified Capabilities

- `health-navigation`：新增一條需求 —— 有資料的分頁與追蹤畫面 SHALL 支援下拉重新整理，
  SHALL 顯示各自資料上次成功載入的時間，且該時間 SHALL 在載入失敗時保留不變。

## 不做

- **記錄分頁的下拉**：它只是導覽磁貼、不載資料，下拉沒有意義。
- **自動偵測網路恢復後重載**：要引進連線狀態依賴，且「網路回來」≠「後端回來」。
  下拉是使用者說了算，成本低很多（issue 也這麼判）。
- **切分頁時重載**：`IndexedStack` 是刻意的（保捲動位置與展開狀態），
  改掉會讓每次切分頁打 13 個請求。
- **單一全局時間戳**：追蹤畫面不共用 `_load()`，全局數字會謊報。
- **相對時間**（「3 分鐘前」）：需要 tick 更新，成本不成比例；顯示絕對 `HH:mm` 就夠。
