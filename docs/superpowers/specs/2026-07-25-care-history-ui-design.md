# 照護 history 前端 — 設計文件

日期:2026-07-25
狀態:已批准方向(對齊使用者自己的 CareFlow app 的 history 頁)

## 目標

新增「照護紀錄」頁,對齊 CareFlow(`../care_flow/lib/features/history/history_page.dart`):
**一頁、AppBar 用 SegmentedButton 切「清單 ↔ 圖表」**,清單可**編輯**過去紀錄,圖表是
**從紀錄算出來的 heatmap**。消費已 merge 的後端 `#52`:
`GET /api/care/range?from=&to=` + `PUT /api/care/log`。

## 參考:CareFlow

- **Toggle**:AppBar actions 放 `SegmentedButton<bool>`(清單/圖表),清單模式才顯示篩選列。
- **清單**:逐日 `HistoryDayCard`(日期標頭,today→「今天」)+ 底下每筆 tile
  (`_MedLogTile`:狀態 icon/顏色 + 標題 + `時間 · ×劑量 → 狀態`)。
- **圖表**:`MedicationHeatmapCard` = headline(達成率/有服藥天數/漏服)+ `GridView` 每天一格
  (full/partial/missed/noSchedule)+ legend。計算 `calcMedicationAdherence(logs, start, end)`。

## LifeOS 設計

### 資料層(重用既有 care 契約)

後端 range 的 slot 用 `careTodaySlotToJson`,**與 care-today 同形狀** → 直接重用既有
`CareTodaySlot` / `CareTodayStatus` / `careTodayStatusFromWire`,不重定義。

- **domain**(`lib/contexts/notifications/domain/care_history.dart`):
  - `CareHistoryDay{ date, slots }`(slots = `List<CareTodaySlot>`)。
  - 純衍生(供圖表與 headline,對齊 CareFlow 的 calc):
    - `careDayState(day)` ∈ full/partial/missed/noSchedule:`noSchedule` slots 空;
      `full` done數==slots數;`partial` 0<done<slots;`missed` done==0 且 slots 非空。
      (**done 只算 `CareTodayStatus.done`**;skipped/missed/pending/overdue 皆非 done,同 CareFlow
      taken 語意。)
    - `careHistorySummary(days)` → `{ adherenceRate = Σdone/Σslots(null when 0), daysWithDose =
      有至少一筆 done 的天數, missedCount = Σ status==missed, totalScheduled = Σslots }`。
  - port `CareHistoryRepository.getRange(idToken, from, to)`;編輯沿用既有 `CareTodayRepository`?
    → **不**,編輯是 `PUT`(覆寫),與既有 `logSlot`(POST)語意不同 → port 加
    `editSlot(idToken, {careScheduleId, localDate, timeOfDay, status})`。
- **application**:`get_care_history.dart`、`edit_care_slot.dart` 薄 use case。
- **infrastructure** `HttpCareHistoryRepository`(mirror `http_care_today_repository.dart`):
  `GET /api/care/range?from=&to=` 解析 `{from,to,days:[{date,items:[...]}]}`;
  `PUT /api/care/log` snake body;401→`CareReauthRequired`、非2xx→`CareRequestFailed`。

### 呈現

- **`CareHistoryController`**:loading/loaded/error/reauth;`load(idToken, from, to)`;
  `edit(idToken, slot, status)` → PUT 後**安靜重載**(比照 `CareTodayController` 的 marking 機制:
  `editing` flag,狀態不掉回 loading;失敗保留清單 + typed `editError`)。
- **`CareHistoryScreen`**(route `/care-history`):
  - AppBar:標題「照護紀錄」+ actions `SegmentedButton`(清單/圖表)。
  - 期間:7/30/90 `SegmentedButton`(比照 `TrendCard`),今天回推 from/to,切換 reload。
  - **清單模式**:逐日卡(日期標頭,今天→`dietDayToday` 既有字串;倒序,新到舊)+ 每筆 slot tile
    (狀態 icon/色 + 標題 + `HH:mm · 狀態`)。tile 可點 → 編輯(見下)。
  - **圖表模式**:headline(達成率/有服藥天數/漏服)+ heatmap `GridView.builder`(每格
    `careDayState` 上色 + tooltip 日期)+ legend(完成/部分/未完成)。
  - 空/loading/error/reauth 狀態(沿用 `AsyncStateScaffold` 慣例)。
- **編輯互動**:點清單 tile → **bottom sheet**(專案慣例:行動裝置對話框用 bottom sheet)提供
  「完成 / 略過」兩個選項 → 呼叫 `edit`。**任何列出的 slot 都可設為 done 或 skipped**(含補登
  `missed` 的那筆);`missed`/`pending`/`overdue` 是系統推導的來源狀態,**不可手動設定**
  (後端只收 done|skipped)。
- **入口**:照護管理(`/care-items`)AppBar 加「紀錄」icon → `/care-history`;
  今日照護 checklist(`/care-today`)AppBar 也加同一入口(兩處都是照護脈絡)。

## 不做(YAGNI)

- 不做項目篩選(CareFlow 有 dropdown 篩選;此版先全部)。
- 不動今日照護 checklist 的既有互動、總覽卡、後端。
- heatmap 不做點格子跳到該日(CareFlow 也只有 tooltip)。

## 驗收標準

1. 從照護管理/今日照護可進入「照護紀錄」頁。
2. 清單模式:逐日分組、每筆顯示時間/標題/狀態;圖表模式:headline + heatmap + legend。
3. AppBar toggle 可切換兩模式;7/30/90 切換會 reload 對應期間(**from = today-(span-1)、
   to = today,含今天**,用 `dayString` + UTC 算術),且**保留既有內容 + 細進度條**,不整頁閃白。
4. 點清單 tile → bottom sheet 選完成/略過 → 送出 PUT 並更新該筆(不整頁 loading);失敗顯示提示
   且保留清單(**含 PUT 成功但後續重載失敗的情況**)。
5. 空(**每天 slots 皆空**——後端 days 是密集陣列,`days.isEmpty` 永不成立)→ 空狀態;
   401 → reauth 出口;初次載入 → loading。**清單模式跳過無 slot 的日子**,heatmap 仍畫該格。
6. 達成率 = Σdone/Σslots(**不需 clamp**:done ⊆ slots);heatmap 格子狀態依
   full/partial/missed/noSchedule,格數 = span 天數。

## 測試策略

- domain 純函式:`careDayState` 四態邊界、`careHistorySummary`(rate/daysWithDose/missedCount/空)。
- `HttpCareHistoryRepository`:mock client 測 GET URL/解析/PUT body/401/非2xx。
- `CareHistoryController`:load 三態;edit 成功→安靜重載、失敗→保留清單+editError。
- `CareHistoryScreen` widget test:清單/圖表 toggle、逐日分組、heatmap 格數、7/30/90 reload、
  tile→bottom sheet→edit 呼叫、空/reauth。
