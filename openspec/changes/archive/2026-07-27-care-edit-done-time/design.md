# 照護編輯方式改版(issue life-os#90)— 設計

日期:2026-07-27
兩軸判定:`flow_profile = full`(行為變更:編輯入口搬家、可編輯範圍收窄、新增可編輯欄位)、
`needs_uiux = true`(編輯互動、時間顯示、可編輯性的視覺表達)。
(v2:依 proposal-review 改採 repo 既有的時區注入 seam、寫明 `.toLocal()`、
修正對 `marking` gate 的誤述。)

## 背景

issue #90 四點 + 使用者後續補充一點:

1. 也能編輯**時間**(定案:**完成時間**,不是排程時間)
2. **只有今日的可以編輯**(定案:`/care-history` 保留編輯,但過去的變唯讀)
3. 入口改在**已完成**那裡
4. 已完成那裡的時間顯示要改成 **local time**
5. `/care-history` ⋮ 裡「圖表已移至健康 → 趨勢」的**註記項移除**(兩個導覽入口保留)

後端已就緒:**life-os-backend#53(已 merge)**,`PUT /api/care/log` 收 `done_time`,
語意是「未指定 = 不要動這個欄位」。

## 現況(讀碼確認)

- 今日照護的「已完成」區(`_DoneGroup`)是**唯讀** `ListTile`,沒有編輯入口;副標的
  `_doneRowSubtitle` 把後端 `done_time` **原字串**塞進文案,而後端送的是 `toISOString()`
  → 畫面現在顯示「2026-07-27T04:58:00.000Z 完成」。這是第 4 點要修的。
- 編輯能力只在 `/care-history`,且**任何日期**都可編輯。
- `CareTodayController` 只有 `markDone`/`markSkipped`(POST,insert-if-absent)。

## 設計

### A. 資料層:`editSlot` 支援 `doneTime`

- `CareHistoryRepository.editSlot` port 加**可選** `DateTime? doneTime`;
  `HttpCareHistoryRepository` 在非 null 時放進 body 的 `done_time`,值為
  **`doneTime.toUtc().toIso8601String()`**(帶 `Z`)。後端要求帶時區偏移 ——
  無偏移字串在 Workers(UTC runtime)會被靜默當成 UTC。
- **不帶時 body 沒有該鍵**(不是 `null`);未帶的語意由後端負責。
- **`status: skipped` 時一律不送 `done_time`**(即使 UI 上還留著時間值)——
  略過從未完成,不該在略過的紀錄上寫完成時間。
- `EditCareSlot` use case 同步加參數(純 pass-through)。

### B. 今日照護的「已完成」區變成可編輯

**⚠️ `marking` 是單一全域 `bool`,不是逐列**(`care_today_controller.dart` 的
`if (marking) return;`)——`_markingSlotId`/`markingAction` 純粹是顯示用,無法表達
「哪一列可並行」。這對 inline 按鈕無妨(按鈕本來就 disabled),但對**編輯 bottom sheet**
就是致命的:使用者花時間選完時間、按送出,呼叫被靜默 gate 掉,**什麼都沒發生也沒有提示**。

`/care-history` 早就解過這題,**照抄它的三件事**:
1. **開 sheet 前** gate(`if (controller.marking) return;`)。
2. **sheet await 之後再 gate 一次** —— 快速雙擊能在任一個到達第一道 gate 前開兩個 sheet。
3. **`edit()` 回傳結果快照**(比照 `CareEditOutcome`,含 `skipped` 代表被 gate 丟棄),
   呼叫端**從回傳值**決定要顯示什麼,**不要** await 後去讀 controller 的可變欄位
   (那些欄位會被並發的 load / 第二次 edit 清掉,曾造成「失敗的 PUT 顯示已儲存」)。
   被丟棄時**不得無聲**。

- `CareTodayController` 注入 `EditCareSlot`,新增 `edit(...)` → PUT 後**安靜重載**
  (比照既有 `_mark`:狀態不掉 `loading`、失敗保留清單 + typed error、401 → reauth)。
- `_DoneGroup` 每列加 edit affordance(trailing icon)→ bottom sheet(專案慣例)。
  - **列的 key 必須是複合鍵** `${careScheduleId}-${localDate}-${timeOfDay}`
    (比照 `care_history_screen.dart` 的 `_slotCompositeKey`):現行
    `Key('care-today-row-${slot.careScheduleId}')` 對「一天兩次的排程」會產生**重複 key**,
    測試無法指定要編輯哪一列。
  - **sheet 的控制項**(這次要收「狀態 + 時間」兩件事,所以不像 `/care-history` 那樣
    「點一下就 pop」,需要一個確認鍵與 sheet 內的暫存狀態):
    | 控制項 | Key | 說明 |
    |---|---|---|
    | 標頭 | `care-today-edit-sheet-title` / `-subtitle` | 項目名 / 日期 · 排程時段 · 現狀 |
    | 狀態 | `care-today-edit-status-done` / `-skipped` | 兩選一 |
    | 完成時間 | `care-today-edit-time` | `ListTile`,顯示目前選定的本地時分,點擊開 picker;**選「略過」時停用** |
    | 送出 | `care-today-edit-submit` | `FilledButton` |
    新 ARB key:sheet 標題、時間列標籤、送出鍵文字。

### C. 時區:採用 repo 既有的注入 seam(**不要重新發明**)

`lib/contexts/health/presentation/today_screen.dart` 對「後端 UTC 瞬間 ↔ 本地 `HH:mm`
↔ `showTimePicker`」已有成熟且測過的解法,其註解明說注入的理由是
「so tests can verify the conversion deterministically regardless of the host machine's
timezone」。**照抄**:

- `CareTodayScreen` 加兩個可注入參數:
  - `DateTime Function(DateTime) toLocalTime`,預設 `(dt) => dt.toLocal()`。
    **`.toLocal()` 是這次的核心動作**:後端 `done_time` 是 `toISOString()`,
    `DateTime.parse` 回來是 `isUtc: true`,**少了 `.toLocal()` 就會顯示 UTC 時分**
    (Asia/Taipei 使用者會看到 04:58 而不是 12:58)——那正是 issue 第 4 點的 bug。
  - `Future<DateTime?> Function(BuildContext, CareTodaySlot, DateTime Function(DateTime))
    pickDoneTime`,預設包 `showTimePicker`:初始值取既有 `doneTime` 的本地時分
    (無則 slot 的 `timeOfDay`),選定後與 **slot 自己的 `localDate`**(用
    `parseDayString`,**不是**「今天」)組成本地 `DateTime` 再 `.toUtc()`。
    用 slot 自己的日期,跨午夜時才不會寫錯日子。
    - 沒有 `doneTime` 時要把 `slot.timeOfDay`(`'HH:mm'` 字串)解析成 `TimeOfDay`。
      repo 現有三份同樣的解析都是**私有**的(`care_item_form.dart`、`vitals_screen.dart`、
      `trend_card.dart`),**這次在 `care_today_screen.dart` 內再開一份私有 helper**
      (第 4 份)—— 不為單一使用點做跨檔重構,免得 diff 擴大。
- **顯示**:`DateFormat('HH:mm').format(toLocalTime(parsed))`。
- shared 只加**純解析**的 `parseInstant(String iso) → DateTime?`
  (`DateTime.tryParse`,無效回 `null`),**時區轉換不放 shared** —— 放在畫面的注入點,
  測試才能注入非 identity 的轉換來證明「真的有走轉換」。

**⚠️ 為什麼不能只靠「自己算期望值」的測試**:CI(`.github/workflows/ci.yml`)在 ubuntu
runner 上跑,`TZ` = UTC,此時 `.toLocal()` 是 identity —— 那種測試**恆真**,抓不到少寫
`.toLocal()` 的 bug。必須注入非 identity 的假轉換直接斷言。

### D. 只有今日可編輯

- `/care-history` 的 `_SlotTile` 收 `editable`,由 `slot.localDate == today` 決定;
  過去的列無 trailing edit icon、`onTap: null`。
- today 用畫面既有的 `clock`(#91 之後它的用途只剩「今日」表頭,這是第二個用途)。
- **後端不設限**(backend#53 明說那是 UI 決策,不是安全邊界)。

### E. ⋮ 移除註記項

刪掉 `PopupMenuItem(enabled: false)` + `PopupMenuDivider` 與 ARB key
`careHistoryTrendsMovedHint`(三檔)。順帶解掉一條既有 follow-up —— 那個 disabled item
會被螢幕閱讀器念成「選單項目,按鈕,已停用」,鍵盤也跳過它。

## UI/UX 設計

- **可編輯性要看得出來**:可編輯的列有 trailing edit icon,唯讀的列沒有 —— 不靠「點了
  沒反應」讓使用者自己發現。
- **修正的入口在「已經發生的事」旁邊**:已完成區就是使用者回頭看「我幾點吃的」的地方,
  修正入口放這裡最短。
- **`missed` 也在已完成區**(`deriveGroups` 把 done|skipped|missed 都歸進去),
  而 `/care-history` 過去的列變唯讀後,**missed 的補登入口主要就落在這裡** —— 必須同樣
  可修正。
- **失敗不可無聲**:被 re-entrancy gate 丟棄的送出也要有提示(見 §B)。

## 不做(YAGNI / 越界)

- **不動** `/care-history` 編輯 sheet 加時間選擇:那裡只剩今天可編輯,而今天的編輯已經
  有今日照護這個更好的入口。兩處 sheet 的差異保持最小,不為單一使用者抽共用元件。
- **不動**後端、不動排程時間(`timeOfDay`)的編輯(那是照護管理的排程設定)。
- **不做**「清除完成時間」:`done_time: null` 在後端是「不要動」而非「清空」。
- **不動** `markDone`/`markSkipped`:它們維持 `Future<void>` 與既有的
  「await 後讀 `markError`」判讀法。雖然那正是 §B 禁止的 anti-pattern,而且
  `care_today_controller.dart` 的 `if (marking) return;` 發生在 `markError = null` **之前**
  (所以被 gate 丟棄的 mark 會沿用上一次的 markError,可能誤跳或無聲),但一起改會波及
  6 檔 8 處建構點、超出本次範圍 —— **列為 follow-up**。新的 `edit()` 走新慣例。

## 驗收標準

1. 今日照護「已完成」列(含 `missed`)可點開編輯 sheet,能改狀態與**完成時間**。
2. 編輯安靜重載,不整頁 loading;失敗保留清單並顯示錯誤;**被 gate 丟棄時也有提示**。
3. 完成時間以**本地時分**顯示(不再是 `2026-07-27T04:58:00.000Z`),且**測試證明真的
   走了時區轉換**(注入非 identity 的 `toLocalTime`),不是靠 runner 剛好是 UTC。
4. `/care-history` 只有**今天**的列可編輯;過去的列**沒有 edit icon** 且點了不開 sheet。
5. `/care-history` ⋮ 不再有註記項,兩個導覽入口仍在。
6. 送出的 `done_time` 是帶 `Z` 的 UTC ISO,由 **slot 的 `localDate`** + 選定時分組成;
   `skipped` 時**不送**該鍵。

## 測試策略

- shared:`parseInstant`(合法 ISO → DateTime、無效 → null)。
- infrastructure:`editSlot` 帶 `doneTime` → body 有 `done_time` 且為 UTC ISO;
  不帶 → **沒有該鍵**;`skipped` → 沒有該鍵。
- `CareTodayController.edit`:成功→安靜重載;失敗→保留清單 + error;401→reauth;
  **被 gate 丟棄 → 回傳值可辨識**。
- `CareTodayScreen` widget test:**注入** `toLocalTime`(非 identity)證明顯示走了轉換;
  **注入** `pickDoneTime` 繞過真正的 time picker(比照 `today_screen_test.dart`);
  已完成列(含 missed)有 edit icon → sheet → 送出的 `doneTime` 由 **slot 的 localDate**
  組成;複合 key 能在「一天兩次排程」時指定正確的列。
- `CareHistoryScreen` widget test:今天可編輯、**過去無 edit icon 且點了不開 sheet**;
  ⋮ 無註記項。
- **DI 波及**(必須一併更新,否則整包編譯失敗):`CareTodayController(` 共
  **6 檔 8 處**建構點(`app_pending_deep_link_test.dart` **×3**、`app_test.dart`、
  `health_scaffold_test.dart`、`care_today_controller_test.dart`、
  `care_today_screen_test.dart`、`care_today_summary_card_test.dart`);`editSlot` 的實作共 1 prod + 6 fake
  (`http_care_history_repository.dart`、`app_test.dart` ×2、`health_scaffold_test.dart`、
  `care_adherence_card_test.dart`、`care_history_controller_test.dart`、
  `care_history_screen_test.dart`)。Dart 不允許 override 少收具名參數,**漏一個就整包紅**。
