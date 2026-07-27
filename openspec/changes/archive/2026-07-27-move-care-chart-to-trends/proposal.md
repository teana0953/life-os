## Why

`add-care-history-ui`(life-os#83)把照護紀錄做成**一頁兩模式**(AppBar `SegmentedButton`
切清單↔圖表),對齊 CareFlow 的 history_page。上線後使用者指示:**「照護管理的圖表移到趨勢裡」**
——heatmap 是「回顧」語境,健康模組已有專屬的**趨勢**分頁,圖表不該藏在紀錄頁的第二個模式裡。

同時清掉 `.devloop/archive/add-care-history-ui/followup-add-care-history-ui.md` 列的
非阻斷 follow-up(spec 缺第 5 態、heatmap 色彩是唯一訊號、eager ListView、空狀態死路、
未用欄位、日期 helper 重複、紀錄頁是導覽葉節點)。

**明示假設**:「移到」= **移走**,不是兩處都放。紀錄頁的圖表模式整段移除,heatmap
只存在於趨勢分頁一處(同一視覺化兩份實作必然漂移)。

## What Changes

- **`CareHistoryController` 改為自持期間**(關鍵前置,非順手重構):比照
  `TrendController` 持有 `spanDays` + 注入式 `clock`,對外只有 `load(idToken)` 與
  `setSpan(idToken, span)`;移除呼叫端傳 `from`/`to` 的形式。**理由**:趨勢卡要能被
  `HealthScaffold._load()` 以 `load(token)` 驅動,但 span 若留在畫面 `State`,scaffold
  算不出 range、只能硬寫一個值 —— 使用者切到 90 天後任何 `DataRevision` 觸發的重載
  都會把資料洗回硬寫值而選擇器仍顯示 90。畫面與卡片的 `_spanDays` state 一併移除。
  **載入驅動者兩邊不同**:卡片**不**在 `initState` 載入(住在 scaffold 裡,由
  `_load()` 驅動,自己再載會並發);畫面**保留** `initState` → `_load()`
  ——`/care-history` 是與 `/health` 平行的 top-level route,scaffold 不會驅動它,
  拿掉就永遠轉圈。
- **新增趨勢分頁的「照護達成」卡**(`lib/contexts/notifications/presentation/care_adherence_card.dart`):
  **單一** `LedgeCard` = 標題 + 卡內 7/30/90 `SegmentedButton` + headline(達成率/有紀錄
  天數/漏服)+ heatmap + legend(每項帶天數計數)。排在 `TrendCard` **之後**。
  - 從 `care_history_screen.dart` 搬移 `_dayStateColor` / `_upcomingAlpha` / `_Legend` /
    `_LegendDot` / `_HeadlineMetric`(含註解,尤其 upcoming 用 `secondary.withValues(alpha:)`
    而非未設 role 的理由——本 app 是手寫 ColorScheme,未設 role 會 fallback 成 `surface`
    讓格子隱形)。**但 `_HeadlineRow` 自己就是 `LedgeCard`、`_HistoryChart` 是 `ListView` +
    另一個 `LedgeCard`,這兩層 wrapper 必須拆掉**(否則卡中卡),`_HeadlineRow` 降為純 `Row`。
  - Stateful + `addListener`(比照 `TrendCard`/`HealthCalendarCard`);期間切換走
    `controller.setSpan`,**保留內容 + 細進度條**;卡內 loading/error(可重試)/空狀態。
  - **自己的** `CareHistoryController` 實例(`careAdherenceController`,`spanDays: 30`,
    `main.dart` 建立,共用同一個無狀態 `HttpCareHistoryRepository`)。與 `/care-history`
    頁(同樣 `spanDays: 30`)共用實例會互搶 `days`/期間,切分頁就把對方資料洗掉。
  - reauth 併進 `HealthScaffold._overviewNeedsReauth`,**且必須同時加進
    `_overviewControllers`**(該 getter 在 scaffold `build()` 求值,卡片自己的 listener
    只 setState 卡片;漏加會讓 401 出口延遲到別的 controller 恰好 notify);
    載入併進 `_load()` 的 `Future.wait`。
- **`/care-history` 收斂為純紀錄清單頁**:移除 `CareHistoryMode` enum 與 AppBar 模式
  `SegmentedButton`;保留期間選擇、逐日清單、bottom-sheet 編輯、loading/error/reauth。
  AppBar actions 改為 `PopupMenuButton`(⋮):「今日照護」→ `/care-today`、「照護管理」→
  `/care-items`(窄螢幕 360dp 放不下標題 + 兩個 IconButton)。
- **資料新鮮度**:`/care-history` 編輯成功後 `DataRevision.bump()`(專案既有的
  「資料變了,健康模組該重載」機制),否則趨勢卡那個實例會停在過時資料。
  `CareHistoryController` 因此注入 `DataRevision`。
- **follow-ups**:heatmap 每格 `Tooltip`「日期 · 狀態」+ `Semantics(label:)`,並在
  **legend 每項帶天數計數**(新 domain 純函式 `careDayStateCounts`)——`Semantics` 只
  幫到螢幕閱讀器,明眼手機使用者仍需長按才讀得到狀態,計數讓量體成為可見文字;
  清單改 `ListView.builder`;空狀態在期間 < 90 天時加「看更長期間」(升到下一級並 reload);
  `CareHistorySummary.totalScheduled` 移除(未被任何畫面使用,語意與 rate 分母不同);
  `careHistoryRangeFor` → `dayRangeEndingOn`、`_parseDate` → `parseDayString` 搬進
  `lib/shared/date/day_format.dart`,`care_today_screen.dart` 的同名私有拷貝一併改用。
- **spec**:`care-history-ui` 的 list/chart requirement 由「純清單頁」requirement 取代
  (ADDED + REMOVED);heatmap 相關 scenario 移到新 capability `care-adherence-trend`,
  並補上實作已有、規格漏寫的第 5 態 `upcoming`(due==0,讓**今天**的格子不會每天早上就先變紅)。

## Impact

- Affected specs: `care-history-ui`(ADDED 新 requirement + REMOVED 舊 requirement)、
  `care-adherence-trend`(ADDED)
- Affected code: `care_history_screen.dart`、新增 `care_adherence_card.dart`、
  `care_history_controller.dart`、`domain/care_history.dart`、`health_scaffold.dart`、
  `lib/shared/date/day_format.dart`、`care_today_screen.dart`、`lib/app.dart`、`lib/main.dart`
- Affected tests(DI 波及,必須一併更新否則大量無關測試編譯失敗):
  `test/app_test.dart` 的 `pumpApp` helper、
  `test/contexts/health/presentation/health_scaffold_test.dart` 的 scaffold builder
- **不動**:後端與 `/api/care/range` 契約、`TrendController`/`TrendCard`、
  `care_items_screen`/`care_today_screen` 的既有「紀錄」IconButton 入口(仍只有 2 份拷貝,
  未過抽象門檻——見 design.md「不做」)。
