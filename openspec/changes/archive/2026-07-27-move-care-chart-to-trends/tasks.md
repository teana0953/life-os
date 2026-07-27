## 1. shared 日期 helper(follow-up 8)

- [x] 1.1 (red) **新建** `test/shared/day_format_test.dart`:`dayRangeEndingOn(spanDays, now)`
      回 `({String from, String to})`,`to` = now 當日、`from` = today-(spanDays-1)
      (7/30/90;跨月、跨年;UTC 錨定所以 DST 不位移);`parseDayString('2026-07-27')`
      → 對應 `DateTime`(本地,只有日期分量)。
- [x] 1.2 (green) 在 `lib/shared/date/day_format.dart` 實作兩個函式(緊鄰既有
      `daysBetween`/`dayString`,共用同一套 UTC 錨定說明)。
- [x] 1.3 (refactor) 刪掉 `care_history_screen.dart` 的 `careHistoryRangeFor` 與
      `_parseDate`、`care_today_screen.dart` 的私有 `_parseDate`,全部改用 shared 版本;
      既有的 `careHistoryRangeFor` 測試在
      `test/contexts/notifications/presentation/care_history_screen_test.dart`,一併遷到
      新的 day_format 測試檔。**不動** `TrendController`(無關重構,見 design.md「不做」)。

## 2. domain(follow-up 6 + 無障礙計數)

- [x] 2.1 (red) `test/contexts/notifications/domain/care_history_test.dart`:移除
      `totalScheduled` 斷言;新增 `careDayStateCounts(days)` → 每個 `CareDayState` 的**天數**
      (五態齊備、空 days、只有 noSchedule 的情形);確認 `adherenceRate`(分母 = due slots =
      status != pending)、`daysWithDose`、`missedCount` 與 `careDayState` 五態行為不變。
- [x] 2.2 (green) `CareHistorySummary` 刪 `totalScheduled` 欄位與 `careHistorySummary` 裡的
      `slotsSum`(並更新類別 doc);新增純函式 `careDayStateCounts`。

## 3. controller 自持期間 + 編輯後 bump(design §A、§D)

- [x] 3.1 (red) `test/contexts/notifications/presentation/care_history_controller_test.dart`:
      `load(idToken)` 用自持 `spanDays` + 注入 clock 算出正確 from/to;
      `setSpan(idToken, 30)` 改 span 並以新 range 重載,**且重載期間保留既有 days**
      (不閃白);`edit` 成功 → 注入的 `DataRevision` 被 bump 一次,`editError` 或 401 →
      **不** bump;既有的 load 三態 / 安靜重載 / `editError` vs `refreshError` 行為不變。
- [x] 3.2 (green) `CareHistoryController`:加 `int spanDays`(建構子,預設值由呼叫端給)、
      注入式 `clock`、注入 `DataRevision`;`load(String idToken)` 內部用
      `dayRangeEndingOn` 算 range;新增 `setSpan`;移除對外的 `from`/`to` 參數形式。
- [x] 3.3 (refactor) **同步所有呼叫端**,讓這一步結束時 analyze/test 全綠——3.2 一改
      建構子與 `load` 簽章,下列位置立刻編譯失敗(**窮舉**):
      `lib/main.dart` 的 `CareHistoryController(...)`(唯一的正式建構點;`dataRevision`
      已在同檔稍早建立、在 scope 內,補 `spanDays: 7`)、`care_history_screen.dart` 的
      `_reload`/`_setSpan`(仍傳 from/to)、`test/app_test.dart` 的組裝、
      `care_history_screen_test.dart` 的同名 helper。
      這一步只改呼叫端與 helper,不改畫面的 UI 結構(那是第 6 節)。

## 4. 圖表搬家:新增趨勢卡 + 紀錄頁移除圖表(卡片新增與畫面刪除必須同一步,否則中途必紅)

- [x] 4.1 (red) **新建** `test/contexts/notifications/presentation/care_adherence_card_test.dart`:
      loading→卡內 spinner;loaded→headline(達成率/有紀錄天數/漏服)+ heatmap 格數 =
      期間天數 + legend **五項且每項帶天數計數**;期間切 7/30/90 → 走 `setSpan` 且**保留
      舊內容 + 細進度條**(不閃白);error→卡內錯誤 + 重試按鈕可再 load;空(每天皆無排程)
      →卡內空狀態;**每格 `Semantics` label 與 `Tooltip` message 同時含日期與狀態文字**
      (follow-up 3);預設 30 天;**卡的 `initState` 不發載入**(僅 addListener)。
      **顏色斷言必須 pump app 真正的 `lightTheme`/`darkTheme`**(承 #83 教訓:pump
      Material 預設主題時 `surfaceContainer*` 有值,配色 fallback 的 bug 測不出來);
      同時更新 `care_history_screen_test.dart`:**不存在** `care-history-mode-toggle`、
      heatmap、legend、headline。
- [x] 4.2 (green) 新檔 `lib/contexts/notifications/presentation/care_adherence_card.dart`
      = **單一** `LedgeCard`(標題 + `SegmentedButton` + headline `Row` + heatmap + legend);
      搬移 `_dayStateColor`/`_upcomingAlpha`/`_Legend`/`_LegendDot`/`_HeadlineMetric` 連同註解,
      **拆掉** `_HeadlineRow` 的 `LedgeCard` 外層(降為純 `Row`)與 `_HistoryChart` 的
      `ListView` + `LedgeCard` 外層(`_TrendBody` 已是 ListView,卡內不得再放不 shrinkWrap
      的可捲動元件);**同一步**從 `care_history_screen.dart` 刪除 `CareHistoryMode`、
      AppBar 模式 `SegmentedButton` 與所有圖表 widget。

## 5. 接進 HealthScaffold + DI

- [x] 5.1 (red) `test/contexts/health/presentation/health_scaffold_test.dart`:趨勢分頁
      同時有 `TrendCard` 與照護達成卡,**且照護卡排在趨勢卡之後**;
      `careAdherenceController` 在 `_overviewControllers` → 用**有鑑別力的**情境:
      **首次 load 成功、之後由卡內動作(期間切換 `setSpan` 或重試按鈕)才回 401**,
      斷言 `health-sign-in-again-button` 出現。**不可**用「初次載入就 401」——那一輪
      `Future.wait` 裡其他已註冊的 controller 也會 notify → setState → 重新求值
      `_overviewNeedsReauth`,漏註冊時測試照樣會過(時序相依的假綠)。
      (比照既有「careTodayController is in _overviewControllers」那條的寫法:
      它同樣是載入成功後才由使用者動作觸發 401。)
- [x] 5.2 (green) `HealthScaffold` 收 `careAdherenceController`,`_TrendBody` 多渲染一張卡
      (排在 `TrendCard` 後),併入 `_load()` 的 `Future.wait`、`_overviewNeedsReauth`
      **與 `_overviewControllers`**;`lib/app.dart`/`lib/main.dart` 建立第二個
      `CareHistoryController` 實例(`spanDays: 30`,共用同一個 `HttpCareHistoryRepository`
      與同一個 `DataRevision`)並串下去。
- [x] 5.3 (refactor) 更新 DI 波及的測試 helper:`test/app_test.dart` 的 `pumpApp`
      參數列與組裝、`health_scaffold_test.dart` 的 scaffold builder。
      **`pumpApp` 需要一個新參數**:目前它內部自建 `dataRevision` 且不對外開放,而
      `careHistoryController` 雖是具名參數卻沒有任何呼叫端在傳 —— 因此
      「編輯後 bump → 卡片刷新」在 app 層根本驗不到。加 `DataRevision? dataRevision`
      參數(`?? DataRevision()`),讓呼叫端能**同時**注入自備 controller 與同一個
      revision;這是 care-adherence-trend spec「Correcting a record on the history
      screen refreshes the card」可驗的前提(見 design §D)。

## 6. 紀錄頁的其餘 follow-up(4、5、9)

- [x] 6.1 (red) `care_history_screen_test.dart`:AppBar ⋮ 開啟後兩個項目分別 push
      `/care-today` 與 `/care-items`(follow-up 9);空狀態在 7/30 天有「看更長期間」按鈕、
      點了升到下一級(走 `setSpan`)並 reload,**90 天時按鈕不存在**(follow-up 5);
      清單以 `ListView.builder` 建構(follow-up 4);逐日清單、bottom-sheet 編輯、
      期間切換、loading/error/reauth 行為不變。
- [x] 6.2 (green) `care_history_screen.dart`:AppBar actions 換 `PopupMenuButton`;
      `_HistoryList` 改 `ListView.builder`;`_EmptyState` 收 `onWiden`(null 時不顯示按鈕);
      畫面的 `_spanDays` state 刪除,改讀 `controller.spanDays`、切換走 `setSpan`。
      **保留** `initState` → `_load()`(見 design §A:此路由不在 scaffold 內,沒人替它載入)
      與畫面自己的 `clock` 參數(**用途縮到只剩「今日」表頭判定**,range 改由 controller
      的 clock 決定);測試 helper 必須**同時釘住這兩個 clock**,否則會出現
      「範圍是 A 日、今日表頭是 B 日」的不一致。

## 7. i18n 收尾 + gate

**注意**:新 ARB key **不集中在這一節**——每個 UI 步驟要用到的 key 必須在**那一步之內**
先加(`app_en.arb` + description → `app_zh_Hant.arb` / `app_zh.arb` → `flutter gen-l10n`),
否則 `loc.<newKey>` 編譯失敗,第 4/6 節「該步結束時全綠」的保證就破功。分配:
**4.2** = 照護達成卡標題、heatmap 格的「日期 · 狀態」組合字串、legend 帶計數的字串;
**6.2** = ⋮ 選單兩個項目、空狀態「看更長期間」。

- [x] 7.1 移除因模式切換消失而不再使用的 key(`careHistoryListMode`/
      `careHistoryChartMode`),重跑 `flutter gen-l10n` 並**提交產物**
      (`lib/l10n/generated/` 是 checked-in 原始碼)。
- [x] 7.2 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。
