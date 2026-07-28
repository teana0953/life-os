# Tasks

## 1. 共用標記元件 (TDD)

- [ ] Test first：`test/shared/widgets/stale_notice_test.dart` —— 渲染文案、點重試會呼叫回呼
- [ ] `lib/shared/widgets/stale_notice.dart`：一條窄橫列（文案 + 重試），四張卡共用。**放在卡片內容之下**（四張卡版型差異極大 —— 128px 兩行到 438px 整月月曆 —— 尾端是唯一不用動既有版型就能插入的位置）
- [ ] l10n 三個 ARB 加 `cardRefreshFailed`（zh：沒有更新到 / en：Couldn't refresh）。en 要有 `@` 描述。**重試沿用既有的 `retry`**，不要開新 key

## 2. 四張卡改判斷 (TDD)

每張卡的規則都一樣：**有內容就保留內容 + 標記；沒內容才顯示錯誤卡**。

- [ ] `GoalCard`：error 分支加 `goal == null` 條件；有 goal 時走正常渲染 + `StaleNotice`。**既有測試 `a reload failure after a successful load surfaces the error`（`goal_card_test.dart:187`）斷言的正是被取代的行為 —— 要改寫成新行為，不是刪掉**。L96 那段註解也要改：顧慮沒有被推翻，是被標記補上
- [ ] `HealthCalendarCard`：同上。**這張卡完全沒有 reload 失敗的測試**（全檔只有 3 條），要新增
- [ ] `NextPeriodCard`：同上。既有錯誤測試沒有預先塞資料，所以「已有資料再失敗」零覆蓋，要新增
- [ ] `CareTodaySummaryCard`：兩件事
  - 已有 summary + 失敗 → 保留 + 標記（目前完全靜默）
  - **從未載入 + 失敗 → 顯示錯誤卡 + 重試**（目前 `SizedBox.shrink()`，整張消失、無訊息、無重試 —— 它是總覽最上面那張，使用者只會看到「今日照護不見了」）。既有測試 `a first-ever load that ends in error (never loaded before) still renders nothing`（`care_today_summary_card_test.dart:345`）把現行行為釘死了，要改寫
  - **仍然要保留**：從未載入 + 載入**中** → `SizedBox.shrink()`（這條沒變）

## 3. 每張卡的測試矩陣

每張卡都要有這四條（目前只有 `GoalCard` 與 `CareTodaySummaryCard` 部分有）：

- [ ] 首次載入中（無資料）→ 各自的 loading 呈現
- [ ] 首次載入失敗（無資料）→ 錯誤 + 重試，**沒有** `StaleNotice`
- [ ] 已有資料 + 重新載入中 → 保留內容，**沒有** `StaleNotice`（載入中不是失敗）
- [ ] 已有資料 + 重新載入失敗 → 保留內容 + `StaleNotice` + 重試只重載自己那個 controller（假 controller 斷言 load 次數與參數）
- [ ] **重試成功後標記消失**（狀態回 loaded）

## 4. 版面

- [ ] 加了標記之後，錯誤狀態不再讓總覽塌陷。實測四張卡「正常 vs 有標記」的高度差，確認只多一列
- [ ] 窄螢幕（320/360）× textScale 1.0/1.5/2.0 不 overflow

## 5. Gate

- [ ] `flutter analyze` 零 issue、`flutter test` 全綠。基準 **1215 passed / 1 skipped**

## 6. On-device verification (manual — 需使用者)

- [ ] 開飛航模式進總覽 → 四張卡都該顯示「沒有更新到」而不是空白或紅卡（若已有快取資料）
- [ ] 點單張卡的重試 → 只有那張動
- [ ] 全新帳號（無任何資料）+ 斷網 → 四張卡都顯示錯誤 + 重試，沒有一張安靜消失
