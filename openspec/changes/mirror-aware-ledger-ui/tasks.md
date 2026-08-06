# Tasks

**這是修一個正在說反話的 app,不是加功能。** 每個守門都要能抓到「畫面講的跟後端做的不一樣」。

## 1. 分帳卡逐幣別分組(D1)—— 最急

- [ ] 1.1 `SplitSpending` 加 `countedInTransactions`,**必填,不要給 `= false` 預設值** —— 預設 false 正好是「靜默重現今天那句錯話」的方向。
- [ ] 1.1a **parse 層要有自己的守門**(寫在 `split_spending_test.dart` 或 `http_finance_repository_test.dart:409`)。1.4/1.5 走的是 `FakeFinanceRepository.getSplitSpending`,裡面是**直接建構**的 `SplitSpending`,`fromJson` **從來不會跑**。鍵名拼錯而讀成 `?? false` 的話,**每一個 TWD 都會說「未計入」** —— 正好是這個 change 要刪掉的那句話,而且沒有任何列出的測試會紅。**突變:讀錯鍵名。**
- [ ] 1.2 卡片分兩組,句子放在**各自那組的金額旁邊**,不是卡片頂端一句話管全部。
- [ ] 1.3 **舊的 `financeSplitSpendingNote`(「不計入上方的支出總額,也不計入預算」)要刪掉**,不是留著改字 —— 它現在對 TWD 是假的。
- [ ] 1.4 **突變:兩組都用同一句文案**,一條「同月有 TWD(已計入)與 THB(未計入)」的測試必須紅。**fixture 一定要兩種都有** —— 只有一種的話,一句話蓋全部照樣綠。
- [ ] 1.5 只有一組時不顯示另一組的標題。**突變:永遠顯示兩個標題**,一條「全部都是已計入幣別」的測試必須紅。

## 2. `FinanceTransaction` 認得鏡像

- [ ] 2.1 加 `splitExpenseId`(`String?`)。`fromJson` 讀 `split_expense_id`。
- [ ] 2.2 **這條守門要寫在 `test/contexts/finance/infrastructure/http_finance_repository_test.dart`,不是 widget 測試。** 所有 3.x/4.x 的 fixture 都經過 `FakeFinanceRepository.byMonth`,裡面是**直接建構**的 `FinanceTransaction` —— `fromJson` **從來沒被呼叫過**,所以「永遠解析成 null」這個突變在 widget 層一條都不會紅。`http_finance_repository_test.dart:52-91` 的 `getTransactions` 測試**目前只斷言 `amount`** —— 不是我先前寫的「已經在斷言 `category_id`/`note`」。要在 fixture JSON 裡加 `split_expense_id` 並斷言它。
- [ ] 2.3 **突變:`fromJson` 不讀 `split_expense_id`**,2.2 的 repository 測試必須紅。
- [ ] 2.4 **`FakeFinanceRepository.updateTransaction` 目前重建那一列時不帶 `splitExpenseId`**(`finance_test_support.dart:216-224`)。**這件事 4.4 看不到** —— 它在 `add_transaction_sheet_test.dart`,根本不畫列表。要嘛把「存檔後標記還在」寫成 transactions tab 的測試,要嘛在 4.4 裡明確斷言。**不要只改 fake 就當作守住了。**

## 3. 明細列標記(D2)

- [ ] 3.1 鏡像的列跟自己記的列在畫面上要分得出來。**總覽的 `_RecentTransactions`(`finance_overview_tab.dart:166`)也是列**,同樣要標記 —— 只標明細的話,同一筆交易在兩個畫面上長得不一樣。
- [ ] 3.2 **兩個畫面各要一條測試。** 只測明細的話,「只把總覽那顆標記拿掉」這個突變會活下來 —— 而 3.1 說不能發生的正是「同一筆交易在兩個畫面上長得不一樣」。**突變:各自拿掉標記**,對應那條必須紅。**fixture 兩種交易都要有** —— 只有鏡像的話,「全部都標記」跟「標記正確」分不出來。

## 4. 編輯 sheet:事實 + 兩個欄位(D2、D3)

- [ ] 4.1 鏡像開啟時:金額/日期/幣別/類型以**文字**呈現,分類與備註是真的輸入。
- [ ] 4.1a **`_canSave`(`add_transaction_sheet.dart:94`)讀的是 `_amountController.text`。** 拿掉金額欄位卻沒把 controller 填好,儲存鈕會永遠死著。4.4 抓得到,但先知道。
- [ ] 4.1b 標題用 `note`,而 `note` 建立之後就歸使用者所有(後端 D18),sheet 自己也讓他改。**使用者改過備註之後,標題就不再是分帳的描述** —— 這是可接受的,但別把標題寫成「分帳的描述」。
- [ ] 4.2a **「前往分帳」這個出口要真的做出來,或從 design/proposal 裡刪掉。** D2 的圖與 D3 都寫了它,但規格 delta 只要求「說明去哪裡改」(一句話),**沒有任何 task 建它、沒有守門**。它不是免費的:`AddTransactionSheet` 只有一個呼叫點(`finance_scaffold.dart:396`),而分帳 tab 是 `FinanceScaffold` 自己的 tab index,所以要從 scaffold 穿一個 callback 進來。**決定:做。** 沒有出口的話那句說明是死路 —— 使用者得自己關掉、自己找到分帳 tab。
- [ ] 4.2b **突變:拿掉那個 callback 的接線(傳 null)**,一條「鏡像 sheet 上按下前往分帳會切到分帳 tab」的測試必須紅。
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
- [ ] 5.2c **已決定:未存的分類/備註編輯要保留**(D5、規格皆已寫)。409 是整筆拒絕,伺服器沒吃掉使用者選的東西,重載之後應該還在 —— 讓他在新的事實上重按一次儲存,而不是重挑一次分類。
- [ ] 5.2d **5.2b 的實作會威脅這件事。** 依 id 重讀那一列的直覺寫法會把 `categoryId`/`note` 一起拉回來,**蓋掉使用者還沒存的選擇** —— 那樣會通過 5.2b 卻違反規格。**要一條測試同時斷言兩半**:409 之後金額顯示新的值,**而且**使用者剛剛挑的分類還選著。
- [ ] 5.3 **突變:讓 409 沿用既有的儲存失敗訊息**,必須紅。斷言**看得到的文案**,不是例外型別 —— 型別對不代表使用者看到對的東西。
- [ ] 5.4 400(改了鎖住的欄位)仍然走既有的驗證失敗路徑。**突變要寫成「400 也當成 409」** —— 反過來寫(「409 當成 400」)紅的是 5.3 那條 409 文案測試,不會增加任何覆蓋。
- [ ] 5.5 **404 現在會因為別人的動作而發生**:付款人刪掉分帳 → cascade 把鏡像也刪了 → 使用者手上那張 sheet 指向一列不存在的資料。現在它掉進 `financeSaveFailed`,使用者會留在一個已經不存在的畫面上編輯。**要有自己的處理**(告訴他分帳被刪了、關掉 sheet、刷新),以及一條測試。
- [ ] 5.6 **409 重載之後那一列可能不在這個月了** —— 日期是可以被改的事實之一,付款人可以把它改到別的月份。依 id 重讀時 `firstWhere` 找不到會丟 `StateError`。**要有測試涵蓋「重載後那一列不見了」。**

## 6. 分帳表單的分類(D6、D7)

- [ ] 6.1 `SplitExpense` 加 `categoryName`;建立/編輯都送。
- [ ] 6.2 接線:split 的表單拿得到使用者自己的 expense 分類(`grep -rn "FinanceCategory" lib/contexts/split/` 目前零筆)。
- [ ] 6.1a **`categoryName` 要穿過的地方**(先列出來,不要邊做邊發現):`SplitExpenseWriter`、`CreateExpense`/`UpdateExpense`、`SplitRepository` port、`HttpSplitRepository._expenseBody`、`SplitController`、`GroupDetailController`、`FakeSplitRepository`(**要加一個 `gotCategoryName` 欄位,否則 6.3 的守門沒有東西可讀**)、`split_presentation_fakes.dart`。
- [ ] 6.2a **`SplitExpenseSheet` 有兩個呼叫點,兩個都要接。** 第二個是 `group_detail_screen.dart:175`,從 `/finance/groups/:id` 開,建在 `FinanceScaffold` **外面**(`app.dart:706`),自己一份 15 欄位的 DI,**零 finance 存取**。只接 `finance_scaffold.dart:229` 那一個的話,**從群組頁做的編輯就是 D7 的原文**:沒有清單 → 沒送 → PATCH 清掉 → 所有沒被手動改過的鏡像靜默退回「其他」。
- [ ] 6.2b **不要用「從群組頁編輯 → 分類不變」當守門,它不可能失敗。** sheet 既有的欄位都是「從 `editing` 種進 state」(`split_expense_sheet.dart:126-134`:`_currency = editing.currency`),分類照做就是 `String? _categoryName = editing?.categoryName` —— 那樣的話**沒接線的呼叫點照樣會把原本的分類重送回去**,選單是空的但值還在,加不加接線都綠。
- [ ] 6.2c **要釘的是「沒接線時選單裡是空的」。** 從 `GroupDetailScreen` 根起的測試(`test/contexts/split/presentation/group_detail_screen_test.dart` 的 harness 支援)開啟 sheet,斷言**分類選單裡有使用者自己的分類**。**突變:只接 `FinanceScaffold` 那一個** → 選單空 → 紅。
- [ ] 6.2d **順帶把 state 的形狀釘死:存名字,不是存 id 再去清單查。** 存 id 的寫法在清單為空時會送出 null,是靜默資料損失;存名字則最差也只是原值重送。
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
  - **`countedInTransactions` 設成必填會打到每一個 `const SplitSpending(...)` 字面值** —— `finance_overview_tab_test.dart` 六處,加上 `get_split_spending_test.dart` 與 `split_spending_test.dart`。逐個補,不要為了少改幾行而給預設值。
- [ ] 8.5 **1.4 的 THB fixture 會照 `decimalDigitsFor` 的既有錯誤渲染**(白名單外一律 2 位,見 8.4 的非目標)。測試裡的期望文字要寫成 ÷100 的那個形式,**並在註解說明原因**,否則看起來像測試寫錯。
- [ ] 8.4 **明確的非目標:`decimalDigitsFor`(`finance_money.dart:26-27`)對白名單外的幣別一律回 2。** 這個 change 把未計入的幣別放到自己一組、變得更顯眼,而 VND 這種零小數的碼會顯示成 1/100。**後端 D10 已經記過這件事,這裡不修**,但要寫進 PR,不要讓它看起來像沒發現。
