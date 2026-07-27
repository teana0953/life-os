# 照護圖表移入趨勢分頁 + care-history follow-ups — 設計

日期:2026-07-27
兩軸判定:`flow_profile = full`(行為變更:畫面拆分、導覽入口、資料欄位移除)、
`needs_uiux = true`(視覺層級、無障礙、空狀態動作、跨畫面導覽)。
(v2:依 proposal-review 修正載入責任歸屬、搬移層級、資料新鮮度、無障礙可見替代。)

## 背景

`add-care-history-ui`(life-os#83)把「照護紀錄」做成**一頁兩模式**(AppBar
`SegmentedButton` 切清單↔圖表),對齊 CareFlow 的 history_page。上線後使用者的新
指示:**「照護管理的圖表移到趨勢裡」**——heatmap 屬於「回顧」語境,健康模組已經有
專屬的**趨勢**分頁,圖表不該藏在紀錄頁的第二個模式裡。

同時清掉 `.devloop/archive/add-care-history-ui/followup-add-care-history-ui.md`
的 follow-up。

## 目標

1. 照護 heatmap **移到**健康模組「趨勢」分頁,成為 `TrendCard` 之後的第二張卡。
2. `/care-history` 收斂成**純紀錄清單 + 編輯**頁(不再有模式切換)。
3. 一併修 follow-up。

**明示假設**:使用者說「移到」= **移走**,不是兩處都放。紀錄頁的圖表模式整段移除,
heatmap 只存在於趨勢分頁一處(避免同一視覺化兩份實作漂移)。

## 設計

### A. `CareHistoryController` 改為自持期間(對齊 `TrendController`)

**這是本 change 的關鍵前置**,不是順手重構:趨勢卡要能被 `HealthScaffold._load()`
以 `load(token)` 驅動(比照其他卡),但目前 `load(idToken, from, to)` 需要呼叫端算
range,而 span 又住在畫面的 `State` 裡 → scaffold 算不出來,只能硬寫一個 span,
使用者切到 90 天後任何 `DataRevision` 觸發的重載都會把資料洗回硬寫值、選擇器卻仍顯示 90。

改成**完全比照** `TrendController`(`lib/contexts/vitals/presentation/trend_controller.dart`):

- controller 持有 `int spanDays`(建構子給預設)與注入式 `DateTime Function() clock`。
- 對外只有 `load(String idToken)`(用自己的 `spanDays` 算 range)與
  `setSpan(String idToken, int spanDays)`(改 span 並重載)。移除呼叫端傳 `from`/`to` 的形式。
- range 算術透過 §E-8 搬進 shared 的 `dayRangeEndingOn`。
- `CareHistoryScreen` 的 `_spanDays` state **刪除**,改讀 `controller.spanDays`;卡片同理。
- **誰驅動第一次載入**(兩者不同,別搞混):
  - **卡片不在 `initState` 發載入**,只 `addListener`(比照 `TrendCard`)——它活在
    `HealthScaffold` 裡,由 `_load()` 的 `Future.wait` 驅動;若卡片自己也載,掛載時會有
    兩個並發 load(該 controller 的 `load` 沒有 re-entrancy guard)。
  - **畫面保留 `initState` → `_load()`**(取 token 後 `controller.load(idToken)`)。
    `/care-history` 是 `lib/app.dart` 裡與 `/health` **平行的 top-level route**,不在
    `HealthScaffold` 內,scaffold 的 `_load()` 只驅動卡片那個實例;拿掉畫面的 initState
    載入,畫面會永遠停在 `status=loading` + `days=[]` 而一直轉圈。畫面用自己的獨立
    controller 實例,本來就沒有第二個載入者,不存在並發問題。
- **畫面仍保留自己的 `clock` 參數**,但用途縮到只剩「今日」表頭判定
  (`dayString(widget.clock())` → `_DayCard` 的 `isToday`);range 算術改由 controller 的
  clock 決定。**測試必須同時釘住這兩個 clock**,否則會出現「範圍是 A 日、今日表頭是 B 日」
  的不一致。

### B. 趨勢分頁新增「照護達成」卡

新檔 `lib/contexts/notifications/presentation/care_adherence_card.dart`。

- **位置**:`HealthScaffold` 的 `_TrendBody`,**排在 `TrendCard` 之後**(生理數值是主軸,
  照護是次要面向)。順序是刻意的設計決定,spec 有可驗 scenario。
- **結構**:**單一** `LedgeCard` 內含 標題 → 卡內 7/30/90 `SegmentedButton` → headline
  (達成率 / 有紀錄天數 / 漏服)→ heatmap → legend(每項帶天數計數,見「無障礙」)。
  **層級注意**:從紀錄頁搬過來時,`_HeadlineRow` 自己就是一個 `LedgeCard`、
  `_HistoryChart` 是 `ListView` + 另一個 `LedgeCard` —— 這兩層 wrapper 必須**拆掉**
  (否則卡中卡:重複邊框與 ledgeShadow),`_HeadlineRow` 降為純 `Row`;`_TrendBody` 本身
  已是 `ListView`,卡內不得再放不 `shrinkWrap` 的可捲動元件。
  真正原封搬移的只有 `_dayStateColor` / `_upcomingAlpha` / `_Legend` / `_LegendDot` /
  `_HeadlineMetric`(含它們的註解,尤其 upcoming 用 `secondary.withValues(alpha:)`
  而非未設 role 的理由)。
- **狀態管理**:Stateful + `addListener`(比照 `TrendCard` / `HealthCalendarCard`);
  期間切換走 `controller.setSpan`,**保留既有內容 + 細進度條**,不整卡閃白;
  錯誤→卡內錯誤 + 重試;空(每天皆無排程)→ 卡內空狀態(不提供「看更長期間」——
  卡本來就有期間選擇器)。
- **controller 實例**:`main.dart` 建**第二個** `CareHistoryController`
  (`careAdherenceController`,`spanDays: 30`),與 `/care-history` 頁的
  `careHistoryController`(同樣 `spanDays: 30`)**分開**,共用同一個(無狀態的)
  `HttpCareHistoryRepository`。同一個實例會讓兩處互搶 `days`/期間,切分頁就互相洗掉。
  兩者**預設期間相同**:卡片 header 的「查看紀錄」直接連到 `/care-history`,若紀錄頁
  預設只有 7 天,使用者從卡上看到的那個未完成日可能根本不在範圍內。之後各自切期間互不影響。
- **卡片 → 紀錄頁入口**:卡 header 放「查看紀錄」(`onOpenHistory` callback,由
  `HealthScaffold` 的 `onOpenCareHistory` 一路注入到 `lib/app.dart` 的
  `context.push('/care-history')`,比照既有的 `onOpenCareItems`)。看到「未完成 5」正是
  要去更正紀錄的時刻,健康模組內若沒有任何連結,最短路徑會變成 更多 → 照護管理 →
  AppBar → 再改期間。
- **401**:卡的 reauth 併進 `HealthScaffold._overviewNeedsReauth`(比照
  `careTodayController`),**且必須同時加進 `_overviewControllers`**。機制:
  `_overviewControllers` 在 `initState`/`dispose` 求值,用來註冊/移除 `_onChanged`
  listener;`_overviewNeedsReauth` 才是在 `build()` 求值的。加進去 → controller notify →
  `_onChanged` → `setState` → 重建 scaffold → 重新求值 `_overviewNeedsReauth`;
  漏加的話卡片自己的 listener 只 `setState` 卡片,401 出口要等別的 controller
  恰好 notify 才會出現。
- **載入時機**:併入 `HealthScaffold._load()` 的 `Future.wait`(與其他卡一致)。

### C. `/care-history` 收斂為純清單頁

`care_history_screen.dart`:

- **移除**:`CareHistoryMode` enum、AppBar 的模式 `SegmentedButton`、
  `_HistoryChart` / `_HeadlineRow` / `_HeadlineMetric` / `_Legend` / `_LegendDot` /
  `_dayStateColor` / `_upcomingAlpha`(搬去 B,見上方層級注意)。
- **保留**:body 頂的 7/30/90 期間 `SegmentedButton`(現在是畫面唯一的分段控制項,
  follow-up「兩個 SegmentedButton 視覺權重相同」因此自然消解,不需另外降階)、
  逐日清單、bottom-sheet 編輯、loading/error/reauth。
- **AppBar actions** 改為 `PopupMenuButton`(⋮):「今日照護」→ `/care-today`、
  「照護管理」→ `/care-items`(follow-up 9)。用 popup 而非兩個 `IconButton`:
  窄螢幕(360dp)放不下標題 + 兩個 icon。

### D. 兩實例之間的資料新鮮度

在 `/care-history` 編輯一筆紀錄只會更新 `careHistoryController` 的 `days`,趨勢卡的
另一個實例不會知道。**決定:編輯成功後 `DataRevision.bump()`** ——
`DataRevision`(`lib/shared/data_revision.dart`)正是專案既有的「資料變了,健康模組
該重載」機制(目前只有 chaodays import 會 bump),`HealthScaffold` 已監聽它並有
`_scheduleLoad` 的 in-flight/pending 合流保護。

**無迴圈**:`_load()` 只呼叫各 controller 的 `load`,`load` 不 bump;卡片那個實例不做
編輯。兩個實例共用同一個 `DataRevision` 沒有 re-entrant 風險。

**成本(明確取捨,不是「低頻」)**:`/care-history` 是從 `/care-items` / `/care-today`
push 上去的,`HealthScaffold` 仍在 stack 下方且 listener 有效 → **每一筆**成功編輯都會
觸發 `_load()` 裡 12 個 controller 的整批重抓;連續更正 N 筆就是 N 次。接受這個成本,
換取「趨勢卡不會停在過時資料」——重抓發生在背景的 scaffold 上,不阻塞使用者當下的
紀錄頁操作,且 `_scheduleLoad` 會把連續的 bump 合流成最多一次待處理重載。

`CareHistoryController` 因此注入 `DataRevision`;**`main.dart`、`lib/app.dart` 與
`test/app_test.dart` 的 `pumpApp` 都必須讓兩個 controller 實例注入到與 scaffold
同一個 `DataRevision` 實例**,否則 bump 連線在那些測試裡等於沒接上。

### E. Follow-up 逐條處置

| # | 項目 | 處置 |
|---|---|---|
| 1 | spec 未描述第 5 態 `upcoming` | 改寫 spec:模式移除、圖表在趨勢分頁、heatmap 五態(含 `upcoming`) |
| 2 | 兩個 SegmentedButton 權重相同 | **由 B/C 消解**(圖表移走,紀錄頁只剩一個) |
| 3 | heatmap 只有 tooltip、色彩是唯一訊號 | cell 的 `Tooltip` 訊息改「日期 · 狀態」+ 外包 `Semantics(label:)`;**並在 legend 每項帶天數計數**(見「無障礙」) |
| 4 | 清單 eager `ListView(children:)` | 改 `ListView.builder` |
| 5 | 空狀態是死路 | 空狀態且 `spanDays < 90` 時加「看更長期間」按鈕 → 升到下一級(7→30→90) |
| 6 | `totalScheduled` 未被使用 | 從 `CareHistorySummary` **移除**(YAGNI;與 rate 分母語意不同,留著只會誤用) |
| 7 | AppBar 入口重複 7 行 | **不做**——見「不做」 |
| 8 | 日期 helper 重複 | `careHistoryRangeFor` → `dayRangeEndingOn(spanDays, now)`、`_parseDate` → `parseDayString`,搬進 `lib/shared/date/day_format.dart`;`care_today_screen.dart` 的同名私有拷貝一併改用 |
| 9 | `/care-history` 是葉節點 | 見 C 的 `PopupMenuButton` |

## UI/UX 設計

- **資訊架構**:照護四種任務各有其位——**做**(今日照護 `/care-today`)、
  **管**(照護管理 `/care-items`)、**看紀錄/更正**(照護紀錄 `/care-history`)、
  **看趨勢**(健康 → 趨勢分頁)。圖表移入趨勢後,「回顧」統一在趨勢分頁,
  紀錄頁專責逐筆查看與更正,每個畫面一個明確任務。
- **視覺層級**(趨勢分頁):`TrendCard`(生理數值折線)在上、照護達成卡在下;
  兩卡同為 `LedgeCard`,各自卡內帶期間選擇器,層級一致、互不從屬。
- **無障礙**:heatmap 每格同時具備顏色、`Tooltip`(日期 · 狀態)與 `Semantics` label。
  但 `Semantics` 只解決螢幕閱讀器——follow-up 原本的抱怨是「行動裝置需長按且不可發現」,
  明眼的手機使用者仍讀不到單格狀態。因此**legend 每一項帶該狀態的天數計數**
  (例:完成 12 · 部分 3 · 未完成 5 · 待辦 1 · 無排程 9),讓每個狀態的量體是**可見文字**,
  不必長按。單格的精確日期仍只在 tooltip/Semantics —— 這是已知取捨(不做點格跳日,
  同 CareFlow)。需要新增 domain 純函式 `careDayStateCounts(days)`。
- **空狀態不是死路**:紀錄頁空狀態最可能的成因是「預設 7 天窗,但排程更早開始」,
  因此直接給「看更長期間」的行動。
- **導覽可逆**:`/care-history` 從葉節點變成可回到照護脈絡的節點(⋮ 選單)。

## 不做(YAGNI / 越界)

- **不抽** AppBar「紀錄」入口的共用 widget:`care_today_screen` 與
  `care_items_screen` 仍只有 **2 份** 7 行拷貝;紀錄頁這端用的是 `PopupMenuButton`,
  形狀不同,不構成第三份。CLAUDE.md「不為單次使用做抽象」——門檻未過。
  (follow-up 原文也是「第三個照護畫面出現時應抽」。)
- **不動** `TrendController` / `TrendCard` / vitals 的期間算術第三份拷貝
  (搬 helper 只讓 care 兩處改用;動 trend 屬無關重構)。
- **不動**後端、不動 `/api/care/range` 契約。
- heatmap 不做「點格子跳到該日清單」(CareFlow 也只有 tooltip)。

## 驗收標準

1. 健康模組 → 趨勢分頁顯示兩張卡,**照護達成卡排在生理數值趨勢卡之後**。
2. 照護達成卡可切 7/30/90 並 reload,**保留內容 + 細進度條**,不整卡閃白;
   預設 30 天;401 → 與趨勢分頁其他卡同一個重新登入出口(且卡的 notify 能重建 scaffold)。
3. `/care-history` **不再有**清單/圖表模式切換,只有期間選擇 + 逐日清單 + 編輯;預設 7 天。
4. `/care-history` 的 AppBar ⋮ 可前往今日照護與照護管理。
5. heatmap 每格的 tooltip 與 Semantics label 同時帶日期與**狀態文字**;
   legend 每項帶**天數計數**(不需長按即可讀到各狀態量體)。
6. 紀錄頁清單以 `ListView.builder` 建構。
7. 紀錄頁空狀態在期間 < 90 天時提供「看更長期間」,點擊後期間升級並重新載入;90 天時不顯示。
8. `CareHistorySummary` 不再有 `totalScheduled`。
9. `dayRangeEndingOn` / `parseDayString` 位於 `lib/shared/date/day_format.dart`,
   `care_history_screen` 與 `care_today_screen` 皆改用,無重複私有拷貝。
10. `/care-history` 編輯成功後 `DataRevision` 被 bump,趨勢卡在健康模組重載後反映新狀態。

## 測試策略

- shared:`dayRangeEndingOn`(7/30/90 邊界、跨月跨年、UTC 錨定)、`parseDayString`
  (**新建** `test/shared/day_format_test.dart`)。既有的 `careHistoryRangeFor` 測試在
  `test/contexts/notifications/presentation/care_history_screen_test.dart` 內,一併遷移。
- domain:`careHistorySummary` 移除欄位後既有測試更新;`careDayState` 五態不變;
  新增 `careDayStateCounts` 測試。
- controller:`load(idToken)` 用自持 span 算 range;`setSpan` 改 span 並重載且不閃白;
  `edit` 成功 → bump `DataRevision`,失敗 → 不 bump。
- `CareAdherenceCard` widget test:三態 + 期間切換不閃白 + heatmap 格數 = 期間天數 +
  每格 Semantics/tooltip 含狀態文字 + legend 五項帶計數 + 空狀態 + 預設 30 天。
- `CareHistoryScreen` widget test:**不存在**模式 toggle 與 heatmap;⋮ 兩個入口 push
  正確路由;空狀態「看更長期間」升級期間並 reload(90 天時按鈕不存在);清單仍可編輯。
- `HealthScaffold` widget test:趨勢分頁兩張卡且照護卡在後;照護卡 401 走 reauth 出口;
  `careAdherenceController` 在 `_overviewControllers`(比照既有的 careTodayController 那條)。
- **DI 波及**:`test/app_test.dart` 的 `pumpApp` helper 與
  `test/contexts/health/presentation/health_scaffold_test.dart` 的 scaffold builder
  都要補新的 required controller,否則大量無關測試編譯失敗。
- 顏色相關 widget test 必須 pump **app 真正的** `lightTheme`/`darkTheme`
  (承 #83 的教訓:pump Material 預設主題會讓 `surfaceContainer*` fallback 的 bug 測不出來)。
