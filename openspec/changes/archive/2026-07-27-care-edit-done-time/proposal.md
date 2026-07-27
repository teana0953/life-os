## Why

issue life-os#90「[照護管理] 編輯的方式」四點 + 使用者後續補充一點:

1. 也能編輯**時間**(定案:**完成時間**,不是排程時間)
2. **只有今日的可以編輯**(定案:`/care-history` 保留編輯,但過去的變唯讀)
3. 入口改在**已完成**那裡
4. 已完成那裡的時間顯示要改成 **local time**
5. `/care-history` ⋮ 裡「圖表已移至健康 → 趨勢」的**註記項移除**(兩個導覽入口保留)

後端已就緒:**life-os-backend#53(已 merge)** 讓 `PUT /api/care/log` 收 `done_time`。

**第 4 點是明確的 bug**:`_doneRowSubtitle` 把後端的 `done_time` **原字串**塞進文案,
而後端送的是 `toISOString()`,所以「已完成」區現在顯示的是
「2026-07-27T04:58:00.000Z 完成」。

## What Changes

- **資料層**:`CareHistoryRepository.editSlot` port 與 `EditCareSlot` use case 加**可選**
  `DateTime? doneTime`;`HttpCareHistoryRepository` 在非 null 時放進 body 的 `done_time`,
  值為 **`doneTime.toUtc().toIso8601String()`**(帶 `Z`)——後端要求帶時區偏移,
  無偏移字串在 Workers(UTC runtime)會被靜默當成 UTC。不帶時 body **沒有該鍵**
  (不是 `null`);未帶的語意由後端負責(#53:已是 done 且有值 → 保留,否則當下)。
  **`status: skipped` 時一律不送**該鍵 —— 略過從未完成。
- **今日照護「已完成」區變成可編輯**:`CareTodayController` 注入 `EditCareSlot`,
  新增 `edit(...)` → PUT 後**安靜重載**。**注意 `marking` 是單一全域 `bool`,不是逐列**
  (`_markingSlotId` 只是顯示用)——被 gate 擋掉會靜默 return,對 bottom sheet 就是
  「選完時間按送出卻什麼都沒發生」。照抄 `/care-history` 的解法:開 sheet 前 gate、
  await 後再 gate 一次、`edit()` **回傳結果快照**(含「被丟棄」),呼叫端從回傳值判讀
  而非 await 後讀可變欄位,且丟棄時不得無聲。`_DoneGroup` 每列加 edit affordance → bottom sheet
  (狀態:完成/略過;**完成時間**:`showTimePicker`,預設為既有 `doneTime` 的本地時分,
  沒有就用 slot 的排程時段)。送出時把選定時分與 **slot 自己的 `localDate`**(不是「今天」)
  組成本地 `DateTime` 再轉 UTC —— 跨午夜時才不會寫錯日子。
- **只有今日可編輯**:`/care-history` 的列僅在 `slot.localDate == today` 時可點、
  才顯示 edit icon;過去的唯讀。用畫面既有的 `clock` 判定(#91 之後它的用途只剩
  「今日」表頭,這是第二個用途)。**後端不設限**(#53 明說那是 UI 決策,不是安全邊界)。
- **完成時間顯示改本地時分**:**採用 repo 既有的注入 seam**(`today_screen.dart` 的
  `toLocalTime` / `pickMealTime`,其註解明說注入是為了讓測試不依賴主機時區),
  不重新發明:`CareTodayScreen` 加 `toLocalTime`(預設 `(dt) => dt.toLocal()`)與
  `pickDoneTime`(預設包 `showTimePicker`)。**`.toLocal()` 是核心動作** —— 後端送的是
  `toISOString()`,`DateTime.parse` 回來 `isUtc: true`,少了它就顯示 UTC 時分。
  shared 只加**純解析**的 `parseInstant(String iso) → DateTime?`。
  **CI 的 ubuntu runner 是 UTC,`.toLocal()` 在那裡是 identity**,所以測試必須注入
  **非 identity** 的假轉換才抓得到這個 bug,不能靠「自己算期望值」。
- **⋮ 移除註記項**:刪掉 `PopupMenuItem(enabled: false)` + `PopupMenuDivider` 與
  ARB key `careHistoryTrendsMovedHint`(三檔)。順帶解掉一條既有 follow-up —— 那個
  disabled item 會被螢幕閱讀器念成「選單項目,按鈕,已停用」,鍵盤也跳過它。

## Impact

- Affected specs: `care-today-ui`(ADDED 兩個 requirement)、
  `care-history-ui`(MODIFIED **兩個** requirement:「Edit a past care record」收窄成
  只有今天可編輯,以及「A care history screen listing past care records」的 overflow-menu
  scenario 改成「只有目的地,沒有非互動註記」)
- Affected code: `domain/care_history.dart`(port)、`application/edit_care_slot.dart`、
  `infrastructure/http_care_history_repository.dart`、`presentation/care_today_controller.dart`、
  `presentation/care_today_screen.dart`、`presentation/care_history_screen.dart`、
  `lib/shared/date/day_format.dart`、**`lib/main.dart`**(DI:今日照護的 controller
  多一個 use case;注意 `careHistoryRepository` 目前建在 `careTodayController` **之後**,
  要把它上移才接得上)。**`lib/app.dart` 不需改** —— 它只是接收 controller,
  `CareTodayScreen` 的新參數都有預設值。
- Affected tests(**DI 波及範圍不小,漏一個整包編譯失敗**):`CareTodayController(` 有
  **6 檔 8 處**建構點(`app_pending_deep_link_test.dart` **×3**、`app_test.dart`、
  `health_scaffold_test.dart`、`care_today_controller_test.dart`、
  `care_today_screen_test.dart`、`care_today_summary_card_test.dart`,且多半還要各自補一個
  `CareHistoryRepository` fake);`editSlot` 的實作有 **1 prod + 6 fake**
  (Dart 不允許 override 少收具名參數)。清單見 design.md「測試策略」。
- **不動**:後端;排程時間(`timeOfDay`)的編輯(那是照護管理的排程設定);
  `/care-history` 編輯 sheet 不加時間選擇(見 design.md「不做」)。
