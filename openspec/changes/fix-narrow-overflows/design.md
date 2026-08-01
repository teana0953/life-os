# 窄螢幕版面溢出(既有)— 設計

## 背景

`add-month-picker`(PR #116)那輪補上本專案第一批手機寬度版面測試({320,360}dp × {en,zh} × textScaler)後,暴露出**四個 main 上早就存在的 RenderFlex 溢出**。三個 review/QA agent 各自開 main 的隔離 worktree 對照量測,數字一致,確認與該輪改動無關。

使用者已指示要修。

## 四處溢出(皆已實測)

| 位置 | 溢出量 | 備註 |
|---|---|---|
| `menstrual_screen` 的 `menstrual-legend` Row | 320/en **60px**、360/en **20px** | zh 乾淨。360dp 是 Android 主流寬度 |
| `networth_tab.dart` 科目小計 Row | 320/en **15px** | textScale 2.0 時放大成 **20 個 layout exception**,且 viewport 壞到 `find.byKey().evaluate()` 自己會 crash |
| `health_calendar_card` 三個 ring 的 `spaceEvenly` Row | 320/en **12px** | 補上正式環境 `padding: 20` 後才浮現 |
| diet 月曆對話框 | 橫向 640×360 **垂直溢出 140px** | 唯一的垂直溢出 |

## 為何值得修(不只是黃黑條紋)

1. 使用者實際會看到破版(320dp 手機、或英文介面、或放大字級)。
2. **測試被迫用 `takeException()` 吞掉它們**——那是鈍器:Flutter test binding 只保留第一個 exception,所以這些頁面**再長出新的溢出也看不見**。修掉之後,窄寬度測試才能改成硬斷言「零 exception」,守門才真的成立。

## 修法方向(各處待實作時依實測決定,不預先綁死)

共同原則:**讓會撐寬的子項可收縮**(`Flexible`/`Expanded` + 適當的 overflow 策略),或在窄寬度改變排列方式(Row → Wrap/Column)。優先選「內容完整可讀」而非截字——與 `ShrinkToFitText` 那輪的結論一致。

- **legend / ring 這類「多個並排的小項目」**:窄寬度改 `Wrap` 通常比壓縮每一項好。
- **科目小計 Row**:名稱可收縮 + 金額固定,或名稱用 `ShrinkToFitText`。
- **diet 對話框橫向垂直溢出**:內容需可捲動(`SingleChildScrollView`)或限制高度。

## 範圍

- 只修上述四處的溢出。
- **修完必須把對應測試從 `takeException()` 改成硬斷言零 exception**——這是本 change 的驗收重點之一,否則守門仍是假的。
- 範圍外:`dialogTheme` 收斂(9 個 AlertDialog 的 insetPadding 不一致)、月份標籤觸控區 37–38dp——兩者已在 backlog,與溢出無關。

## 測試

- 四處各補 {320,360}dp × {en,zh} × textScale {1.0, 2.0} 的版面測試,**硬斷言零 RenderFlex exception**(不用 `takeException()` 排除)。
- 收集**全部** FlutterError 而非只取第一個(binding 只留第一個,`takeException()` 看不到後續)——照 QA 那輪用 `FlutterError.onError` 覆寫收集的做法。
- 既有測試零改動;既有那些用 `takeException()` 排除溢出的測試,改成硬斷言(這算修既有測試,但屬本 change 的驗收目標,需明確記錄改了哪幾支、為何)。

## 驗收

四處在 {320,360}dp × {en,zh} × textScale {1.0,2.0} 皆零 RenderFlex exception;相關測試不再需要 `takeException()`;`flutter analyze` 0 issue、`flutter test` 全綠、`TZ=UTC` 複驗。
