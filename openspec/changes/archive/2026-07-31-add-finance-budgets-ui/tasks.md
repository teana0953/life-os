# Tasks

## 1. Domain + infrastructure

- [x] 1.1 `domain/`:`FinanceBudget` 實體(id、categoryId?、amount、spent、remaining、percent);`FinanceRepository` port 加 `listBudgets(month)`/`upsertBudget(categoryId?, amount)`/`deleteBudget(id)`。
- [x] 1.2 `HttpFinanceRepository` 三方法(契約照 design.md;status→typed exception 照既有映射)。測試:mock client、body 形狀、401/404/400。

## 2. Controller(重要邏輯,測試必須覆蓋)

- [x] 2.1 `FinanceController`:`budgets` 狀態併入 `load(month)` 同批抓取(沿用月份 gate——同月才落地);`saveBudgets` 逐筆循序批次(改→upsert、清空既有→delete、未動不發);**部分失敗:立即 reload、回報失敗、diff 基準重算(重試不重送已成功筆)**;切月同步清 budgets(比照 summary)。測試:競態(舊月 budgets 不落地)、切月清除、diff 各分支、部分失敗重試不重送、typed error。

## 3. Presentation

- [x] 3.1 警示色 helper(app_theme.dart,honey/amber 系,light/dark AA,照 financeIncomeColor 先例)。
- [x] 3.2 `BudgetCard`(總覽 tab,月摘要卡下):列(名稱、`spent / amount` TWD 格式、文字百分比、fractional_progress_bar);<80 正常 / ≥80 警示 / ≥100 error+超支標籤;空狀態引導+CTA;`Key('budget-card')`/`Key('budget-edit-button')`。
- [x] 3.3 `BudgetSheet`:isScrollControlled+viewInsets padding;總額列+未 archived expense 分類列(含未設);archived 且有預算者列出、標示封存、只能清空,金額欄 empty-zero(空=未設)、數字鍵盤;標題下「預算為每月循環設定」說明;儲存中 disabled+進度;失敗 snackbar+保留;`Key('budget-sheet-save')`、每列 `Key('budget-field-…')`。
- [x] 3.4 widget tests:三段色邊界(percent 79/80/100,判定用後端整數 percent)、超支標籤、空狀態 CTA 開 sheet、批次 diff(1 upsert+1 delete)、部分失敗(reload+保留+重試不重送)、l10nTestApp。

## 4. i18n + 收尾

- [x] 4.1 ARB 三檔(en 含 description、zh_Hant、zh)+ `flutter gen-l10n`,generated commit。
- [x] 4.2 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠(`All tests passed!`);`TZ=UTC flutter test` 複驗。
