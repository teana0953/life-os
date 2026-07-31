# Tasks

> 硬約束:零行為改變、零 widget key 變動。任何呼叫點的視覺(間距/尺寸/文案)與 key 都必須與抽取前逐一相同;有差異就參數化,不得順手統一。**既有測試不得修改**——若某測試非改不可,代表行為變了,停下回報。

## 1. monthWeeks 純函式

- [ ] 1.1 `lib/shared/date/month_grid.dart` 新增 `monthWeeks(DateTime)`(週日優先、前後補 null、切整週),搬自三份逐字實作之一。測試 `test/shared/date/month_grid_test.dart`:閏年二月、1 號週日、1 號週六、月末補白。
- [ ] 1.2 三處改用:`menstrual_calendar.dart:85-101`、`health_calendar_card.dart:206-218`、`diet_day_screen.dart:299-316` 刪本地 `_weeks()` 改呼叫共用件。跑既有測試確認不破。

## 2. DateField

- [ ] 2.1 `lib/shared/widgets/date_field.dart`:`DateField({fieldKey, label, value(DateTime?), placeholder, onTap(VoidCallback?)})`,結構照現有(Column > Text(label, labelLarge, onSurfaceVariant) + SizedBox(4) + OutlinedButton(fieldKey) > Align(centerLeft) > Text)。測試:key 存在、value/placeholder 切換、onTap null 時 disabled。
- [ ] 2.2 兩處改用:`menstrual_screen.dart:532-571`、`chaodays_import_screen.dart:470-511`。既有測試零改動確認。

## 3. CardErrorRetry

- [ ] 3.1 `lib/shared/widgets/card_error_retry.dart`:`CardErrorRetry({message, messageKey, retryKey, onRetry, header?, spacing=12})`。測試:key、retry 觸發、header 有無、spacing 參數。
- [ ] 3.2 五處改用:`goal_card.dart:111-131`、`next_period_card.dart:68-88`、`trend_card.dart:124-143`、`health_calendar_card.dart:77-97`(spacing 12)、`care_adherence_card.dart:226-250`(header + spacing 16)。逐一比對抽取前後視覺一致。

## 4. CardLoading

- [ ] 4.1 `lib/shared/widgets/card_loading.dart`:`CardLoading({indicatorKey})`。**先確認五處的 padding/尺寸是否真的一致**(health_calendar_card:56-67 那份要特別看),不一致就參數化,不得改變任一頁視覺。測試:key 存在。
- [ ] 4.2 五處改用:`goal_card:83`、`next_period_card:94`、`trend_card:111`、`health_calendar_card:56-67`、`care_adherence_card:175`。

## 5. TrackerBusyBar

- [ ] 5.1 `lib/shared/widgets/tracker_busy_bar.dart`:`TrackerBusyBar({busy, indicatorKey})`(SizedBox height 3 + busy 時 LinearProgressIndicator minHeight 3)。**不要**放進 TrackerDayScreen mixin(menstrual 沒用)。測試:busy true/false。
- [ ] 5.2 五處改用:`vitals_screen:289`、`water_screen:160`、`exercise_screen:172`、`bowel_screen:120`、`menstrual_screen:194`。

## 6. 收尾

- [ ] 6.1 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠(**既有測試未經修改**)+ `TZ=UTC flutter test` 複驗。確認削減行數約 200。
