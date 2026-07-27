## 1. shared:純解析 helper

- [x] 1.1 (red) `test/shared/day_format_test.dart` 補 `parseInstant(String iso)`:
      合法 ISO(帶 `Z`)→ `DateTime`(`isUtc` 為 true);無效字串 / 空字串 → `null`。
      **只測解析,不測時區轉換** —— 轉換是畫面的注入點(design §C),不放 shared。
- [x] 1.2 (green) 在 `lib/shared/date/day_format.dart` 實作(緊鄰既有 `parseDayString`)。

## 2. 資料層:editSlot 支援 doneTime(**改簽章與更新所有實作必須同一步**)

- [x] 2.1 (red) `test/contexts/notifications/infrastructure/http_care_history_repository_test.dart`:
      `editSlot` 帶 `doneTime` → body 有 `done_time` 且為**帶 Z 的 UTC ISO**;
      不帶 → body **沒有** `done_time` 這個鍵(不是 `null`);
      `status: skipped` → **沒有**該鍵(即使呼叫端傳了 doneTime)。401 / 非 2xx 行為不變。
- [x] 2.2 (green) `CareHistoryRepository.editSlot` port + `EditCareSlot` use case +
      `HttpCareHistoryRepository` 加可選 `DateTime? doneTime`,**並在同一步更新全部
      實作**(Dart 不允許 override 少收具名參數,漏一個整包紅):
      `lib/contexts/notifications/infrastructure/http_care_history_repository.dart`、
      `test/app_test.dart`(`_FakeCareHistoryRepository` 與 `_MutableCareHistoryRepository`
      兩個)、`test/contexts/health/presentation/health_scaffold_test.dart`、
      `test/contexts/notifications/presentation/care_adherence_card_test.dart`、
      `.../care_history_controller_test.dart`、`.../care_history_screen_test.dart`。
      既有呼叫端 `CareHistoryController.edit` 不傳 doneTime,語意不變。

## 3. 今日照護:controller 的編輯能力(**加建構子參數與更新所有建構點必須同一步**)

- [x] 3.1 (red) `test/contexts/notifications/presentation/care_today_controller_test.dart`:
      `edit(...)` 成功→**安靜重載**(status 全程 loaded);失敗→保留 slots + typed error;
      401→reauth;**被 re-entrancy gate 丟棄時回傳值可辨識**(不是靜默 `void`)。
      `skipped` 時不傳 doneTime。
- [x] 3.2 (green) `CareTodayController` 注入 `EditCareSlot`,實作 `edit` 比照既有 `_mark`,
      **回傳結果快照 enum**(比照 `CareEditOutcome`,含代表「被 gate 丟棄」的值)。
      **同一步**更新全部 **6 檔 8 處**建構點:`test/app_pending_deep_link_test.dart`(**3 處**)、
      `test/app_test.dart`、`test/contexts/health/presentation/health_scaffold_test.dart`、
      `.../care_today_controller_test.dart`、`.../care_today_screen_test.dart`、
      `.../care_today_summary_card_test.dart`(這些檔多半只有 `CareTodayRepository` 的
      fake,還要各自補一個 `CareHistoryRepository` fake 才建得出 `EditCareSlot`)。
      正式 wiring 一併在這步接上:**只需改 `lib/main.dart`**(`lib/app.dart` 只是接收
      controller,`CareTodayScreen` 的新參數都有預設值)。**注意順序**:`main.dart` 目前
      在建 `careTodayController` **之後**才建 `careHistoryRepository`,要把 repository
      (或 `EditCareSlot(...)`)的建立**上移**才接得上。

## 4. 今日照護:顯示本地時分(第 4 點)

- [x] 4.1 (red) `test/contexts/notifications/presentation/care_today_screen_test.dart`:
      **注入一個非 identity 的 `toLocalTime`**(例如固定 +8 小時)並斷言 done 列副標顯示
      的是**轉換後**的時分 —— 這樣才抓得到「少寫 `.toLocal()`」。
      **不可**用「自己算期望值」的寫法:CI 的 ubuntu runner 是 UTC,`.toLocal()` 是
      identity,那種測試恆真(design §C 的警告)。
      `doneTime` 為 null 或無法解析 → 退回 `slot.timeOfDay`。
- [x] 4.2 (green) `CareTodayScreen` 加 `toLocalTime` 參數(預設 `(dt) => dt.toLocal()`,
      比照 `today_screen.dart` 的 `_defaultToLocal`);`_doneRowSubtitle` 的 done 分支改成
      **`loc.careTodayDoneAtLabel(DateFormat('HH:mm').format(toLocalTime(parsed)))`**
      —— **保留**既有的「Done at {time}」文案包裝,只換裡面的時間值(spec 只要求
      顯示成本地時分,沒有要改文案);`parsed` 為 null → fallback 到 `slot.timeOfDay` 不變。
      **同一步**修既有測試:`care_today_screen_test.dart` 的 `_FakeCareTodayRepository.logSlot`
      目前寫 `doneTime: '08:05'`(**非 ISO**,`tryParse` 回 null → 走 fallback),
      要改成真正的 UTC ISO;對應的 `careTodayDoneAtLabel('08:05')` 斷言改成注入的
      `toLocalTime` 轉換後的期望值。否則這一步必紅。

## 5. 今日照護:已完成列可編輯(第 1、3 點)

- [x] 5.1 (red) `care_today_screen_test.dart`:已完成列(**含 `missed`**)有 edit
      affordance → 點開 bottom sheet(標頭含項目/日期/時段/現狀)→ 可選完成/略過 + 選時間;
      **注入 `pickDoneTime`** 繞過真正的 time picker(比照
      `test/contexts/health/presentation/today_screen_test.dart` 的 `pickMealTime` 注入);
      送出的 `doneTime` 由 **slot 自己的 `localDate`** + 選定時分組成(**不是**「今天」);
      **一天兩次排程**時複合 key 能指定正確的列;編輯中該列顯示 in-flight;
      失敗顯示 SnackBar 且清單保留;**被 gate 丟棄時也有提示**(不無聲)。
- [x] 5.2 (green) **只有 `_DoneGroup`** 的列改用複合 key
      `care-today-row-${careScheduleId}-${localDate}-${timeOfDay}`(現行只有
      careScheduleId,一天兩次排程會撞);**`_SlotRow`(overdue/later)維持原 key 不動**
      —— 那兩區同樣有重複 key 的既有問題,但不在本次範圍。
      **同一步**修既有斷言:`care_today_screen_test.dart` 用
      `Key('care-today-row-sch-done')` / `Key('care-today-row-sch-1')` 指向已完成區的地方
      都要改成複合 key。加 trailing edit icon + `onTap` → sheet;
      `CareTodayScreen` 加 `pickDoneTime` 參數(預設包 `showTimePicker`,初始值取既有
      `doneTime` 的本地時分、無則 slot 的 `timeOfDay`,選定後與
      `parseDayString(slot.localDate)` 組成本地 `DateTime` 再 `.toUtc()`);
      **開 sheet 前與 await 之後都 gate** `controller.marking`,結果一律**從 `edit` 的
      回傳值**判讀(design §B)。sheet 的控制項與 Key 照 design §B 的表格
      (標頭 / 狀態兩顆 / 時間列(選「略過」時停用)/ 送出鍵)。新 ARB key
      (sheet 標題、時間列標籤、送出鍵)在**這一步**先加齊(`app_en.arb` + description →
      `app_zh_Hant.arb` / `app_zh.arb` → `flutter gen-l10n`)。

## 6. 紀錄頁:只有今日可編輯 + ⋮ 移除註記(第 2、5 點)

- [x] 6.1 (red) `test/contexts/notifications/presentation/care_history_screen_test.dart`:
      **今天**的列仍可點開編輯 sheet;**過去**的列**沒有 edit icon** 且點了**不開** sheet;
      ⋮ 開啟後**不存在**註記項,兩個導覽入口仍在。
- [x] 6.2 (green) `_SlotTile` 收 `editable`(由 `slot.localDate == dayString(widget.clock())`
      決定);`PopupMenuButton` 刪掉註記項與 `PopupMenuDivider`;三個 ARB 檔刪
      `careHistoryTrendsMovedHint`,重跑 `flutter gen-l10n`。

## 7. gate

- [x] 7.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠;
      `lib/l10n/generated/` 產物已提交。
