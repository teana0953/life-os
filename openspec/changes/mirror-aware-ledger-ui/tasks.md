# Tasks

**這是修一個正在說反話的 app,不是加功能。** 每個守門都要能抓到「畫面講的跟後端做的不一樣」。

## 1. 分帳卡逐幣別分組(D1)—— 最急

- [ ] 1.1 `SplitSpending` 加 `countedInTransactions`(後端逐幣別回)。
- [ ] 1.2 卡片分兩組,句子放在**各自那組的金額旁邊**,不是卡片頂端一句話管全部。
- [ ] 1.3 **舊的 `financeSplitSpendingNote`(「不計入上方的支出總額,也不計入預算」)要刪掉**,不是留著改字 —— 它現在對 TWD 是假的。
- [ ] 1.4 **突變:兩組都用同一句文案**,一條「同月有 TWD(已計入)與 THB(未計入)」的測試必須紅。**fixture 一定要兩種都有** —— 只有一種的話,一句話蓋全部照樣綠。
- [ ] 1.5 只有一組時不顯示另一組的標題。**突變:永遠顯示兩個標題**,一條「全部都是已計入幣別」的測試必須紅。

## 2. `FinanceTransaction` 認得鏡像

- [ ] 2.1 加 `splitExpenseId`(`String?`)。`fromJson` 讀 `split_expense_id`。
- [ ] 2.2 **這條守門要寫在 `test/contexts/finance/infrastructure/http_finance_repository_test.dart`,不是 widget 測試。** 所有 3.x/4.x 的 fixture 都經過 `FakeFinanceRepository.byMonth`,裡面是**直接建構**的 `FinanceTransaction` —— `fromJson` **從來沒被呼叫過**,所以「永遠解析成 null」這個突變在 widget 層一條都不會紅。既有的 `getTransactions` 測試已經在斷言解析出來的 `category_id`/`note`,加上去即可。
- [ ] 2.3 **突變:`fromJson` 不讀 `split_expense_id`**,2.2 的 repository 測試必須紅。
- [ ] 2.4 **`FakeFinanceRepository.updateTransaction` 目前重建那一列時不帶 `splitExpenseId`** —— 不改的話 4.4 存檔後看到的會是一列沒有標記的交易,而那不是產品行為。

## 3. 明細列標記(D2)

- [ ] 3.1 鏡像的列跟自己記的列在畫面上要分得出來。**總覽的 `_RecentTransactions`(`finance_overview_tab.dart:166`)也是列**,同樣要標記 —— 只標明細的話,同一筆交易在兩個畫面上長得不一樣。
- [ ] 3.2 **突變:拿掉標記**,一條「同月有鏡像與自記交易」的測試必須紅。**fixture 兩種都要有** —— 只有鏡像的話,「全部都標記」跟「標記正確」分不出來。

## 4. 編輯 sheet:事實 + 兩個欄位(D2、D3)

- [ ] 4.1 鏡像開啟時:金額/日期/幣別/類型以**文字**呈現,分類與備註是真的輸入。
- [ ] 4.1a **`_canSave`(`add_transaction_sheet.dart:94`)讀的是 `_amountController.text`。** 拿掉金額欄位卻沒把 controller 填好,儲存鈕會永遠死著。4.4 抓得到,但先知道。
- [ ] 4.1b 標題用 `note`,而 `note` 建立之後就歸使用者所有(後端 D18),sheet 自己也讓他改。**使用者改過備註之後,標題就不再是分帳的描述** —— 這是可接受的,但別把標題寫成「分帳的描述」。
- [ ] 4.2 **刪除鈕拿掉,不是 disabled**(D3)。**突變:改成 disabled 的按鈕**,一條「鏡像的 sheet 上找不到刪除控制項」的測試必須紅 —— 斷言要用 `findsNothing`,不能只斷言 `onPressed == null`。
- [ ] 4.3 **突變:把金額改回可編輯的 `TextField`**,必須紅。斷言「找不到金額輸入框」而不是「有一個唯讀的 Text」—— 後者在兩種寫法下都成立。
- [ ] 4.3a **`type` 也要鎖,而且它比金額更嚴重。** 後端 `update-transaction.ts:36` 把 `type` 算進「改寫分帳事實」→ 400。而 `add_transaction_sheet.dart:244-252` 在切換 type 時**把 `_categoryId` 清成 null** —— 使用者點一下就抹掉了他唯一來改的那個欄位,然後儲存還會失敗。**突變:留著 type 切換**,必須紅。
- [ ] 4.4 分類與備註**仍然可編輯並且存得起來**。**突變:把它們也鎖住**,必須紅。**這條一定要有** —— 少了它,「整張 sheet 唯讀」這個過度修正會活下來,而分類正是使用者唯一需要改的東西。
- [ ] 4.5 自己記的交易 sheet **完全不變**(刪除鈕還在、所有欄位可編輯)。**突變:對所有交易都套用鎖定**,必須紅。

## 5. 409 是重新載入(D5)

- [ ] 5.1 新例外對應 409,不要掉進 `FinanceFetchFailure`。
- [ ] 5.2 訊息講「這筆分帳剛剛被改過」並**把現在的值拿回來**。
- [ ] 5.2a **「拿回來」目前沒有任何機制,而且要動的那段程式碼明文拒絕這件事。** `finance_controller.dart:331-351` 的 `_mutate` **失敗時從不重載**(註解寫明是刻意的),而 `AddTransactionSheet` 在 `initState` 就把 `widget.editing` 快照下來(`:61-68`),之後沒有任何東西重讀。所以要兩件事:(a) `_mutate` 對這個新例外要有重載分支;(b) sheet 要能依 id 從 `controller.transactions` 重新取事實。
- [ ] 5.2b **突變:只改文案、不重載**,必須紅 —— 一條「409 之後 sheet 上顯示的金額是新的那個」的測試。**少了它,一個顯示正確句子卻繼續秀著過期 900 的實作會通過 5.3。**
- [ ] 5.2c 409 是**整筆拒絕**(後端規格:「none of it is applied — not even the category change」)。決定使用者手上還沒存的分類/備註編輯要不要保留,**並寫進規格**,不要留給實作者猜。
- [ ] 5.3 **突變:讓 409 沿用既有的儲存失敗訊息**,必須紅。斷言**看得到的文案**,不是例外型別 —— 型別對不代表使用者看到對的東西。
- [ ] 5.4 400(改了鎖住的欄位)仍然走既有的驗證失敗路徑。**兩者要分得開**:突變「409 也當成 400」必須紅。

## 6. 分帳表單的分類(D6、D7)

- [ ] 6.1 `SplitExpense` 加 `categoryName`;建立/編輯都送。
- [ ] 6.2 接線:split 的表單拿得到使用者自己的 expense 分類(`grep -rn "FinanceCategory" lib/contexts/split/` 目前零筆)。
- [ ] 6.2a **`SplitExpenseSheet` 有兩個呼叫點,兩個都要接。** 第二個是 `group_detail_screen.dart:175`,從 `/finance/groups/:id` 開,建在 `FinanceScaffold` **外面**(`app.dart:706`),自己一份 15 欄位的 DI,**零 finance 存取**。只接 `finance_scaffold.dart:229` 那一個的話,**從群組頁做的編輯就是 D7 的原文**:沒有清單 → 沒送 → PATCH 清掉 → 所有沒被手動改過的鏡像靜默退回「其他」。
- [ ] 6.2b **突變:只接 `FinanceScaffold` 那一個**,一條「從群組頁編輯 → 分類不變」的測試必須紅。**6.4 的測試釘不到這個** —— 它是直接建構 sheet 並餵進分類清單的,永遠走不到清單為空那條路。
- [ ] 6.3 送**名字**不送 id。**突變:送 id**,一條斷言送出 payload 的測試必須紅。
- [ ] 6.3a **JSON 的鍵名要另外釘。** 6.3 只釘到 sheet → repository 那一段(`FakeSplitRepository` 收的是具名 Dart 參數),而 `category_name` 這個鍵是在 `http_split_repository.dart:232-248` 的 `_expenseBody` 設的,**沒有任何列出的測試會走到那裡**。create 與 update 兩個動詞都要。
- [ ] 6.3b `SplitExpense.fromJson` 同樣的問題(`split_expense.dart:48-71`):widget fixture 直接建構,解析壞掉不會有任何測試紅。守門寫在 `http_split_repository` 的測試裡。
- [ ] 6.4 **編輯時要重送現有的分類**(D7)。**突變:編輯時不送 `category_name`**,一條「只改金額 → 分類不變」的測試必須紅。**這種錯不會有任何報錯**,而且會靜默改掉別人帳本裡的分類。
- [ ] 6.5 不選分類是允許的。**突變:變成必填**,必須紅。

## 7. 規格與界線

- [ ] 7.1 D4 的兩個界線(標題不顯示「跟誰」、「前往分帳」只到分帳 tab)**寫進 PR**,不要讓人以為漏做。
- [ ] 7.1a 後端還送一個 `category_source`(`routes/finance.ts:119`)。**這個 change 用不到,明說**,不要讓它看起來像漏掉的。
- [ ] 7.2 **不要**為「深連結到單筆分帳」開路 —— 沒有路由、交易也不帶 group id,半做會留下一個看起來能用的死鏈。

## 8. 驗證

- [ ] 8.1 `flutter analyze`、`flutter test` 全綠。**不要同時跑兩個 test 程序。**
- [ ] 8.2 碰到日期的改動要 `TZ=UTC flutter test` 複驗(本機 UTC+8 / CI UTC)。
- [ ] 8.3 既有測試若因為「分帳現在計入總額」而失敗,**逐條判斷是合法的預期變化還是真的弄壞了**。已知會動到的:
  - `finance_overview_tab_test.dart:555-556`(舊文案的 key 與文字)會因為 1.3 而壞 —— 預期內。
  - `finance_overview_tab_test.dart:446`、`:467` **不會反轉,也不該反轉**。它們證明的是「前端不在本地把 `splitSpending` 加上去」,而那件事現在**更重要**了(加了就是重複計算)。**只改註解,不要動斷言。**
  - 三個 ARB 檔加上產生的 l10n。
- [ ] 8.4 **明確的非目標:`decimalDigitsFor`(`finance_money.dart:26-27`)對白名單外的幣別一律回 2。** 這個 change 把未計入的幣別放到自己一組、變得更顯眼,而 VND 這種零小數的碼會顯示成 1/100。**後端 D10 已經記過這件事,這裡不修**,但要寫進 PR,不要讓它看起來像沒發現。
