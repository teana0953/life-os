# Tasks

- [ ] 1 `lib/shared/date/pick_time_24h.dart`:`pickTime24h(BuildContext, {required TimeOfDay initialTime})`,包住 `showTimePicker` 固定帶 `alwaysUse24HourFormat: true` 的 builder;doc comment 寫明**為什麼**(存與顯示都是 24 小時制,picker 跟語系走會讓使用者選 9:30 PM 卻讀回 21:30),並指出這個 bug 在 care 那邊已經獨立修過兩次
- [ ] 2 **helper 的 widget test**:在 `alwaysUse24HourFormat: false` 的 `MediaQuery` 底下呼叫,斷言彈出的 picker 底下該旗標是 true。**要做突變測試**——把 builder 拿掉必須紅,否則這條守門測不到東西
- [ ] 3 `vitals_screen.dart` 三處改用 helper(血壓/血糖/血氧)
- [ ] 4 `today_screen.dart` 的 `_defaultPickMealTime` 改用 helper
- [ ] 5 `care_today_screen.dart` 與 `care_item_form.dart` 共三處改用 helper——**行為不變**,但不留手寫 builder 給下一個人複製
- [ ] 6 四個 bug 點各一條測試:**明確指定 `Locale('en')`**(不要靠環境預設),打開 picker,斷言 `TimePickerDialog` **確實存在**且沒有 AM/PM 切換——只斷言「找不到 AM/PM」在 dialog 沒開時也會過
- [ ] 6b **只有 `today_screen` 把「挑時間」注入成參數**(`pickMealTime`),而 `today_screen_test.dart:301` **寫死了那個 fake**;要驗真的預設實作,得先讓它能被要求走預設(例如接受 `pickMealTime: null`)。`care_today_screen` 沒有這道注入,直接測即可
- [ ] 6c **每一條都要突變驗證**:拿掉該處的 helper 呼叫(改回裸 `showTimePicker`)必須讓對應那條紅
- [ ] 7 既有 care 三處的測試不得破(`care_today_screen_test.dart:1827-1858` 已經在守這件事);`_zeroPad` 不動(follow-up);`last_loaded_label.dart` 不動(它顯示的是載入時間、不是使用者輸入,沒有輸入輸出不一致)
- [ ] 8 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test`、`TZ=UTC flutter test` 全綠
