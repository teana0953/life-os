# Tasks

## 1. 共用 MonthPickerDialog

- [ ] 1.1 `lib/shared/widgets/month_picker_dialog.dart`:`showMonthPicker(context, {required initialMonth, firstMonth, lastMonth})` → `Future<DateTime?>`(回傳選中月的 1 號,取消回 null)。版面:`AlertDialog` + 年份列 `‹ 2026 ›` + 4×3 月份格;當前月高亮**且加語意 selected**(不只靠色);超界月份與年份箭頭 disabled。Keys:`month-picker-year-previous/next`、`month-picker-year-label`、`month-picker-month-<1..12>`。全走 theme 與 ARB,不 hard-code 色/字串。
- [ ] 1.2 測試:年份前後切、選月回傳正確 DateTime、取消回 null、first/last 邊界 disabled(月份格與年份箭頭都要驗)、當前月標記。

## 2. MonthNavHeader 接上

- [ ] 2.1 `month_nav_header.dart` 加**可選** `onPickMonth`(VoidCallback?):有傳時月份標籤包成可點(`<keyPrefix>-label` key 不變、文字不變),不傳時維持純 Text。測試:不傳時不可點(既有行為)、有傳時點擊觸發。
- [ ] 2.2 財務兩處接上:`finance_overview_tab.dart`(keyPrefix `finance-month`)、`networth_tab.dart`(`networth-month`)——點標籤開 picker,選到的月餵給既有的月份切換路徑(**走既有 controller 的月份 gate,不繞過競態防線**)。財務不設 first/last 邊界。

## 3. diet 月曆接上

- [ ] 3.1 `diet_day_screen.dart` 的月份標題(:331 附近 `monthYearLabel`)變可點,開 picker;`lastMonth` = 當月(未來月不可選),`firstMonth` 不設。選中後更新 `_visibleMonth`。
- [ ] 3.2 測試:點標題開 picker、選月後月曆切到該月、未來月 disabled。

## 4. i18n + 收尾

- [ ] 4.1 ARB 三檔(en 含 description、zh_Hant、zh)+ `flutter gen-l10n`:對話框標題、月份短名(或用 `DateFormat` 產生——**優先用 intl 的月份名**,避免手寫 12×3 筆)、年份箭頭 tooltip。generated commit。
- [ ] 4.2 迴歸:既有 `finance-month-*`、`networth-month-*`、diet 月曆測試全綠(**不修改既有測試**;若非改不可代表行為變了,停下回報)。
- [ ] 4.3 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
