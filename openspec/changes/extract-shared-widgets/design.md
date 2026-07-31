# 共用元件抽取(第一批:純抽取)— 設計

來源:`.devloop/archive/add-finance-networth-ui/shared-components-audit.md`(全專案共用元件盤點,使用者要求做「第一批」)。

## 目標

把五組**逐字重複**的樣板抽成共用元件/純函式。**零行為改變、零 widget key 變動**——既有測試應該完全不用改就綠。

## 範圍

| # | 抽出物 | 重複份數 | 落點 |
|---|---|---|---|
| 1 | `monthWeeks(DateTime)` 純函式 | 3 | `lib/shared/date/month_grid.dart` |
| 2 | `DateField` widget | 2 | `lib/shared/widgets/date_field.dart` |
| 3 | `CardErrorRetry` widget | 5 | `lib/shared/widgets/card_error_retry.dart` |
| 4 | `CardLoading` widget | 5 | `lib/shared/widgets/card_loading.dart` |
| 5 | `TrackerBusyBar` widget | 5 | `lib/shared/widgets/tracker_busy_bar.dart` |

## 範圍外(盤點第二批,不在本 change)

`pickTime24()` 修 vitals 的 12/24 小時 bug、finance sheet 的 needsReauth 訊息映射、SheetForm 外殼、空狀態家族、`showDatePicker` 邊界統一(真差異,盤點明確不建議)、diet 改用 TrackerDayScreen mixin(盤點明確不建議——踩日期錯位累犯區)。

## 各項細節

### 1. `monthWeeks(DateTime)`

三份逐字相同(連 `// DateTime.sunday == 7` 註解都一樣):
- `menstrual_calendar.dart:85-101`
- `health_calendar_card.dart:206-218`
- `diet_day_screen.dart:299-316`

邏輯:週日優先、前置 null 補白、尾端補滿 7 的倍數、切 `List<List<int?>>`。差異:零。

放 `lib/shared/date/month_grid.dart`(不塞進 day_format.dart——那是格式化,這是日曆格線,職責不同)。純函式,補測試:閏年二月、1 號是週日、1 號是週六、月末補白。

### 2. `DateField`

- `menstrual_screen.dart:532-571`
- `chaodays_import_screen.dart:470-511`

除 `onTap` 可空性外逐字相同。API:
```dart
class DateField extends StatelessWidget {
  const DateField({super.key, required this.fieldKey, required this.label,
    required this.value, required this.placeholder, required this.onTap});
  // value: DateTime?  onTap: VoidCallback?(null = 停用)
}
```
取較寬鬆的 `VoidCallback?` 涵蓋兩者。key 由 `fieldKey` 帶入→既有測試不變。

### 3. `CardErrorRetry`

五份:`goal_card.dart:111-131`、`next_period_card.dart:68-88`、`trend_card.dart:124-143`、`health_calendar_card.dart:77-97`、`care_adherence_card.dart:226-250`。

差異只有:訊息文案、兩個 key、間距(12 vs 16)、care 那份多保留 header。全部參數化:
```dart
class CardErrorRetry extends StatelessWidget {
  const CardErrorRetry({super.key, required this.message, required this.messageKey,
    required this.retryKey, required this.onRetry, this.header, this.spacing = 12});
}
```

### 4. `CardLoading`

五份(`goal_card:83`、`next_period_card:94`、`trend_card:111`、`health_calendar_card:56-67`、`care_adherence_card:175`),差異只有 indicator 的 key:
```dart
class CardLoading extends StatelessWidget {
  const CardLoading({super.key, required this.indicatorKey});
}
```
注意 health_calendar_card 那份的 padding/尺寸若與其他不同,以參數涵蓋或保留原值——**不得改變任何一頁的視覺**。

### 5. `TrackerBusyBar`

五份(`vitals_screen:289`、`water_screen:160`、`exercise_screen:172`、`bowel_screen:120`、`menstrual_screen:194`),差異只有 key:
```dart
class TrackerBusyBar extends StatelessWidget {
  const TrackerBusyBar({super.key, required this.busy, required this.indicatorKey});
}
```
**不要**放進 `TrackerDayScreen` mixin(menstrual 沒用那個 mixin)。

## 風險與紀律

- **零行為改變**是本 change 的硬約束:每個呼叫點的 widget key、文案、間距、尺寸都必須與抽取前逐一相同;有任何差異就參數化,不得「順手統一」。
- 若某個呼叫點與其他份有真差異(非文案/key/間距),**保留原地不動**並在 tasks 記錄原因,不硬塞進共用件。
- 不動測試檔:既有測試零改動即綠是驗收標準之一;若某測試必須改,視為訊號——回頭確認是不是行為變了。

## 測試

- `monthWeeks`:新增純函式測試(閏年、1 號週日/週六、補白)。
- 三個 widget:各補一支基本 widget test(key 存在、callback 觸發、參數化分支如 header/spacing)。
- 迴歸:`flutter test` 全套零改動即綠;`TZ=UTC flutter test` 複驗(月曆函式碰日期)。

## 驗收

五組抽取完成、各呼叫點改用共用件;既有測試**未經修改**全綠;`flutter analyze` 0 issue;削減約 200 行重複碼。
