# Tasks

## 1. 純函式：五種狀態 (TDD)

- [ ] Test first：`test/contexts/menstrual/domain/next_period_status_test.dart`
  - 沒有任何紀錄 → `notEnoughData`
  - 有紀錄但 `predictedNextStart == null`（少於兩次）→ `notEnoughData`
  - 預測在未來 → `upcoming` + 正確天數；**跨月**（7/28 → 8/2 = 5 天）
  - 預測是今天 → `today`（**不是** `upcoming` 且天數 0）
  - 預測在過去 → `overdue` + 正確天數
  - 今天在最近一次週期內（已結束的）→ `ongoing` + 第 N 天；**起始日當天 = 第 1 天**（不是第 0 天）
  - 最近一次沒有結束日且起始日在今天之前 → `ongoing`
  - **`ongoing` 優先於 `overdue`**：既有一段涵蓋今天、預測日又在過去 → `ongoing`
  - 最近一次週期的**結束日就是今天** → 仍是 `ongoing`（閉區間）
  - 最近一次週期**昨天結束** → 不是 `ongoing`
  - **UTC 正規化**：`TZ=UTC` 與 `TZ=Asia/Taipei` 兩種環境下天數相同（design D2）。這個 repo 兩種相反的時區失敗都踩過
- [ ] `lib/contexts/menstrual/domain/next_period_status.dart`：`NextPeriodStatus`（kind + 可選 date + 可選 days）與 `computeNextPeriodStatus(overview, today)`。**純函式，不碰 DateTime.now()**

## 2. 卡片 (TDD)

- [ ] Test first：`test/contexts/menstrual/presentation/next_period_card_test.dart`
  - 五種狀態各渲染出對應文案（用 `loc.xxx` 比對，不寫死字串）
  - **點擊卡片會呼叫 `onOpen`**，且**沒有預測時也會**（D6）
  - 首次載入（`loading` 且 `overview == null`）→ 轉圈
  - **重新載入（`loading` 但已有 overview）→ 保留內容，不退回轉圈**（#82 的教訓；這條要能紅）
  - `error` → 卡內錯誤訊息
  - 卡片**不呼叫** `load`（D4）—— 用假 controller 斷言 load 次數為 0
- [ ] `lib/contexts/menstrual/presentation/next_period_card.dart`：`LedgeCard` + `InkWell`，比照 `GoalCard`。`clock` 注入（D3）

## 3. l10n

- [ ] 三個 ARB 加：`nextPeriodTitle`、`nextPeriodUpcoming`(date, days)、`nextPeriodToday`、`nextPeriodOverdue`(date, days)、`nextPeriodOngoing`(day)、`nextPeriodNoPrediction`。en 要有 `@` 描述
- [ ] 日期格式用既有的 `mediumDateLabel`（生理期頁統計卡就是用它）
- [ ] 重產 `lib/l10n/generated/` 並 commit（tracked）

## 4. 接進總覽

- [ ] `_OverviewBody` 加 `NextPeriodCard`，**放最後**（月曆之後），`onOpen: () => context.push('/menstrual')`
- [ ] `_OverviewBody` 收 `MenstrualController` 參數；`HealthScaffold` 傳下去
- [ ] **`_overviewControllers` 加 `menstrualController`** —— 否則卡片不會跟著重建
- [ ] **`_overviewNeedsReauth` 加 menstrual 的 `needsReauth`** —— 否則生理期 401 被吞掉（照護卡踩過同款：#82 的 blocking）
- [ ] 測試：總覽上看得到這張卡、點了會導到生理期頁（**用 production 的 router，不要自建**——這是 #88 那輪抓到的坑）

## 5. Gate

- [ ] `flutter analyze` 零 issue、`flutter test` 全綠、**`TZ=UTC flutter test` 也全綠**。基準 **1177 passed / 1 skipped**

## 6. On-device verification (manual — 需使用者)

- [ ] 總覽最下面看得到卡片，點了會到生理期頁、返回鍵回得來
- [ ] 目前狀態顯示正確（進行中／還有幾天／已晚幾天）
- [ ] 窄螢幕上讀得順
