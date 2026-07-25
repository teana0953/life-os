## Why

照護 history 的後端已 merge(`life-os-backend#52`:`GET /api/care/range` per-slot 紀錄 +
`PUT /api/care/log` 可編輯、連動庫存)。前端需要對應的「照護紀錄」頁,**對齊使用者自己的
CareFlow app**(`../care_flow/lib/features/history/history_page.dart`):一頁、AppBar 用
SegmentedButton 切「清單 ↔ 圖表」,清單可**編輯**過去紀錄,圖表是**從紀錄算出來的 heatmap**。

## What Changes

- **domain**(`lib/contexts/notifications/domain/care_history.dart`)——**重用**既有
  `CareTodaySlot`/`CareTodayStatus`(後端 range 的 slot 用 `careTodaySlotToJson`,與 care-today
  同形狀,不重定義):
  - `CareHistoryDay{date, slots}`;
  - 純衍生(對齊 CareFlow 的 `calcMedicationAdherence`):`careDayState(day)` ∈
    full/partial/missed/noSchedule(noSchedule slots 空;full done==slots;partial 0<done<slots;
    missed done==0;**done 只算 `CareTodayStatus.done`**);
    `careHistorySummary(days)` → `{adherenceRate=Σdone/Σslots(空→null), daysWithDose, missedCount,
    totalScheduled}`。
  - port `CareHistoryRepository`:`getRange(idToken, from, to)` + `editSlot(idToken, {...,status})`
    (PUT 覆寫,與既有 POST `logSlot` 語意不同,故另立)。
- **application**:`get_care_history.dart`、`edit_care_slot.dart` 薄 use case。
- **infrastructure** `HttpCareHistoryRepository`(mirror `http_care_today_repository.dart`):
  `GET /api/care/range?from=&to=` 解析 `{from,to,days:[{date,items:[...]}]}`;`PUT /api/care/log`
  送 snake body;401→`CareReauthRequired`、非2xx→`CareRequestFailed`。
- **presentation**:
  - `CareHistoryController`:loading/loaded/error/reauth;`load(idToken,from,to)`;
    `edit(...)` → PUT 後**安靜重載**(比照 `CareTodayController` 的 marking 機制:`editing` flag、
    狀態不掉回 loading、失敗保留清單 + typed `editError`)。
  - `CareHistoryScreen`(route `/care-history`):AppBar 標題 + **清單/圖表 SegmentedButton**;
    7/30/90 期間切換(比照 `TrendCard`,今天回推,切換 reload);
    **清單**=逐日卡(日期標頭,今天用既有 `dietDayToday`;新到舊)+ 每筆 slot tile(狀態 icon/色 +
    標題 + `HH:mm · 狀態`),點 tile → **bottom sheet**(專案慣例)選「完成/略過」→ `edit`;
    **圖表**=headline(達成率/有服藥天數/漏服)+ `GridView.builder` heatmap(每格 `careDayState`
    上色 + tooltip 日期)+ legend;空/loading/error/reauth 狀態。
- **入口 + DI**:照護管理(`/care-items`)與今日照護(`/care-today`)的 AppBar 各加一個「紀錄」
  icon → `context.push('/care-history')`;`app.dart` 加 route、`main.dart` 組 DI。
- 新增 i18n(en + zh-Hant + zh):頁標題、清單/圖表、達成率/有服藥天數/漏服、legend、狀態字、
  編輯 sheet 標題、空狀態。

**不動**:今日照護 checklist 既有互動、總覽卡、後端;不做項目篩選(CareFlow 有,此版全部)。
Gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`。

## Capabilities

### Added Capabilities

- `care-history-ui`: 照護紀錄頁——一頁切換「清單 / 圖表」:清單逐日列出每筆照護 slot 及其狀態
  並可就地編輯(完成/略過,經 `PUT /api/care/log`);圖表以每日 heatmap(完成/部分/未完成/
  無排程)加達成率 headline 呈現,7/30/90 期間可切換。對齊 CareFlow 的 history 頁。
