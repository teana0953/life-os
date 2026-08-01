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

- [x] 3b.1 `menstrual_calendar.dart:95-118` 的月份標題(key `menstrual-month-label`)變可點,開同一個 picker;不設邊界(既有箭頭亦無界);選中後更新 `_visibleMonth`(純本地,無 fetch)。
- [x] 3b.2 測試:點標題開 picker、選月後月曆切到該月;既有 `menstrual-prev-month`/`next-month` 行為不變。

## 4. i18n + 收尾

- [x] 4.1 月份名用 **intl `DateFormat.MMM(locale)`**(短名——`zh` 的 `MONTHS` 是「三月」、`SHORTMONTHS` 才是「3月」,必須用 MMM),不手寫 36 筆;對話框標題與年份箭頭 tooltip 走 ARB 三檔 + `flutter gen-l10n`,generated commit。
- [x] 4.2 迴歸:既有 `finance-month-*`、`networth-month-*`、diet 月曆、`menstrual-*-month` 測試全綠(**不修改既有測試**;若非改不可代表行為變了,停下回報)。
- [x] 4.3 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。

## 5. Review/QA 後追加(第二輪)

> 這些是 review legs 與使用者追加的需求,與前四節同源(時間選擇跨度),併入本 change。

- [ ] 5.1 **月份格尺寸(uiux blocking)**:實測預設 theme 下月份格在 320dp 寬只剩 40dp、文字換行、低於 48dp 觸控下限。修:`AlertDialog` 的 `insetPadding` 16 + `contentPadding` 16、月份格 compact padding + `minimumSize(0, 48)` + `maxLines: 1`。測試:320/360/390 三種寬度 × en/zh 兩語系,月份格 ≥48dp 高且文字不換行。
- [ ] 5.2 **可發現性(uiux blocking + 使用者指定)**:四個月份標籤入口(財務兩處經 `MonthNavHeader`、diet、月經)加 `Icons.arrow_drop_down` 明示可展開,四處一致;同時補 tooltip(箭頭都有、標籤沒有)。dialog 內年份標籤同樣加 `▾`。
- [ ] 5.3 **年份清單(使用者判定逐年箭頭不夠)**:dialog 的年份標籤可點,開可捲動年份清單(1970–2100 防呆界內,預設捲到當前年附近),選年後回到月份格。年份箭頭保留。Keys:`month-picker-year-label`(可點)、`month-picker-year-<YYYY>`。測試:開清單、選遠年、清單捲動位置合理。
- [ ] 5.4 **健康記錄月曆可切月(使用者追加)**:`health_calendar_controller.dart` 加 `selectedMonth` 狀態 + `loadMonth(idToken, year, month)`(**含競態防線**:回應落地前確認仍是當前選中月——本專案累犯);`health_calendar_card.dart` 加 `MonthNavHeader`(keyPrefix `health-calendar-month`)。預設當月。後端 `getHealthCalendar` 已收 year/month,不動後端。測試:切月載入該月、跳月、競態(舊月回應不覆蓋)、預設當月。
- [ ] 5.5 **code review 的兩條**:(a)`initialMonth` 落在 bounds 之外時 12 格與兩個年份箭頭全 disabled 變死巷——clamp `initialMonth` 進範圍或至少讓年份箭頭可動;(b)兩個測試檔逐字重複的 20 行活樹走訪 helper 收進 `test/support/`。
- [ ] 5.6 迴歸與收尾:既有測試零改動(`git diff --numstat main...HEAD -- test/` 除既有那 1 行 diet fake stub 外不得再增加刪除);`bash scripts/lint-actions.sh` + `flutter analyze` 0 issue + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
