# Tasks

## 1. Domain + infrastructure

- [x] 1.1 `lib/contexts/finance/domain/`:實體(`FinanceTransaction`/`FinanceCategory`/`MonthlySummary`)、`FinanceRepository` port、typed exceptions(照 diet_exceptions 慣例)、幣別小數位映射+金額格式化/解析(`{TWD:0,JPY:0,KRW:0,其餘:2}`)。測試:格式化/解析各幣別+非法輸入。
- [x] 1.2 `domain/finance_month.dart`:`YYYY-MM` 純字串月份工具(上/下月、月初/月底、當月)。測試:跨年、月底天數(含閏年)。
- [x] 1.3 `infrastructure/http_finance_repository.dart`:照 http_water_repository 模式接 `/api/finance/*`(契約見 design.md;POST/PUT 帶 Content-Type: application/json)。測試:mock http.Client——status→typed exception 映射、body 形狀。

## 2. Controller(重要邏輯,測試必須覆蓋)

- [ ] 2.1 `presentation/finance_controller.dart`:selectedMonth 狀態、`load(month)`(categories+summary+月 transactions;**回應 month == 當前 selectedMonth 才落地**)、auth 組線(idToken;401→`needsReauth` 狀態)、add/update 成功後 **reload 該筆 date 所在月(跨月則 selectedMonth 跳過去)**、delete 後 reload 當前月、typed error、首個 await 前不 notify。測試:狀態轉換、切月競態(舊回應不覆蓋)、跨月寫入跳月、401→needsReauth、寫入後 reload。

## 3. Presentation

- [ ] 3.1 `FinanceScaffold`:底部 nav 兩格(總覽/明細),tab 內部狀態,FAB 開記一筆 sheet,照 HealthScaffold 慣例。
- [ ] 3.2 `FinanceOverviewTab`:月份 ‹ › 列、支出/收入/結餘卡按幣別分行(收入色用 app_theme 新增的 `financeIncomeColor` helper、支出用 colorScheme.error)、分類統計用 `fractional_progress_bar` 橫條列(每分類 icon+名+金額+比例,依金額排序、幣別分組;不用 fl_chart)、最近 5 筆、空狀態(引導+CTA 開 sheet)、loading/reauth 走 async_state_scaffold、error+retry 在 builder 自建(照 health tab 現行做法)。分類 icon 映射以 name 為 key、fallback icon 欄→泛用 icon。
- [ ] 3.3 `FinanceTransactionsTab`:按日分組倒序、row(分類 icon+name、note、帶號金額)、點 row 開編輯 sheet。
- [ ] 3.4 `AddTransactionSheet`(記一筆+編輯同一 sheet):`showModalBottomSheet(isScrollControlled:true)` + viewInsets bottom padding(照 exercise_screen.dart:385);金額數字鍵盤 empty-zero 慣例、支出/收入 segmented(換分類 grid)、分類 grid、日期預設今天、幣別下拉預設 TWD、note;存檔鈕 gate(金額>0 且有分類);編輯模式帶現值+刪除(confirm);失敗 snackbar+內容保留。互動元件加 Key(`finance-fab`/`amount-field`/`save-transaction-button` 等)。
- [ ] 3.5 widget tests:表單 gate(空→disabled)、送出呼叫 use case、失敗保留內容、明細分組、總覽卡數字與幣別分行、空狀態 CTA、l10nTestApp 包裝。

## 4. 入口 + 路由 + i18n

- [ ] 4.1 ARB 三檔(en 含 description、zh_Hant、zh 同步)+ `flutter gen-l10n`,generated commit。分類 name 直接顯示後端值,不進 ARB。
- [ ] 4.2 `home_screen.dart` 把既有財務 placeholder tile(index 1)變可點:InkWell + `Key('finance-tile')` + push `/finance`(照 index 0 health-tile 現行寫法);`app.dart` 加 `/finance` GoRoute + theme helper `financeIncomeColor`(app_theme.dart,light/dark AA 安全);`main.dart` DI 組線。測試:tile 可點+導航。
- [ ] 4.3 既有測試回歸:home_screen 測試預期不破(不是新增一格);跑全套確認。

## 5. 收尾

- [ ] 5.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠(看到 `All tests passed!`);`TZ=UTC flutter test` 複驗。
