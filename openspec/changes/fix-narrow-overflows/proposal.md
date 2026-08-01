## Why

`add-month-picker`(PR #116)補上本專案第一批手機寬度版面測試後,暴露出四個 **main 上早就存在**的 RenderFlex 溢出(三個 agent 各自開 main 隔離 worktree 對照,數字一致)。使用者已指示要修。

兩個理由:(1) 使用者在 320dp 手機、英文介面或放大字級下會實際看到破版;(2) 目前窄寬度測試被迫用 `takeException()` 吞掉它們,而 Flutter test binding 只保留第一個 exception——**這些頁面再長出新溢出也看不見**,守門是假的。

## What Changes

修**七項**(proposal review 逐格實測後更正,初版漏一處、錯兩處歸因):

- `menstrual_calendar.dart:216` legend Row(320/en 60px、360/en 20px)
- `networth_tab.dart:370` 科目小計 Row(320/en 15px)
- `networth_tab.dart:325-345` 科目 `ListTile`(ts 2.0 時 20 個 exception,**非 RenderFlex**,與上一項是獨立問題)
- `health_calendar_card.dart:148` 三 ring Row(320/en 12px)+ `:280` 月份圓點日格(ts 2.0 時 31 個垂直溢出)
- `diet_day_screen.dart:344` 對話框橫向 640×360(垂直 140px)
- `category_progress_bar.dart:42` 共用元件(ts 2.0 時最多 144px)——**初版完全漏掉**

原則:讓會撐寬的子項可收縮,或窄寬度改變排列(Row → Wrap/Column);優先內容完整可讀而非截字。

**並把對應測試從 `takeException()` 改成硬斷言零 exception**——這是驗收重點,否則守門仍假。

範圍外:`dialogTheme` 收斂、月份標籤觸控區 37–38dp(已在 backlog,與溢出無關)。

## Capabilities

### Modified Capabilities

- `design-system`:窄螢幕(320/360dp)與放大字級下,各畫面不得出現版面溢出;相關版面以硬斷言守門。

## Impact

- `menstrual_calendar.dart` / `networth_tab.dart`(兩處)/ `health_calendar_card.dart`(兩處)/ `diet_day_screen.dart` / `category_progress_bar.dart`(共用元件,影響多個宿主畫面)。
- 8 處 / 5 檔 / 約 36 個測試案例的 `takeException()` 改硬斷言(含一處死 drain 直接移除)。
- 無行為變更,純版面。
