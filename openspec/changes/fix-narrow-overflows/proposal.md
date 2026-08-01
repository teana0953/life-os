## Why

`add-month-picker`(PR #116)補上本專案第一批手機寬度版面測試後,暴露出四個 **main 上早就存在**的 RenderFlex 溢出(三個 agent 各自開 main 隔離 worktree 對照,數字一致)。使用者已指示要修。

兩個理由:(1) 使用者在 320dp 手機、英文介面或放大字級下會實際看到破版;(2) 目前窄寬度測試被迫用 `takeException()` 吞掉它們,而 Flutter test binding 只保留第一個 exception——**這些頁面再長出新溢出也看不見**,守門是假的。

## What Changes

修四處溢出:

- `menstrual_screen` 的 `menstrual-legend` Row(320/en 60px、360/en 20px)
- `networth_tab` 科目小計 Row(320/en 15px;textScale 2.0 時放大成 20 個 exception 並讓 viewport 壞到無法查詢)
- `health_calendar_card` 三個 ring 的 `spaceEvenly` Row(320/en 12px)
- diet 月曆對話框橫向 640×360 垂直溢出 140px

原則:讓會撐寬的子項可收縮,或窄寬度改變排列(Row → Wrap/Column);優先內容完整可讀而非截字。

**並把對應測試從 `takeException()` 改成硬斷言零 exception**——這是驗收重點,否則守門仍假。

範圍外:`dialogTheme` 收斂、月份標籤觸控區 37–38dp(已在 backlog,與溢出無關)。

## Capabilities

### Modified Capabilities

- `design-system`:窄螢幕(320/360dp)與放大字級下,各畫面不得出現版面溢出;相關版面以硬斷言守門。

## Impact

- `menstrual_screen.dart` / `networth_tab.dart` / `health_calendar_card.dart` / `diet_day_screen.dart` 各一段 Row 的排列方式。
- 既有窄寬度測試中用 `takeException()` 排除溢出的部分改為硬斷言(需逐一記錄)。
- 無行為變更,純版面。
