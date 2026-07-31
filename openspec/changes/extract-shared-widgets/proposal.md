## Why

全專案共用元件盤點(`.devloop/archive/add-finance-networth-ui/shared-components-audit.md`)發現:大塊抽象化做得好,但小塊樣板每個 context 各複製一份。使用者要求先做「第一批:純抽取」——五組逐字重複、零行為改變、零 key 變動的樣板。

淨值那輪 review 抓到的問題有一半是樣板複製出來的變體(錯誤+重試各寫各的、reauth 出口不一致);收斂共用件之後再做分帳(sub-project 4),新頁面站在乾淨基礎上,少長同類 bug。

## What Changes

抽出五組逐字重複的樣板,各呼叫點改用共用件:

- `monthWeeks(DateTime)` → `lib/shared/date/month_grid.dart`(3 份逐字純函式:menstrual_calendar / health_calendar_card / diet_day_screen)
- `DateField` → `lib/shared/widgets/date_field.dart`(2 份:menstrual_screen / chaodays_import_screen)
- `CardErrorRetry` → `lib/shared/widgets/card_error_retry.dart`(5 份:goal_card / next_period_card / trend_card / health_calendar_card / care_adherence_card)
- `CardLoading` → `lib/shared/widgets/card_loading.dart`(5 份,同上五個卡片)
- `TrackerBusyBar` → `lib/shared/widgets/tracker_busy_bar.dart`(5 份:vitals / water / exercise / bowel / menstrual screen)

**硬約束:零行為改變、零 widget key 變動**——差異(文案、key、間距、header)一律參數化,不「順手統一」;既有測試未經修改即綠是驗收標準。

範圍外(盤點第二批):vitals 的 12/24 小時 picker bug、finance sheet 的 needsReauth 映射、SheetForm 外殼、空狀態家族;以及盤點明確不建議做的 showDatePicker 邊界統一、diet 改用 TrackerDayScreen mixin。

## Capabilities

### New Capabilities

- `shared-widgets`:跨 context 共用的展示元件與日曆格線純函式(卡片錯誤重試/卡片載入/tracker busy bar/日期欄位/月曆週格),行為由呼叫端參數化。

### Modified Capabilities

(無——純重構,所有既有 capability 的行為與測試 key 皆不變。)

## Impact

- 新增 5 個 shared 檔 + 對應測試。
- 改 10 個既有檔的呼叫點(刪約 200 行重複碼),行為不變。
- 既有測試零改動。
