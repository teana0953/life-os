## Why

預算後端已上(life-os-backend PR #62):可設定、可查進度、超支會推播。但前端沒有任何預算 UI——設不了也看不到。本 change 補上前端,sub-project 2 閉環。

## What Changes

- 總覽 tab 新「預算」卡:總額+已設分類各一列(名稱、spent/amount、進度條;<80 正常、≥80 警示色、≥100 error+超支標籤);零預算時空狀態引導+CTA。
- `BudgetSheet` 設定 bottom sheet:總額+未 archived expense 分類各一金額欄(empty-zero;空=未設;archived 僅在仍有預算時列出、標示封存、只能清空),說明預算為每月循環設定;儲存循序批次 diff(upsert/delete),部分失敗→立即 reload+保留輸入+基準重算(重試不重送已成功筆)。
- `FinanceController.load` 一併抓 budgets(沿用既有月份競態防線,切月同步清除);儲存後 reload。
- `FinanceRepository`/`HttpFinanceRepository` 加 listBudgets/upsertBudget/deleteBudget。
- 警示色 theme helper(honey/amber 系,照 financeIncomeColor 先例);ARB 三檔。

範圍外:淨值、分帳、預算歷史、外幣預算;推播接收端(既有基礎,零改動)。

## Capabilities

### New Capabilities

- `finance-budgets-ui`:預算進度卡(三段色)+ 設定 sheet(批次 upsert/delete)。

### Modified Capabilities

(無——finance-ledger-ui 的既有行為不變,總覽只是多一張卡。)

## Impact

- `lib/contexts/finance/`:domain/infrastructure port+impl 擴充、controller 加 budgets、presentation 新卡+sheet。
- `lib/shared/theme/app_theme.dart`:警示色 helper。
- `lib/l10n/*.arb` + generated。
- 既有畫面:總覽 tab 加卡,其餘零變更。
