## Why

四個時間選擇點**存 24 小時制、顯示 24 小時制,卻讓 picker 跟著語系走**:`vitals_screen` 的血壓/血糖/血氧三處(`_zeroPad` 存嚴格 ASCII `HH:mm`,`_TimeChip` 原樣顯示),以及 `today_screen` 的餐點時間(顯示走 `DateFormat('HH:mm')`)。

英文語系(12 小時制)的使用者選「9:30 PM」,回到畫面看到「21:30」——他沒輸入錯,是我們把他的輸入換一種寫法給他看,而且沒有任何提示。

**這個 bug 在這個 repo 已經修過兩次**:`care_item_form.dart`(兩處)與 `care_today_screen.dart`(一處)都強制 `alwaysUse24HourFormat: true`,註解把後果寫得跟上面一字不差。修法被複製成三份,`lib/shared/` 底下沒有共用的時間 helper——所以第三個畫面照樣踩。

## What Changes

- 新增 `lib/shared/date/pick_time_24h.dart`:`pickTime24h(context, initialTime:)`,包住 `showTimePicker` 並固定帶上 `alwaysUse24HourFormat: true` 的 builder。
- **七個呼叫點全部改用它**(vitals 三、today 一、care_item_form 二、care_today 一),不是只修有 bug 的四個——留兩份手寫的 builder,下一個人照著複製時仍會漏。既有那三處行為完全不變。

**這是行為修正,不是重構**:vitals 與 today 的 picker 在 12 小時制語系下會改成 24 小時制輪盤,因為那兩處的顯示本來就是 24 小時制。

範圍外:顯示格式不動(要不要跟語系顯示 12 小時制是另一個問題,而且會牽動 vitals 給後端的線上格式);`_zeroPad` 的兩份重複不抽(那是格式化不是互動,且同樣碰到線上格式);不改那四個畫面的注入結構。

## Capabilities

### Modified Capabilities

- `vitals`:讀數的時間控制一律 24 小時制。
- `health-diet`:餐點時間的控制一律 24 小時制。

## Impact

- 新增 `lib/shared/date/pick_time_24h.dart` 與其測試。
- 修改 `vitals_screen.dart`(3 處)、`today_screen.dart`(1 處)、`care_today_screen.dart`(1 處)、`care_item_form.dart`(2 處)。
- 既有 care 三處的行為不變,其測試不得破。
