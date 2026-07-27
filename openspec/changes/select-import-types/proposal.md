## Why

[issue #86](https://github.com/loftapartment/life-os/issues/86)：「可以選擇要匯入哪些資料 —— 匯入太長的時間區間，會被對方的 server 擋住」。

issue 講的是兩件事，落在兩個 repo：

- **本 change（前端）**：讓使用者選要匯哪些類型。現在 `ChaodaysImportController.import` 把五種類型（體重／飲食／飲水／排便／飲食目標）**固定全跑**，想只補匯飲食也得五種全跑一遍。
- **後端另一個 change**：長區間自動分批。切分放後端，因為每個 use case 呼叫都會先 `chaodaysClient.signIn()` —— 在前端分批會讓登入次數變成「批數 × 類型數」（匯三年 = 30 次登入打同一台 server），若對方擋的是速率就會適得其反。後端切則維持每類型登入一次，並串接 `fetch*` 已經回傳的輪替 session。

## What Changes

- **`ChaodaysImportController.import`** 接受要跑的類型集合（`Set<ImportType>`），只跑選中的；未選的維持 `notAttempted`，不算失敗。既有的失敗語意（停在第一個失敗）、`DataRevision` 的「至少一種成功就 bump」規則都不變。
- **`ChaodaysImportScreen`** 讓五個類型各自可勾選，**預設全選**（現有使用者的行為完全不變），全不選時送出停用 —— 「匯入零種資料」不是有意義的操作。
- 選擇 UI 放在既有的 `_TypeResultRow` 上，不另開卡片 —— 否則畫面會出現兩份相同的類型清單。**勾選框的顯示條件是「這次匯入尚未進行中」（`_isImporting`），不是 per-type 狀態**：後者在一輪跑完後五列都停在 `success`，勾選框會整組消失，使用者沒辦法在同一畫面改選再跑一次 —— 而「只補匯某一種」正是這個功能的主要情境。

前端 only；後端與 `ImportRepository` 介面不動。新增選擇相關的 l10n 文案（ARB ×3）。Gate = lint + `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `chaodays-import-ui`: 匯入 SHALL 只跑使用者選中的資料類型（預設全選），而不是固定全跑。
