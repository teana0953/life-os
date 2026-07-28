# 總覽顯示下一次生理期（issue #84）

## 問題

`predictedNextStart` 只出現在生理期頁的統計卡。要看下一次是什麼時候，得走 記錄 → 生理期。

## 研究：chaodays 沒有這個功能

抓 `https://chaodays.app/assets/main-*.js` 逐字看過 i18n：

```
period: { name:"生理期小月曆", period:"生理期", average_circle:"平均週期",
          average_period:"平均經期", period_record:"生理期記錄",
          period_start_end:"生理期起訖日", remark:"備註",
          show_past_year_record:"顯示過去一年記錄", return_month_record:"回到本月記錄" }
```

整份 bundle 裡 `預測`／`預計`／`下次`／`predict`／`next_period` **零命中**。它的 `dashboard`（資訊總覽）是今日體重體脂／今日身體代謝／今日飲食記錄／我的成就／焦點資訊／即將到來的預約課程，**沒有生理期**。

所以「參考 chaodays」在這件事上沒有東西可參考。唯一形式上相近的是它的「即將到來的預約課程」—— 標題＋一行內容＋點進去，就是這張卡的形狀。用詞上 lifeos 早就跟它對齊了（`平均週期`／`平均經期` 一字不差）。

## 設計決策

### D1 — 五種狀態，不是「有預測／沒預測」兩種

後端 `predictedNextStart = 最後一次起始日 + 平均週期`，**沒有被夾到未來**（`menstrual-stats.ts`）。所以「印出那個日期」在真實使用下有兩種讀起來像壞掉的情況：

1. **預測日已過**：一陣子沒記錄 → 「下次生理期：7月2日」而今天是 7月28日。
2. **人正在經期中**：顯示下個月的日期，技術上對，但此刻最沒用。

分成五種：

| 條件 | 顯示 |
| --- | --- |
| 今天 ∈ 最近一次週期 `[start, end ?? +∞]` | 進行中・第 N 天 |
| `predicted == null` | 還沒辦法預測，再記錄一次就可以 |
| `predicted > today` | {日期}・還有 N 天 |
| `predicted == today` | 預計今天 |
| `predicted < today` | 預計 {日期}・已晚 N 天 |

**順序就是優先序**：進行中先於一切；沒有預測時不編一個出來。

「已晚 N 天」把一個讀起來像壞掉的日期變成訊號 —— 可能真的晚了，也可能只是忘了記，兩種都值得使用者看一眼。**不要把預測夾到未來**（例如一直加週期直到超過今天）：那會把「你已經 26 天沒記錄了」偽裝成一個乾淨的未來日期，是最糟的一種安靜。

**「進行中」的 N 天用最近一次的起始日算，不設上限**。忘了關的舊紀錄會顯示「進行中・第 45 天」，那是對的 —— 它在說「你忘了關」。設上限或改回顯示預測，等於幫使用者把自己的錯誤藏起來。

### D2 — 日期算術用 UTC 正規化

兩邊都是 date-only，但 `DateTime` 是本地時區的。跨 DST 邊界時 `difference(...).inDays` 會少一天。**兩個日期都先轉成 `DateTime.utc(y, m, d)` 再相減**。

本機是 UTC+8、CI 是 UTC，兩種相反的失敗模式這個 repo 都踩過 —— 碰日期的測試要 `TZ=UTC` 複驗。

### D3 — 今天從注入的 clock 來

`DateTime Function() clock = DateTime.now`，比照 `HomeScreen` 的問候語與匯入畫面。沒有它，「還有 N 天」的測試就得跟著真實時鐘跑，只有在特定日期才會紅。

### D4 — 卡片自己不載入資料

`MenstrualController` 已經是 app 級 singleton，且 `HealthScaffold._load()` 已經呼叫 `menstrualController.load(token)`（匯入後的 `DataRevision` 刷新也已經涵蓋它）。卡片只監聽、不自己發請求 —— 多發一次就是同一份資料抓兩次。

### D5 — 載入與錯誤的呈現照多數決

`GoalCard` 與 `HealthCalendarCard` 是「卡片內顯示錯誤」，`CareTodaySummaryCard` 是「安靜保留舊資料」（既有的不一致，記在 #82 的 follow-up）。新卡跟多數：

- 首次載入（還沒有資料）→ 卡內轉圈
- 重新載入（已經有資料）→ **保留現有內容**，不要退回轉圈（#82 的教訓：自動刷新會把畫面打空）
- 錯誤 → 卡內錯誤訊息
- 401 → 不自己處理，交給 `HealthScaffold` 的 `_overviewNeedsReauth`（**要把 menstrual 加進那個判斷**，否則生理期 401 會被吞掉）

### D6 — 整張卡可點

`LedgeCard` + `InkWell`，與 `GoalCard`／`CareTodaySummaryCard` 相同。**五種狀態都可點**，包含「資料不足」—— 那張卡同時是捷徑，而沒資料的人正是最需要捷徑的。

## 元件

| 檔案 | 改動 |
| --- | --- |
| `contexts/menstrual/domain/next_period_status.dart`（新） | 純函式：`(overview, today) → NextPeriodStatus`（五選一 + 天數）。這是唯一有邏輯的部分，可單獨測 |
| `contexts/menstrual/presentation/next_period_card.dart`（新） | 卡片；監聽 `MenstrualController`，`onOpen` 回呼 |
| `contexts/health/presentation/health_scaffold.dart` | `_OverviewBody` 加卡片（最後）、`_overviewControllers` 與 `_overviewNeedsReauth` 加 menstrual |
| `l10n/app_{en,zh,zh_Hant}.arb` | 五種狀態的文案 |

## 不做（YAGNI）

- 把預測夾到未來 —— 見 D1。
- 在總覽上直接記錄生理期 —— 捷徑進去就有，不重複做一個入口。
- 平均週期／平均經期也搬到總覽 —— issue 要的是「下一次是什麼時候」。
- 通知／提醒 —— 完全另一件事。
