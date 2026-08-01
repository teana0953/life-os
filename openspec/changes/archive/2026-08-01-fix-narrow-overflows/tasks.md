# Tasks

> 每處動手前**先讀原始碼並實測**當前狀況。design 的表格是 proposal review 逐格實測的結果(行號當時已驗證),但仍以你動手當下的實測為準。修法依實測決定,不照抄方向猜測。
> **驗收判準是「零 layout exception」不是「零 RenderFlex overflow」**——#2b 正是非 RenderFlex 的 `ListTile` assert。

## 1. menstrual-legend Row(最大宗:320/en 60px、360/en 20px)

- [x] 1.1 實測確認當前溢出量與成因,修到 {320,360} × {en,zh} × textScale {1.0,2.0} 零溢出。優先 `Wrap` 或可收縮子項,不截字。
- [x] 1.2 該畫面既有窄寬度測試中的 `takeException()` 改硬斷言零 exception。

## 2. networth 兩處(**是兩個獨立問題,別混為一談**)

- [x] 2.1 `networth_tab.dart:370` 科目小計 Row:320/en 15px(ts 1.0)。
- [x] 2.2 `networth_tab.dart:325-345` 科目 `ListTile`:ts 2.0 時 20 個 exception(320 與 360/en 都有),**非 RenderFlex**——是 trailing 寬度爆掉 + `_RenderListTile` 沒 layout 的 assert;此時 `find.byKey().evaluate()` 自己丟 `_TypeError`。修好後該情境要能正常查詢。
- [x] 2.3 對應測試改硬斷言。

## 3. health_calendar_card 兩處

- [x] 3.1 `:148` 三 ring Row:320/en 12px。**不要用 `Wrap`**(320dp 會變 2+1 不對稱);撐寬的是 `:355` 沒受限的標籤 `Text`,正解是每個 ring 包 `Expanded` + 標籤置中換行。測試需帶 `padding: EdgeInsets.all(20)` 否則測不到。
- [x] 3.2 `:280` 月份圓點日格:ts 2.0 時 **31 個垂直溢出**(en/zh 四種組合都中)。方向:日格高度需隨字級增長(彈性高度或內容可縮),不可寫死。
- [x] 3.3 對應測試改硬斷言。

## 4. diet 對話框橫向(640×360,ts1.0 140px / ts2.0 176px)

- [x] 4.1 實測後修(內容可捲動或限制高度)。直向 320/360 在 1.0/2.0 皆乾淨。
- [x] 4.2 補橫向版面測試。

## 4b. category_progress_bar(**proposal review 發現的第五處**)

- [x] 4b.1 `category_progress_bar.dart:42`:ts 2.0 時 320/en 4 個溢出(59/2.5/31/144px)、360/en 2 個(19/104px)。**共用元件**,修改需在所有宿主畫面驗證(今日畫面也用)。
- [x] 4b.2 `diet_day_screen_test.dart:550` 目前吞掉它,且該行註解誤記成「對話框裡的 day grid」(對話框實測乾淨)——改硬斷言並更正註解。
- [x] 4b.3 真實宿主是 `today_screen.dart:272-296`、`daily_target_screen.dart:174-207`(diet day 經 today):兩者都補上 {320,360} × {en,zh} × ts{1.0,2.0} 守門(`daily_target_screen` 先前完全沒有)。另補右對齊守門:尾端數值收縮後仍須貼齊右緣(鬆散 `Flexible` 會 shrink-wrap 把餘裕留在後面,愈寬飄愈遠)。
- [x] 4b.4 兩半都用 flex 子項的話,每半被限在**該列的一半**,標籤在放得下時照樣換行(`Total liabilities` 390dp 3 行、430dp 2 行)。改用共用的 `LabelValueRow`(標籤是受列寬限制的一般子項、數值 `Expanded` 靠右),並補「正常寬度不換行」守門(390/430/600/800dp 量 `RenderParagraph` 行數)。

## 5. 守門機制

- [x] 5.1 抽一個共用的版面守門 helper(收集**全部** `FlutterError` 而非只取第一個),放 `test/support/`,各處共用。**兩個實測踩過的陷阱**:(a) 必須**先還原 `FlutterError.onError` 再斷言**,否則 `binding.dart:1019` 的 assert 會蓋掉真正的錯誤;(b) onError callback 內部若丟例外,test run 會**無限卡住且沒有紅字**(本專案「測試卡死≠通過」累犯)。binding 自己會在 postTest 還原,不會汙染其他測試。
- [x] 5.2 改動範圍 = **8 處 / 5 檔 / 約 36 個測試案例**,逐一處理並記錄:`menstrual_screen_test.dart:508,561`、`health_calendar_card_test.dart:375,419,454`、`networth_tab_test.dart:423`、`finance_overview_tab_test.dart:392`、`diet_day_screen_test.dart:550`。其中兩個特例:`finance_overview_tab_test.dart:392` 不在溢出清單、實測全格 0 exception(**死 drain,註解也錯**)→ 直接移除;`health_calendar_card_test.dart:454` 是 280dp(在宣告的 320/360 範圍外)→ 判斷後處理。
- [x] 5.3 spec 第二條的守門要求**只涵蓋本 change 觸及的測試**,不得擴及既有約 45 處 `expect(takeException(), isNull)`(含 login/home responsive 等)——那些不在範圍內。

## 6. 收尾

- [x] 6.1 七項在 {320,360} × {en,zh} × ts{1.0,2.0} 皆**零 layout exception**;`bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
- [x] 6.2 **mutation 驗證**:在任一受守畫面人為加一個溢出 → 守門測試應變紅(證明不再是假守門)。

## Follow-up(本 change 不修,已記錄於 `label_value_row.dart` dartdoc)

`LabelValueRow` 的 65% 是**固定**的,兩半明明放得下時照樣切:320dp/2x + 短中文標籤(`現金` 56.5dp + `1234567` 197.8dp = 266.3dp,可用列寬 288dp 本可各一行)時,值被壓成 2 行、標籤盒子空著 40.1dp。英文標籤夠長所以不會中,這是第六次「該換行的沒換 / 不該換的換了」鏡射。乾淨修法要問標籤的 intrinsic 寬度,而這正是這個 widget 因宿主約束**刻意不能做**的事,所以接受現狀可能才是對的。
**它為何拖到第六輪才被發現**:守門只掃**標籤側**(「放得下就不換行」),沒有對稱的「有空間時**值**不換行」守門。要再動這個 fraction 的話,先補上那一側的守門。
