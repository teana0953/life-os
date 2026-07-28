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

### D1 — 六種狀態，不是「有預測／沒預測」兩種

後端 `predictedNextStart = 最後一次起始日 + 平均週期`，**沒有被夾到未來**（`menstrual-stats.ts`）。所以「印出那個日期」在真實使用下有兩種讀起來像壞掉的情況：

1. **預測日已過**：一陣子沒記錄 → 「下次生理期：7月2日」而今天是 7月28日。
2. **人正在經期中**：顯示下個月的日期，技術上對，但此刻最沒用。

分成六種：

| 條件 | 顯示 |
| --- | --- |
| 今天 ∈ **任何一段**已記錄的週期 `[start, end ?? +∞]` | 進行中・第 N 天（有預測時**才**加次要文字「下次預計 {日期}」） |
| 一筆紀錄都沒有 | 還沒有生理期紀錄 |
| 只有一筆（後端要兩筆才算得出週期） | 再記錄一次就能預測下次 |
| `predicted > today` | {日期}・還有 N 天 |
| `predicted == today` | 預計今天 |
| `predicted < today` | 預計 {日期}・已晚 N 天 |

**順序就是優先序**：進行中先於一切；沒有預測時不編一個出來。

**「資料不足」要分成兩句**：後端是 `periods.length < 2` 才回 null，所以 0 筆的人「再記錄一次」仍然不會有預測 —— 而 0 筆正是每個新使用者的起始狀態，對他講一句做不到的承諾是最糟的第一印象。0 筆說「還沒有生理期紀錄」，1 筆才說「再記錄一次就能預測下次」。

**「進行中」仍然要把預測講出來**（次要文字，例如「下次預計 8月20日」）。很多人只記開始不記結束 —— 那筆一直開著的話，這張卡就永遠不顯示 issue #84 要的那個日期，等於功能對那群人不存在。

**但預測可能是 null**：「只有一筆紀錄、今天落在那一筆裡」就是 ongoing + 沒有預測 —— 而那正是新使用者**第一次記錄當天**的狀態（記了開始、還沒記結束），一點都不罕見。這時只顯示「進行中・第 N 天」，次要那行整個不出現。**不要對它做 `!`。**

**分支順序寫死，全程不用 `!`**：`ongoing`（預測可有可無）→ `predicted == null` 時看 periods 筆數分 `noRecords`／`needsOneMore` → 再比日期分 `upcoming`／`today`／`overdue`。目前「≥2 筆 ⟺ 有預測」是後端的不變式（`periods.length < 2` 才回 null，且 overview 不分頁），但那是後端的事 —— 依賴它寫成 `!` 的話，哪天後端改成只回最近 N 筆就會變成 null crash。

「已晚 N 天」把一個讀起來像壞掉的日期變成訊號 —— 可能真的晚了，也可能只是忘了記，兩種都值得使用者看一眼。**不要把預測夾到未來**（例如一直加週期直到超過今天）：那會把「你已經 26 天沒記錄了」偽裝成一個乾淨的未來日期，是最糟的一種安靜。

**「進行中」的 N 天用那一段的起始日算，不設上限**。忘了關的舊紀錄會顯示「進行中・第 45 天」，那是對的 —— 它在說「你忘了關」。設上限或改回顯示預測，等於幫使用者把自己的錯誤藏起來。

**判斷要掃過 `overview.periods`，不能只看 `lastPeriod`**。`lastPeriod` 是**起始日最大**的那一次（後端 `periods[periods.length - 1]`，升冪）。使用者補記一段「開始得更早、結束得更晚」的週期時，`lastPeriod` 不是涵蓋今天的那一段 —— 生理期頁的月曆用**全部** periods 判斷，會把今天標成經期日，總覽卡卻會說「還有 12 天」。兩個畫面對同一天講相反的話。取「涵蓋今天且起始日最大的那一段」，程式碼一樣短。

### D2 — 天數用「兩邊都剝成 UTC 午夜」再相減

紀錄裡的日期是 `_parseDate` 出來的**本地午夜**，但 `clock()` 回的是**帶時分秒**的當下。直接 `difference(...).inDays` 會被那幾個小時吃掉一天：下午三點打開 app、預測日是明天，`inDays` 會算成 0，卡片就說「預計今天」。**這是每天下午都會發生的**，不是邊界情況。

所以：`today` 先剝成 `DateTime.utc(t.year, t.month, t.day)`，紀錄日期也剝成 `DateTime.utc(...)`，再相減。跨 DST 的一小時偏移順帶也一起解決了。

**不要寫「切換 TZ 環境變數」的測試**：Dart 的本地時區在 process 啟動就定了，單一測試裡切不掉；而且 UTC 與 Asia/Taipei 都沒有 DST，`TZ=UTC flutter test` 對這條完全無效。真正能紅的是**傳一個帶時分秒的 `clock`**（例如 `2026-07-28 15:30`）而預測日是 `2026-07-29`，斷言「還有 1 天」而不是「預計今天」—— 這條在任何時區都會紅。

### D3 — 今天從注入的 clock 來

`DateTime Function() clock = DateTime.now`，比照 `HomeScreen` 的問候語與匯入畫面。沒有它，「還有 N 天」的測試就得跟著真實時鐘跑，只有在特定日期才會紅。

### D4 — 卡片自己不載入資料

`MenstrualController` 已經是 app 級 singleton，且 `HealthScaffold._load()` 已經呼叫 `menstrualController.load(token)`（匯入後的 `DataRevision` 刷新也已經涵蓋它）。卡片只監聽、不自己發請求 —— 多發一次就是同一份資料抓兩次。

### D5 — 載入與錯誤的呈現照多數決

`GoalCard` 與 `HealthCalendarCard` 是「卡片內顯示錯誤」，`CareTodaySummaryCard` 是「安靜保留舊資料」（既有的不一致，記在 #82 的 follow-up）。新卡跟多數：

- 首次載入（還沒有資料）→ 卡內轉圈
- 重新載入（已經有資料）→ **保留現有內容**，不要退回轉圈（#82 的教訓：自動刷新會把畫面打空）
- 錯誤 → 卡內錯誤訊息，**重用既有的 `errorMenstrualLoadFailed`**（三個 ARB 都已經有），不要重開 key
- 401 → 不自己處理，交給 `HealthScaffold` 的 `_overviewNeedsReauth`（**要把 menstrual 加進那個判斷**，否則生理期的 401 不會有重新登入的出口）

`_overviewControllers` 也要加 menstrual，但**理由不是「否則卡片不會重建」**（卡片自己 `addListener`，跟 `GoalCard`／`CareTodaySummaryCard` 一樣）—— 而是 `_overviewNeedsReauth` 只在 scaffold 自己重建時重算，不加的話 menstrual 專屬的 401 要等別的 controller 動一下才會浮出來。

### D6 — 整張卡可點，路由是 `/health/menstrual`

生理期頁是 `/health` 的**巢狀子路由**（`lib/app.dart` 的 `path: ':name'`），記錄分頁自己就是 `context.push('/health/$name')`。`/menstrual` 不存在，而 router 沒有 `errorBuilder` —— 導錯會掉進 go_router 內建的 not-found 畫面。捷徑是這個 issue 一半的需求，測試要用 **production 的 router**，不要自建一個。



`LedgeCard` + `InkWell`，與 `GoalCard`／`CareTodaySummaryCard` 相同。**每種狀態都可點**，包含「還沒有紀錄」—— 那張卡同時是捷徑，而沒資料的人正是最需要捷徑的。

### D7 — 放在月曆之前，不是最後

原本想放最後（最不動既有順序）。但月曆卡是一整格月曆＋三個達成率環，把新卡推到它後面等於手機上必定在第一屏外 —— 而這張卡的全部價值就是「不用點進去就看得到」。

改成 照護 → 目標 → **下次生理期** → 月曆。照護仍在最上面：那是唯一有時效、漏了補不回來的資訊。

## 元件

| 檔案 | 改動 |
| --- | --- |
| `contexts/menstrual/domain/next_period_status.dart`（新） | 純函式：`(overview, today) → NextPeriodStatus`（六選一 + 天數 + 可選預測日）。這是唯一有邏輯的部分，可單獨測 |
| `contexts/menstrual/presentation/next_period_card.dart`（新） | 卡片；監聽 `MenstrualController`，`onOpen` 回呼 |
| `contexts/health/presentation/health_scaffold.dart` | `_OverviewBody` 加卡片（**月曆之前**）、`_overviewControllers` 與 `_overviewNeedsReauth` 加 menstrual |
| `l10n/app_{en,zh,zh_Hant}.arb` | 五種狀態的文案 |

## 不做（YAGNI）

- 把預測夾到未來 —— 見 D1。
- 在總覽上直接記錄生理期 —— 捷徑進去就有，不重複做一個入口。
- 平均週期／平均經期也搬到總覽 —— issue 要的是「下一次是什麼時候」。
- 通知／提醒 —— 完全另一件事。
