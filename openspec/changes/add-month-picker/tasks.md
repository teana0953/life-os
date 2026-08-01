# Tasks

## 1. 共用 MonthPickerDialog

- [x] 1.1 `lib/shared/widgets/month_picker_dialog.dart`:`showMonthPicker(context, {required initialMonth, firstMonth, lastMonth})` → `Future<DateTime?>`(回傳選中月的 1 號,取消回 null)。版面:`AlertDialog` + 年份列 `‹ 2026 ›` + 4×3 月份格;當前月高亮**且加語意 selected**(不只靠色);超界月份與年份箭頭 disabled;**內建 1970–2100 年份防呆界**(非業務邊界,防年份無限步進產出爛字串)。Keys:`month-picker-year-previous/next`、`month-picker-year-label`、`month-picker-month-<1..12>`。全走 theme 與 ARB,不 hard-code 色/字串。
- [x] 1.2 測試:年份前後切、選月回傳正確 DateTime、取消回 null、first/last 邊界 disabled(月份格與年份箭頭都要驗)、當前月標記、**1970/2100 防呆界擋住年份步進**。

## 2. MonthNavHeader 接上

- [x] 2.1 `month_nav_header.dart` 加**可選** `onPickMonth`(VoidCallback?):有傳時月份標籤可點,**但 `<keyPrefix>-label` 的 key 必須留在 `Text` 上**(可點的 wrapper 包在外層)——既有 `networth_tab_test.dart:301` 做 `tester.widget<Text>(byKey(...))`,key 移到 wrapper 會炸。不傳時維持純 Text。測試:不傳時不可點(既有行為)、有傳時點擊觸發、key 仍解析為 Text。
- [x] 2.2 財務兩處接上:`finance_overview_tab.dart`(keyPrefix `finance-month`)、`networth_tab.dart`(`networth-month`)——點標籤開 picker,選到的月餵給既有的月份切換路徑(**走既有 controller 的月份 gate,不繞過競態防線**)。財務不設 first/last 業務邊界。

## 3. diet 月曆接上

- [x] 3.1 `diet_day_screen.dart` 的月份標題(:331 附近 `monthYearLabel`,key `calendar-month-label`)變可點,開 picker;**不設 first/last**(與既有 › 箭頭一致——現有箭頭對未來月無上界)。選中後**走既有 `_changeMonth` 的等價路徑:更新 `_visibleMonth` 後必須呼叫 `_loadLoggedDays()`**,否則新月份會留著舊月份的記錄圓點(靜默錯誤資料)。
- [x] 3.2 測試:點標題開 picker、選月後月曆切到該月、**且 loggedDays 有重抓**(斷言 fake repository 收到新月份的查詢)。

## 3b. 月經月曆接上

- [ ] 3b.1 `menstrual_calendar.dart:95-118` 的月份標題(key `menstrual-month-label`)變可點,開同一個 picker;不設邊界(既有箭頭亦無界);選中後更新 `_visibleMonth`(純本地,無 fetch)。
- [ ] 3b.2 測試:點標題開 picker、選月後月曆切到該月;既有 `menstrual-prev-month`/`next-month` 行為不變。

## 4. i18n + 收尾

- [ ] 4.1 月份名用 **intl `DateFormat.MMM(locale)`**(短名——`zh` 的 `MONTHS` 是「三月」、`SHORTMONTHS` 才是「3月」,必須用 MMM),不手寫 36 筆;對話框標題與年份箭頭 tooltip 走 ARB 三檔 + `flutter gen-l10n`,generated commit。
- [ ] 4.2 迴歸:既有 `finance-month-*`、`networth-month-*`、diet 月曆、`menstrual-*-month` 測試全綠(**不修改既有測試**;若非改不可代表行為變了,停下回報)。
- [ ] 4.3 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
