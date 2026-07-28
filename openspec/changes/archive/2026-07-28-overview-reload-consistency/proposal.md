## Why

[issue #100](https://github.com/teana0953/life-os/issues/100)：總覽四張卡對「已經有資料了，然後重新載入失敗」各做各的。

| 卡 | 現況 |
| --- | --- |
| `CareTodaySummaryCard` | **完全靜默** —— 仍顯示舊 summary，沒有錯誤提示、沒有重試、沒有「這是舊資料」 |
| `GoalCard` | 整張換成紅色錯誤卡（舊內容消失）+ 重試 |
| `HealthCalendarCard` | 整張換成紅色錯誤卡 + 重試 |
| `NextPeriodCard` | 整張換成紅色錯誤卡 + 重試 |

**四個 controller 失敗時都保留舊資料**，差異 100% 在卡片的 render 判斷。

**這不是兩個刻意決定打架。** #82（匯入後自動刷新）的 design 只講 reload **中**不要打空：

> Reload must not blank the overview. Each controller's `load()` resets its status to `loading`…

care 卡「失敗也靜默」是實作把條件寫成 `status != loaded && !_hasLoadedOnce` 順帶產生的；同一個 commit 對 `GoalCard` 只改 `loading && goal == null`、錯誤分支沒動。兩張卡從此分岔，而 design 從沒為「失敗也靜默」寫過理由。

**#82 之後這從罕見事件變常態**：匯入完成會自動觸發整個總覽 reload。四張卡同時失敗時，畫面上是「一張安靜的舊資料 + 三張紅卡」，而且總覽從 1148px 塌到 800px（實測，單是月曆卡就吃掉 274px）。

## What Changes

**兩種失敗分開處理** —— 這不是不一致，是兩件不同的事：

- **從沒載入過**：沒有內容可留，卡片顯示失敗 + 重試（三張卡已經這樣做；**`CareTodaySummaryCard` 目前是整張消失**，要修）
- **已有內容、重新載入失敗**：保留內容 + 標記「沒有更新到」+ 重試，重試只重載自己那張

四張卡都打**不同的 endpoint**（`/api/care/today`、`/api/weight-goal`+`/api/body-profile`、`/api/health-calendar`、`/api/menstrual`），`Future.wait` 並行、各自 catch。一張失敗不代表其他張也失敗，所以重試的顆粒度就是一張卡。

**`GoalCard` 現在的行為要改，而它的註解明說了相反的話**：

> This must not hinge on `goal == null`: a reload that fails after a successful first load would otherwise silently keep showing the stale card.

那個顧慮是對的 —— **在沒有任何訊號的前提下**。標記就是那個訊號。所以這不是推翻它，是補上它缺的那一半。

## Capabilities

### Modified Capabilities

- `dashboard-goal-card`: 新增一條跨卡需求 —— 總覽卡 SHALL 區分「從未載入」與「載入過但刷新失敗」，後者 SHALL 保留內容並標記，且 SHALL NOT 與剛更新過的內容長得一樣。
- `care-today-ui`: 「error 時仍顯示 nothing」改成「從未載入才顯示 nothing；首次載入失敗要說出來」。
- `health-calendar-card`: 錯誤呈現改成「沒有內容時顯示錯誤卡，有內容時保留並標記」。

## 不做

- **趨勢分頁的兩張卡**（`TrendCard`、`CareAdherenceCard`）有同樣的問題，但 issue #100 的範圍是總覽四張。另開。
- **常駐的手動 refresh 按鈕** —— 使用者確認只在失敗時出現。app 本來就會自動載入（首次進入 + 匯入完成的 `DataRevision`），常駐按鈕沒有要解的問題。
- **`dashboard-trend-card/spec.md:8` 的「the dashboard's second card, below the goal card」是過時文字**（那兩張卡早就搬到趨勢分頁了），與新需求的「總覽 tab 的卡」讀起來會打架。既有問題，不在這輪修。
- 401 的處理不動 —— 已經由 `HealthScaffold._overviewNeedsReauth` 整頁接管。
