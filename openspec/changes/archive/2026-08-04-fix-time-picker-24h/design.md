# 時間選擇一律 24 小時制 — 設計

## 問題

四個時間選擇點**存 24 小時制、顯示 24 小時制,但讓 picker 跟著語系走**:

- `vitals_screen.dart` 三處(血壓/血糖/血氧的時間):存的是 `_zeroPad(picked)`,那是**嚴格 ASCII 的 `HH:mm`**(註解寫明刻意不用 `formatTimeOfDay`,免得本地化數字/分隔符弄壞給後端的線上格式);`_TimeChip` 把它**原樣**顯示(`time.isEmpty ? '--:--' : time`)。
- `today_screen.dart` 的餐點時間:顯示走 `DateFormat('HH:mm')`(:407),永遠是 24 小時制。

所以英文語系(12 小時制)的使用者在 picker 裡選「9:30 PM」,回到畫面看到的是「21:30」。他沒有輸入錯,是我們把他的輸入換了一種寫法給他看,而且沒有任何錯誤或提示。

**這個 bug 在這個 repo 已經修過兩次**:`care_item_form.dart`(兩處)與 `care_today_screen.dart`(一處)都強制 `alwaysUse24HourFormat: true`,而且註解把後果寫得跟上面一模一樣——「a 12-hour picker would have an English-locale user choose "9:30 PM" and then read it back as "21:30"」。修法被複製成三份,`lib/shared/` 底下沒有任何共用的時間 helper。

## 做法

新增 `lib/shared/date/pick_time_24h.dart`:

```dart
Future<TimeOfDay?> pickTime24h(BuildContext context, {required TimeOfDay initialTime})
```

包住 `showTimePicker`,固定帶那個把 `alwaysUse24HourFormat` 設為 true 的 `builder`。**七個呼叫點全部改用它**——不是只修有 bug 的四個。理由:留兩份自己寫的 `MediaQuery` builder,下一個人照著複製時仍會漏掉;而且既有那三處的行為完全不變,改動是零風險的。

**這是行為修正,不是重構**:vitals 與 today 的 picker 在 12 小時制語系下會從此顯示 24 小時制輪盤。這正是要的結果——因為那兩處的**顯示**本來就是 24 小時制。

## 決策要點

**D1 helper 放 `lib/shared/date/`,不放 widgets。** 它不是 widget,是一次互動;跟 `day_format.dart` 同一個資料夾,那裡已經是日期/時間格式的既有落點。

**D2 不改任何顯示格式(往 12 小時制走)。** 這一期只讓輸入跟輸出一致。「要不要跟著語系顯示 12 小時制」是另一個問題,不在範圍內。

理由是**範圍**,不是技術上做不到:顯示與線上格式其實是可以分開的——`care_today_screen` 就已經把後端字串 parse 回 `DateTime` 再用 `DateFormat` 自己格式化,顯示層換成跟語系走並不會動到 `_zeroPad` 產出的那個嚴格 ASCII `HH:mm`。(先前這裡寫「會牽動存進後端的線上格式」,那句是錯的,已更正。)真正成立的理由有兩個:一是範圍,二是**全 app 每一個使用者看得到的時間目前都是 24 小時制**,所以維持 24 小時制才是一致的那一邊——見下面 `last_loaded_label` 那一段。

**D3 不動 `_zeroPad`。** 兩份重複(`vitals_screen.dart:983`、`care_item_form.dart:53`)看起來也該抽,但它們是**格式化**、不是**互動**,而且動它會碰到給後端的線上格式。記為 follow-up,不在這一期。

**D4 helper 要能被測試替換嗎?不用。** **只有 `today_screen`** 把整個「挑時間」注入成參數(`pickMealTime`);`care_today_screen` 沒有那道注入,`vitals_screen` 與 `care_item_form` 也是直接呼叫。而 `today_screen_test.dart:301` **寫死了那個 fake**,所以要驗真的預設實作,得先讓它能被要求「不要注入」(例如接受 `pickMealTime: null` 走預設)。這一期不改注入結構——改了會擴大到那四個畫面的建構子與所有既有測試,而收穫只是「能不能單獨測 helper」。**helper 本身用 widget test 驗**:pump 一個 12 小時制語系的畫面、開啟 picker、斷言渲染出來的是 24 小時制輪盤。

## 測試

- **helper 的 widget test**:在 `alwaysUse24HourFormat: false` 的 `MediaQuery` 底下呼叫 `pickTime24h`,斷言彈出的 `TimePickerDialog` 底下 `MediaQuery.of(context).alwaysUse24HourFormat` 是 true。**這條要做突變測試**——把 builder 拿掉必須紅,否則它就是一條測不到東西的守門。
- **四個 bug 點各一條**:**明確指定 `Locale('en')`**(不要靠測試環境的預設),打開 picker,斷言 `TimePickerDialog` **確實存在**、且沒有 AM/PM 切換——只斷言「找不到 AM/PM」在 dialog 根本沒開的時候也會過。**每一條都要突變驗證**。
- 既有的 care 三處測試不得破。

## `last_loaded_label` 也改成 24 小時制

`last_loaded_label.dart:26` 原本**跟著語系的 12/24 設定走**。一開始把它排除在外,理由是「那是載入時間,不是使用者輸入的值,沒有輸入輸出不一致的問題」。

**這個排除理由後來被推翻了。** 判準不該是「是不是使用者輸入的」,而是**使用者在同一個畫面上看到幾種時間寫法**:這個標籤就長在 vitals 與 diet Today(`health_scaffold`)的最上面,英文語系使用者會同時看到上面「Updated 9:30 PM」與下面讀數 chip「21:30」。這正是這一期要消滅的那種困惑,只是換了個位置。

所以改成 `DateFormat('HH:mm')`,跟 app 裡其他每一處使用者看得到的時間一致(`vitals_screen.dart:905`、`today_screen.dart:408`、`care_today_screen.dart:156`/`:1110`、`friends_screen.dart:536`)。這是**一行**加上註解與一條測試,沒有線上格式或譯文風險。

## 不做

- 不改顯示格式(D2)、不抽 `_zeroPad`(D3)、不改注入結構(D4)。
