# 窄螢幕版面溢出(既有)— 設計

## 背景

`add-month-picker`(PR #116)那輪補上本專案第一批手機寬度版面測試({320,360}dp × {en,zh} × textScaler)後,暴露出**四個 main 上早就存在的 RenderFlex 溢出**。三個 review/QA agent 各自開 main 的隔離 worktree 對照量測,數字一致,確認與該輪改動無關。

使用者已指示要修。

## 七項版面失敗(皆已逐格實測)

| # | 位置 | ts 1.0 | ts 2.0 | 備註 |
|---|---|---|---|---|
| 1 | `menstrual_calendar.dart:216` legend Row | 320/en **60px**、360/en **20px** | 320/en 300px、360/en 260px | zh 兩種寬度都乾淨 |
| 2 | `networth_tab.dart:370` 科目小計 Row | 320/en **15px** | — | 見下方「networth 的 2.0 是另一回事」 |
| 2b | `networth_tab.dart:325-345` 科目 `ListTile` | — | **20 個 exception**(320 與 360/en 都有) | 非 RenderFlex:trailing 寬度爆掉 + `_RenderListTile` 沒 layout 的 assert;此時 `find.byKey().evaluate()` 自己丟 `_TypeError` |
| 3 | `health_calendar_card.dart:148` 三 ring Row | 320/en **12px**(必須帶 `padding: all(20)` 才測得到) | 320/en 252px、360/en 212px、**320/zh 32px**(zh 在 2.0 也會炸) | |
| 3b | `health_calendar_card.dart:280` 月份圓點日格 | — | **31 個垂直溢出**(en/zh 皆有,四種組合都中) | 初版漏列;修法方向:日格高度需隨字級增長(給格子彈性高度或讓內容可縮),不可寫死 |
| 4 | `diet_day_screen.dart:344` 對話框橫向 640×360 | **140px 垂直**(en/zh 相同) | 176px | 直向 320/360 在 1.0/2.0 皆乾淨 |
| 5 | `category_progress_bar.dart:42` | — | 320/en **4 個(59/2.5/31/144px)**、360/en 2 個(19/104px) | **初版完全漏掉**;共用元件,今日畫面也用;正被 `diet_day_screen_test.dart:550` 吞掉,而該行註解誤記成「對話框裡的 day grid」(對話框實測乾淨) |

以上為 proposal review 逐格實測(收集全部 FlutterError 而非只取第一個)的結果,已取代初版憑三個 agent 回報彙整的表格。初版的 ts 1.0 數字全部吻合,錯在 ts 2.0 的歸因與遺漏。

### networth 的 2.0 是另一回事

初版把「textScale 2.0 時放大成 20 個 exception」歸給小計 Row(#2),**實測不成立**:2.0 時完全沒有 RenderFlex 溢出,那 20 個是 `ListTile` 的問題(#2b),且 360/en 也會炸(初版只寫 320)。**修 #2 不會讓 #2b 變好**,兩者要分開處理。

## 為何值得修(不只是黃黑條紋)

1. 使用者實際會看到破版(320dp 手機、或英文介面、或放大字級)。
2. **測試被迫用 `takeException()` 吞掉它們**——那是鈍器:Flutter test binding 只保留第一個 exception,所以這些頁面**再長出新的溢出也看不見**。修掉之後,窄寬度測試才能改成硬斷言「零 exception」,守門才真的成立。

## 修法方向(各處待實作時依實測決定,不預先綁死)

共同原則:**讓會撐寬的子項可收縮**(`Flexible`/`Expanded` + 適當的 overflow 策略),或在窄寬度改變排列方式(Row → Wrap/Column)。優先選「內容完整可讀」而非截字——與 `ShrinkToFitText` 那輪的結論一致。

- **legend**:窄寬度改 `Wrap` 或可收縮子項。
- **ring 那列不要用 `Wrap`**(review 指出):三項在 320dp 會變 2+1 不對稱兩列;而且撐寬的不是 ring 本身(非固定寬度),是 `health_calendar_card.dart:355` 那個沒受限的標籤 `Text` —— 正解是每個 ring 包 `Expanded` + 標籤置中換行。
- **科目小計 Row**:名稱可收縮 + 金額固定,或名稱用 `ShrinkToFitText`。
- **diet 對話框橫向垂直溢出**:內容需可捲動(`SingleChildScrollView`)或限制高度。**注意這不是唯一的垂直溢出**(#3b 月份圓點日格也是垂直)。
- **#2b `ListTile`**:trailing 在大字級下需可收縮或改版面(非 RenderFlex,是 `ListTile` 自身的 layout 限制)。
- **#5 `category_progress_bar`**:共用元件,修它會影響所有用到的畫面——改動需在多個宿主畫面驗證。

## 範圍

- 修上述**七項**(#1、#2、#2b、#3、#3b、#4、#5)。
- **修完必須把對應測試從 `takeException()` 改成硬斷言零 exception**——這是本 change 的驗收重點之一,否則守門仍是假的。
- 範圍外:`dialogTheme` 收斂(9 個 AlertDialog 的 insetPadding 不一致)、月份標籤觸控區 37–38dp——兩者已在 backlog,與溢出無關。

## 測試

- 七項各補 {320,360}dp × {en,zh} × textScale {1.0, 2.0} 的版面測試,**硬斷言零 layout exception**(不限 RenderFlex——helper 不可只濾 RenderFlex,#2b 是 `ListTile` 的 assert;不用 `takeException()` 排除)。
- 收集**全部** FlutterError 而非只取第一個(binding 只留第一個,`takeException()` 看不到後續)——照 QA 那輪用 `FlutterError.onError` 覆寫收集的做法。
- 既有測試零改動;既有那些用 `takeException()` 排除溢出的測試,改成硬斷言(這算修既有測試,但屬本 change 的驗收目標,需明確記錄改了哪幾支、為何)。

## 驗收

七項在 {320,360}dp × {en,zh} × textScale {1.0,2.0} 皆**零 layout exception**(不限 RenderFlex——#2b 正是非 RenderFlex 的 `ListTile` assert,寫死 RenderFlex 會讓它不修也過驗收);相關測試不再需要 `takeException()`;`flutter analyze` 0 issue、`flutter test` 全綠、`TZ=UTC` 複驗。
