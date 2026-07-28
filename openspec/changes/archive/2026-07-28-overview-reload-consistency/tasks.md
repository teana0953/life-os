# Tasks

## 1. 共用標記元件 (TDD)

- [x] Test first：`test/shared/widgets/stale_notice_test.dart` —— 渲染文案、點重試會呼叫回呼
- [x] `lib/shared/widgets/stale_notice.dart`：一條窄橫列（文案 + 重試），四張卡共用。**放在卡片內容之下**（四張卡版型差異極大 —— 128px 兩行到 438px 整月月曆 —— 尾端是唯一不用動既有版型就能插入的位置）
- [x] **`HealthCalendarCard` 的 `LedgeCard` 已經是 `padding: EdgeInsets.all(20)`**，其餘三張是 zero／null（內距在 `InkWell` 裡）。直接插會讓月曆卡拿到 40 水平內距 —— 正是這條要避免的「各自長得不一樣」，而 §4 只量高度與 overflow，測不到。**把月曆卡的 padding 從 `LedgeCard` 移進它自己的內容**，四張卡就一致了
- [x] **插的位置：`InkWell` 之外、`LedgeCard` 之內。** `GoalCard`／`NextPeriodCard`／`CareTodaySummaryCard` 三張的內容都包在整卡 `InkWell` 裡（分別開編輯表／開生理期頁／push `/care-today`），插在裡面點標記會被帶走。插在外面則沒有內距（care 的 `LedgeCard` 是 `padding: EdgeInsets.zero`），所以 `StaleNotice` 自己帶 `EdgeInsets.symmetric(horizontal: 20, vertical: 12)`，四張卡不傳版型參數 —— 否則會各自長得不一樣
- [x] l10n 三個 ARB 加 `cardRefreshFailed`（zh：沒有更新到 / en：Couldn't refresh）。en 要有 `@` 描述。**重試沿用既有的 `retry`**，不要開新 key

## 2. 四張卡改判斷 (TDD)

每張卡的規則都一樣：**有內容就保留內容 + 標記；沒內容才顯示錯誤卡**。

- [x] `GoalCard`：error 分支加 `goal == null` 條件；有 goal 時走正常渲染 + `StaleNotice`。**既有測試 `a reload failure after a successful load surfaces the error`（`goal_card_test.dart:187`）斷言的正是被取代的行為 —— 要改寫成新行為，不是刪掉**。L96 那段註解也要改：顧慮沒有被推翻，是被標記補上
- [x] `HealthCalendarCard`：同上。**這張卡完全沒有 reload 失敗的測試**（全檔只有 3 條），要新增
- [x] `NextPeriodCard`：同上。既有錯誤測試沒有預先塞資料，所以「已有資料再失敗」零覆蓋，要新增
- [x] `CareTodaySummaryCard`：兩件事
  - 已有 summary + 失敗 → 保留 + 標記（目前完全靜默）
  - **從未載入 + 失敗 → 顯示錯誤卡 + 重試**（目前 `SizedBox.shrink()`，整張消失、無訊息、無重試 —— 它是總覽最上面那張，使用者只會看到「今日照護不見了」）。既有測試 `a first-ever load that ends in error (never loaded before) still renders nothing`（`care_today_summary_card_test.dart:345`）把現行行為釘死了，要改寫
  - **仍然要保留**：從未載入 + 載入**中** → `SizedBox.shrink()`（這條沒變）
  - **「有沒有內容」的判斷用 `controller.date.isNotEmpty || _hasLoadedOnce`**（`CareTodayController.date` 是 `String date = ''`，只在成功 fetch 時寫入、從不清空 —— 它就是「至少成功載入過一次」，而且**跨掛載存活**）。`slots.isNotEmpty` 不需要，它是前者的子集
  - 為什麼不能只看 `_hasLoadedOnce`：它只從 `status == loaded` 播種，controller 是 app 級 singleton，重進 health module 時可能停在 error 但手上還有 slots
  - 為什麼不能改成看 `slots.isNotEmpty`：**「今天沒有排程」的使用者 slots 本來就是空的**，那樣會把既有的 `_SetupPrompt` 分支打掉 —— 正是「No schedules shows a setup prompt, not nothing」那條既有 scenario。用 `date` 兩個洞一起解決：空 slots + 斷網 + 重進 health module 也會正確落到「保留 setup prompt + 標記」
  - **標記文案講「沒有更新到」而不是「這是舊資料」**：`WeightGoalController.load` 先寫 `goal` 再寫 `profile`，body-profile 那半失敗時 `goal` 已經是新鮮資料卻標成 error。「沒有更新到」對「更新了一半」仍然成立，「這是舊資料」不成立

## 3. 每張卡的測試矩陣

每張卡都要有這四條（目前只有 `GoalCard` 與 `CareTodaySummaryCard` 部分有）：

- [x] 首次載入中（無資料）→ 各自的 loading 呈現
- [x] 首次載入失敗（無資料）→ 錯誤 + 重試，**沒有** `StaleNotice`
- [x] 已有資料 + 重新載入中 → 保留內容，**沒有** `StaleNotice`（載入中不是失敗）
- [x] 已有資料 + 重新載入失敗 → 保留內容 + `StaleNotice` + 重試會呼叫**自己那個** controller 的 `load`

**「只重載自己」不能在單卡測試裡驗** —— 單卡 widget test 只有那一個 fake controller，斷言 `loadCount == 1` 恆真、看不到另外三個有沒有被動到。要一條 `health_scaffold_test.dart` 的測試：四張卡都有資料、其中一個進 error，點那張卡的重試，斷言**另外三個的 fake repository 呼叫次數沒有增加**。注意那個檔的 `_buildScaffold` 用的是**真 controller + fake repository**（`calls++` / `errorAfterFirstLoad` 那套），不是 fake controller；`_FakeBodyProfileRepository` 目前還不是可覆寫的參數，要先補。另外全檔只有 `_FakeHealthCalendarRepository` 與 `_FakeCareHistoryRepository` 有 `calls` 計數器，`_FakeCareTodayRepository`／`_FakeMenstrualRepository`／`_FakeBodyProfileRepository` 三個都要補
- [x] **重試成功後標記消失**（狀態回 loaded）
- [x] **care 卡專屬**：載入成功但 `slots` 為空（今天沒排程）→ reload 失敗 → **仍然顯示 `_SetupPrompt` + 標記**，不是錯誤卡。上面四條矩陣抓不到這個（它們都塞非空資料）
- [x] **care 卡專屬**：controller 停在 error 但手上有 slots、卡片重新掛載（模擬重進 health module）→ 顯示內容 + 標記，不是錯誤卡
- [x] **care 卡專屬**：載入成功但 slots 為空 + reload **中** → 仍顯示 `_SetupPrompt`，無標記
- [x] **care 卡專屬**：載入成功但 slots 為空 + reload 失敗 + **卡片重新掛載** → 仍顯示 `_SetupPrompt` + 標記。**這一格是 `controller.date` 而不是 `_hasLoadedOnce`／`slots` 的唯一證明** —— 用另外兩個判斷都會落到錯誤卡

## 4. 版面

- [x] 加了標記之後，錯誤狀態不再讓總覽塌陷。實測四張卡「正常 vs 有標記」的高度差，確認只多一列
- [x] 窄螢幕（320/360）× textScale 1.0/1.5/2.0 不 overflow

## 5. Gate

- [x] `flutter analyze` 零 issue、`flutter test` 全綠。基準 **1215 passed / 1 skipped**

## 5b. UI/UX review 補強

- [x] 按下重試之後**那一列不消失**：按鈕 disabled + spinner，成功才整列消失、失敗回到可按。in-flight 狀態收在 `StaleNotice` 自己（四張卡各傳 `failed` / `loading` 兩個布林），不是四份 `_retryInFlight`
- [x] 卡片在 `failed || loading` 期間都保持 `StaleNotice` **掛載**——不然按下去的那一刻 widget 被卸載，記著的「我按過重試」也跟著沒了
- [x] 整列可點（`InkWell` 包住整列，仍在卡片 `InkWell` 之外）；點 icon、點文字都會重試
- [x] 標記是**單一語意節點**且帶主詞（各卡既有的標題 l10n key），四張卡同時 stale 時四個 label 互不相同
- [x] 重試文字對比：實測舊值 **1.64:1**（`colorScheme.primary` 的粉藍在奶油卡上），改用 `colorScheme.onSurface` → 亮 8.32:1 / 暗 12.25:1
- [ ] **另開 issue（不在這輪）**：網路回來後沒有全域刷新入口——總覽是 `IndexedStack`、沒有 `RefreshIndicator`，只能逐張點重試或重開 app

## 6. On-device verification (manual — 需使用者)

- [ ] 開飛航模式進總覽 → 四張卡都該顯示「沒有更新到」而不是空白或紅卡（若已有快取資料）
- [ ] 點單張卡的重試 → 只有那張動
- [ ] 全新帳號（無任何資料）+ 斷網 → 四張卡都顯示錯誤 + 重試，沒有一張安靜消失
