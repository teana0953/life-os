# 大跨度時間選擇(issue #114)— 設計

使用者回報(issue #114「健康或是財務裡的時間選擇,如果跨度大會不方便」):**目前只能一個月一個月跳,如果想看去年或前年的會很不方便。**

## 現況掃描

| 位置 | 現況 | 跨年體驗 |
|---|---|---|
| 財務 總覽/淨值 月份列(`MonthNavHeader`) | **只有 ‹ ›** | ✗ 回去年要點 12 次 |
| diet 月曆(`diet_day_screen.dart:327/341`) | **只有 ‹ ›** | ✗ 同上 |
| **月經月曆導覽**(`menstrual_calendar.dart:95-118`) | **只有 ‹ ›**,標題純 Text | ✗ 同上 |
| **健康記錄月曆卡**(`health_calendar_card` + `health_calendar_controller.load()`) | **寫死當月**(`now.year/now.month`),連前後月都不能切 | ✗✗ 完全看不到歷史 |
| 簡易 tracker(水/血壓/排便/運動) | 📅 開 `showDatePicker`(firstDate 2020,四者共用 `TrackerDayScreen.openDefaultCalendar`,無人覆寫) | ✓ 可跳年 |
| 月經**起訖日欄**(`_PeriodDialog`) | `showDatePicker`(firstDate 2000) | ✓(與上一列的月曆導覽是兩回事) |
| 記帳日期欄 | `showDatePicker`(2000–2100) | ✓ |

痛點分兩類:
- **只有前後箭頭、沒有跳轉入口**:財務月份列、diet 月曆、月經月曆。
- **完全不能切月**:健康記錄月曆卡(使用者回報「現在只能看本月無法看歷史」)。

(初版掃描把「月經起訖日欄的 showDatePicker」誤當成月經月曆已可跳年——proposal review 查核後更正。)

## 修法

新增共用 **`MonthPickerDialog`**(`lib/shared/widgets/month_picker_dialog.dart`):年份左右切 + 12 個月份格,一下跳到任意月。使用者已核准此方向(而非 `showDatePicker` 選日取月、或滑動切月)。

- `MonthNavHeader` 的月份標籤變成**可點**(目前是純 Text),點開 `MonthPickerDialog`;新增 `onPickMonth` callback,**可選**(不傳則維持純文字,不破壞既有呼叫端契約)。
  **`<keyPrefix>-label` 的 key 必須留在 `Text` 上**(包一層可點的 wrapper 在外面):既有測試 `networth_tab_test.dart:301` 做 `tester.widget<Text>(byKey(...))`,key 移到 wrapper 會型別轉換失敗。
- 財務兩處(總覽 `finance-month`、淨值 `networth-month`)傳入 `onPickMonth`。
- diet 月曆的月份標籤同樣可點(它不是用 `MonthNavHeader`,是自繪的 `_visibleMonth` 列),接同一個 dialog。**選月後必須走既有的 `_changeMonth` 等價路徑——它會呼叫 `_loadLoggedDays()`**;只更新 `_visibleMonth` 會讓新月份留著舊月份的記錄圓點(靜默錯誤資料)。
- 月經月曆(`menstrual_calendar.dart:95-118`)的月份標題同樣可點,接同一個 dialog(純本地 `_visibleMonth`,無 fetch)。
- **健康記錄月曆卡**:`HealthCalendarController` 加 `selectedMonth` 狀態與 `loadMonth(idToken, year, month)`(後端 `getHealthCalendar` 已收 year/month 參數,不需動後端);卡片加 `MonthNavHeader`(keyPrefix `health-calendar-month`,‹ › + 可點標籤開 picker)。**月份切換要有競態防線**(回應落地前確認仍是當前選中月),照 finance controller 既有寫法——這是本專案累犯。預設仍為當月。

### `MonthPickerDialog` API

```dart
Future<DateTime?> showMonthPicker(
  BuildContext context, {
  required DateTime initialMonth,
  DateTime? firstMonth,      // 可選下限;null = 不限
  DateTime? lastMonth,       // 可選上限;null = 不限
});
```
回傳選中月份的第一天(`DateTime(year, month, 1)`),取消回 `null`。

**版面**:標題列 `‹ 2026 ▾ ›`(年份切換 + 可點開年份清單)+ 4×3 月份格;當前月高亮;超出範圍的月份與年份箭頭 disabled。

**尺寸(uiux review 實測後釘死)**:預設 theme 的按鈕 padding 會把月份格壓到 320dp 寬時只剩 **40dp**、文字換行(en 每格多行、zh 的 10/11/12 月換行使第三列高出 16dp),且低於 48dp 觸控下限。必須:`AlertDialog` 的 `insetPadding` 16 + `contentPadding` 16、月份格改 compact padding + `minimumSize(0, 48)` + `maxLines: 1`。驗收:320/360/390 三種寬度 × en/zh 兩種語系,月份格皆 ≥48dp 高、文字不換行。

**年份也可點開清單**:點年份標籤開一個可捲動的年份清單(範圍 1970–2100 的防呆界內,預設捲到當前年附近),點一下直接到該年。

初版設計以 YAGNI 為由不做,**使用者實際評估後判定「一次跳一格年份不夠」**(回三年前要點 3 次箭頭)——issue #114 的訴求正是「想看去年或前年很不方便」,年份步進本身就是痛點的一部分。年份箭頭保留(近距離微調仍最快)。

## 邊界

- **財務**:`firstMonth`/`lastMonth` 都不設(記帳可記未來、淨值可補過去——已查核後端 `validation.ts:165-171` 只驗 `YYYY-MM` 格式不驗範圍)。
- **理智界**:dialog 內建 1970–2100 的年份範圍(防年份無限步進到 year<=0 產出爛字串),這不是業務邊界,是防呆。
- **diet**:`firstMonth`/`lastMonth` 都不設——**與既有 › 箭頭一致**(現有箭頭對未來月無上界,只 disable 未來的「日」);若 picker 擋未來月而箭頭不擋,會出現「箭頭去得了、picker 選不到」的不對稱。
- **月經**:同 diet,不設邊界(既有箭頭亦無界)。
- dialog 內的年份切換不因未設邊界而無限——UI 上就是箭頭,使用者自己停。

### 月份字串轉換

picker 回 `DateTime`,而財務的月份切換路徑吃 `YYYY-MM` 字串。若把轉換函式加進 `finance_month.dart`,**必須守住該檔的 library 契約**:不讀時鐘、不做 instant 轉換(只做欄位進欄位出),否則會破壞它現有的 TZ 不變式。放哪裡由 apply 決定。

## 範圍外

- 簡易 tracker / 月經起訖日欄 / 記帳日期欄的 `showDatePicker`(已可跳年,不是痛點)。
- `health_calendar_card`(寫死當月,連一格都不能跳)與 care history / care adherence / vitals trend 的 7/30/90 相對區間——這些是「不同的時間選擇模型」,不是逐月跳的痛點,本輪不動;若使用者之後也想要,另案。
- `firstDate: 2020` 等既有邊界值調整(沒人抱怨,YAGNI)。
- 年份清單選擇器、日期範圍選擇。

## UI/UX 設計

### 使用者路徑

- **主路徑**:財務總覽看到「2026年7月 ▾」→ **點標籤** → 月份選擇器 → **點年份「2026 ▾」開清單 → 選 2024** → 點「3月」→ 回到總覽,顯示 2024年3月的資料。原本要點 28 次箭頭;跨越多年時年份清單比年份箭頭更快。
- diet 月曆與月經月曆同理:點月份標題 → 跳任意月。
- 取消/點外面 → 不改變當前月。

### 介面與一致性

- Dialog 走 `AlertDialog`(theme 已定義圓角/outline),月份格用 `Theme` 的 `colorScheme`;當前月用 `primary` 填色,其餘 outline。
- 年份列沿用 `MonthNavHeader` 的 chevron 語彙(視覺一致);年份標籤本身可點開年份清單。
- **可發現性**:四個接入點的月份標籤旁加一個小 `▾`(`Icons.arrow_drop_down`),明示可展開——沒有線索的話使用者不會知道標籤能點(「功能做了沒人發現」)。dialog 內的年份標籤同樣加 `▾`。四處一致。
- 月份文字用 **intl 的 `DateFormat.MMM(locale)`**(不手寫 36 筆 ARB)。注意:`zh-Hant` 在 intl 無獨立 symbols 會退回 `zh`,而 `zh` 的 `MONTHS` 是「三月」、**`SHORTMONTHS` 才是「3月」**——必須用 `MMM`(短名)才符合 app 其他處的月份寫法。對話框標題與年份箭頭 tooltip 仍走 ARB。

### 狀態設計

- 沒有 loading/error(純本地選擇)。
- 超出範圍的月份與年份箭頭 disabled(視覺明示不可選,非靜默無反應)。

### 可及性

- 月份格與年份箭頭都是有 tooltip/semantics label 的按鈕;當前月除了顏色另加語意標記(`selected`)。
- Keys:`month-picker-year-previous/next`、`month-picker-year-label`(可點)、`month-picker-year-<YYYY>`(年份清單項)、`month-picker-month-<1..12>`;月份標籤觸發鍵沿用 `<keyPrefix>-label`(**key 留在 Text 上**,可點的 wrapper 包外層,見上)。

## 測試

- `MonthPickerDialog`:年份切換、**點年份開清單並選年**、選月回傳正確 `DateTime`、取消回 null、first/last 邊界 disabled、當前月高亮、`▾` 線索存在。
- `MonthNavHeader`:`onPickMonth` 為 null 時標籤不可點(既有行為不變);有傳時點擊開 dialog。
- 財務兩處:點標籤開 dialog、選月後畫面切到該月(用既有 controller 的月份 gate,不繞過)。
- diet:點標題開 dialog、選月後月曆切到該月**且重抓該月 loggedDays**。
- 月經:點標題開 dialog、選月後月曆切到該月。
- 迴歸:既有 `finance-month-*` / `networth-month-*` / diet 月曆 / `menstrual-*-month` 測試全綠。
- `TZ=UTC flutter test` 複驗(碰日期)。

## 驗收

財務兩處、diet 月曆、月經月曆都能一步跳到任意年月;既有箭頭行為不變;`flutter analyze` 0 issue、`flutter test` 全綠。
