## Why

Issue #114:「健康或是財務裡的時間選擇,如果跨度大會不方便——目前只能一個月一個月跳,如果想看去年或前年的會很不方便。」

掃描後痛點集中在**只有前後箭頭、沒有直接跳轉入口**的兩處:財務的月份列(`MonthNavHeader`,總覽 + 淨值)與 diet 的自繪月曆。回去年要點 12 次箭頭。其餘位置(簡易 tracker、月經、記帳日期欄)都已有 `showDatePicker` 可跳年,不是痛點。

## What Changes

- 新增共用 `MonthPickerDialog`(`lib/shared/widgets/month_picker_dialog.dart`)+ `showMonthPicker()` helper:年份 `‹ 2026 ›` 切換 + 4×3 月份格,一步跳到任意年月;可選 `firstMonth`/`lastMonth` 邊界(超界的月份與年份箭頭 disabled)。
- `MonthNavHeader` 新增**可選** `onPickMonth`:有傳時月份標籤可點開選擇器,不傳維持純文字(既有呼叫端契約不變)。
- 財務兩處(總覽 `finance-month`、淨值 `networth-month`)接上。
- diet 月曆的月份標題同樣可點,接同一個 dialog(`lastMonth` = 當月)。

範圍外:已可跳年的 `showDatePicker` 各處、既有 `firstDate` 邊界值調整、年份清單選擇器、日期範圍選擇。

## Capabilities

### New Capabilities

- `shared-widgets`:月份選擇對話框——年份切換 + 月份格,可設上下界,供任何「以月為單位」的畫面一步跳轉。

### Modified Capabilities

- `finance-ledger-ui`:財務的月份列可點標籤跳到任意年月,不再只能逐月前後切。
- `health-diet`:diet 月曆可點月份標題跳到任意年月。

## Impact

- 新增 `lib/shared/widgets/month_picker_dialog.dart` + 測試。
- `lib/shared/widgets/month_nav_header.dart`:+ 可選 `onPickMonth`(既有 key 與行為不變)。
- `finance_overview_tab.dart` / `networth_tab.dart` / `diet_day_screen.dart`:接上跳轉。
- `lib/l10n/*.arb` + generated(月份名、對話框標題、tooltip)。
