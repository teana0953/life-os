## Why

Issue #114:「健康或是財務裡的時間選擇,如果跨度大會不方便——目前只能一個月一個月跳,如果想看去年或前年的會很不方便。」

痛點分兩類:**只有前後箭頭、沒有跳轉入口**的三處(財務月份列、diet 月曆、月經月曆——回去年要點 12 次箭頭),以及**完全不能切月**的健康記錄月曆卡(使用者追加回報「現在只能看本月無法看歷史」)。其餘位置(簡易 tracker、月經起訖日欄、記帳日期欄)都已有 `showDatePicker` 可跳年,不是痛點。

## What Changes

- 新增共用 `MonthPickerDialog`(`lib/shared/widgets/month_picker_dialog.dart`)+ `showMonthPicker()` helper:年份 `‹ 2026 ›` 切換 + 4×3 月份格,一步跳到任意年月;可選 `firstMonth`/`lastMonth` 邊界(超界的月份與年份箭頭 disabled)。
- `MonthNavHeader` 新增**可選** `onPickMonth`:有傳時月份標籤可點開選擇器,不傳維持純文字(既有呼叫端契約不變)。
- 財務兩處(總覽 `finance-month`、淨值 `networth-month`)接上。
- diet 月曆與月經月曆的月份標題同樣可點,接同一個 dialog;picker 範圍與各自既有箭頭一致(diet 選月後需重抓該月 loggedDays)。
- **健康記錄月曆卡**從寫死當月改為可切月:controller 加 `selectedMonth` + `loadMonth`(含競態防線),卡片加 `MonthNavHeader`。後端已收 year/month,不需改動。
- 年份標籤可點開年份清單(跨多年時比逐年箭頭快),月份標籤加 `▾` 明示可展開。

範圍外:已可跳年的 `showDatePicker` 各處、既有 `firstDate` 邊界值調整、年份清單選擇器、日期範圍選擇;care/vitals 的 7/30/90 相對區間(不同的時間選擇模型,另案)。

## Capabilities

### Modified Capabilities(既有 capability,新增 requirement)

- `shared-widgets`:月份選擇對話框——年份切換 + 月份格,可設上下界,供任何「以月為單位」的畫面一步跳轉。

- `finance-networth-ui`:共用月份列(`MonthNavHeader`)可點標籤跳到任意年月,不再只能逐月前後切(該 requirement 住在此 capability)。
- `health-diet`:diet 月曆可點月份標題跳到任意年月。
- `menstrual-ui`:月經月曆可點月份標題跳到任意年月。
- `health-calendar-card`:記錄月曆從只能看當月變成可切月/可跳月。

## Impact

- 新增 `lib/shared/widgets/month_picker_dialog.dart` + 測試。
- `lib/shared/widgets/month_nav_header.dart`:+ 可選 `onPickMonth`(既有 key 與行為不變)。
- `finance_overview_tab.dart` / `networth_tab.dart` / `diet_day_screen.dart` / `menstrual_calendar.dart`:接上跳轉;`health_calendar_controller.dart` + `health_calendar_card.dart`:新增月份切換。
- `lib/l10n/*.arb` + generated(對話框標題、年份箭頭 tooltip;**月份名走 intl `DateFormat.MMM`,不進 ARB**)。
