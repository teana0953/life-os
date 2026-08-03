# settle up + 分帳自付額(sub-project 6,前端)— 設計

財務藍圖最後一塊。後端已在 `life-os-backend` main(PR #69):`split_settlement` 表、三條 settlement endpoint、`GET /api/finance/split-spending?month=`,餘額已含還款扣抵。

## 使用者已裁定

- **結清的入口在餘額列上**:分帳 tab 每一列餘額旁邊給一個「結清」動作,點下去預填全額與幣別,使用者改金額或直接確認。看到欠多少的同一個地方就能處理。
- **只做雙人結清**(proposal review 之後追加的裁定)。群組頁改成同時顯示兩兩餘額,結清從那裡也能發起——見 D8。
- **分帳自付額在財務總覽獨立一列**,跟記帳支出並列,不加進支出總額。兩個數字分得開、對得了帳,也跟後端分開端點的理由一致。

## 後端契約(已凍結)

```
POST   /api/split/settlements    body { group_id?, from_user_id, to_user_id, amount, currency, day, note? } → 201
GET    /api/split/settlements[?group_id=|?with=]  → { settlements: [...] }
DELETE /api/split/settlements/:id                 → 刪除

GET    /api/finance/split-spending?month=YYYY-MM  → { month, totals: [{ currency, amount }] }
```

settlement JSON 帶 `from_display_name` / `to_display_name`,**名字不用自己湊**(與 share/payer 同一套)。

錯誤碼沿用既有 `mapSplitError` 那十種,新增 `cannot_settle_with_self`(400)。餘額端點的回應形狀沒變,只是數字已扣掉還款。

## 決策要點

**D0 結清只從「雙人餘額」發起,`group_id` 一律 `null`。** 群組餘額是「每位成員對整個群組」的淨額,**沒有 from/to 這一對**——「他欠群組 450」沒有回答要付給誰。把 D1 的正負規則套上去就是把錢記反。所以結清的來源只有一種:`GET /api/split/balances` 回的雙人餘額。

**D1 「結清」預填的金額是該幣別的全額,方向由餘額的正負決定。**
- 餘額為正(對方欠我)→ 預填 `from = 對方`、`to = 我`。
- 餘額為負(我欠對方)→ 預填 `from = 我`、`to = 對方`。
**方向不能讓使用者自己選**,否則就是把後端那條「兩段 SQL 符號相反」的陷阱原封不動搬到 UI 上。方向由畫面依餘額算好,使用者只改金額。這條要有雙向測試:欠與被欠各一次,確認送出的 `from`/`to` 沒有對調。

**D2 一列餘額可能有多個幣別,結清是「一次一個幣別」。** 後端沒有跨幣別的還款,前端也不假裝有。餘額列若有 TWD 與 USD 兩行,就有兩個「結清」入口,各自預填自己那個幣別的全額。

**D3 允許少還與多還。** 預填全額只是預設;使用者可以改小(部分還款)或改大(後端刻意不擋多還,餘額會翻向另一邊)。**多還時要在送出前提醒**「這會讓對方變成欠你」,但不阻擋——那是真實情況,不是錯誤。

**D4 還款要能刪。** 記錯了只能刪掉重記(後端沒有 PATCH,三個欄位而已)。刪除限**建立者或付款人**,其他人後端回 404,所以**入口只對這兩種人顯示**——不給一顆按下去必定失敗的按鈕(與分帳那期同一條規矩)。刪除要二次確認且指名對象與金額。

**D5 還款在明細裡要跟支出分得出來。** 分帳 tab 的清單目前只有支出;加入還款之後,兩者**必須有明顯不同的呈現**(不同圖示 + 文案寫明「還款」),否則使用者會把結清誤讀成又花了一筆錢。這正是後端不用反向支出充數的理由,前端不能在呈現上把它抵銷掉。

**D6 財務總覽的「分帳自付額」是獨立一列,不進支出總額、不進預算進度。** 後端 summary 的回應形狀沒動,分帳自付額走新端點;前端要分兩次請求並分開顯示。**預算卡的數字絕對不能把它加進去**——後端預算刻意不算分帳,前端加了就會跟預算超支的判定不一致。
**而且那一列自己要把這件事寫出來。** 它跟總額卡長得一模一樣(同 `LedgeCard`、同粗體金額),夾在預算卡與總額之間由上往下讀,沒有任何東西排除「已含在支出總額/預算已用金額裡」的誤讀。所以:**卡片排在記帳的各幣別總額之後**(spec 的「beside the recorded expense totals」),並**在標題下加一句說明「不計入上方的支出總額,也不計入預算」**——跟群組頁的 `splitGroupBalancesNote` 同一種誠實標籤的做法。

**D7 沒有分帳資料的月份不顯示那一列**,不是顯示 0。後端該月回空陣列。**注意總覽的空月份分支**:目前沒有記帳交易時整個總額區塊會被換成 call-to-action;有分帳份額但沒記帳交易的月份**不能因此把分帳那列一起藏掉**。

**D8 群組頁同時顯示兩種餘額,而且標籤要誠實。**(使用者裁定「只做雙人結清,群組頁改顯示兩兩餘額」)
- 上面保留既有的**群組淨額**(每位成員對整個群組),但標籤要寫成**「分帳淨額(不含還款)」**——這一期建立的還款都是 `group_id = null`,而後端的群組餘額只加總 `s.group_id = 該群組` 的還款,所以這個數字**永遠不會因為結清而變動**。不標清楚就是兩個畫面對同一筆錢說法不一致。
- 下面新增**「我與各成員的往來」**:拿雙人餘額篩出該群組的成員,**每列都可結清**。後端 PR #70 已把無群組還款的對象條件放寬成「是好友**或**有共同群組」(照 Splitwise:加進群組本身就是關係),所以這裡不需要好友閘門——純粹透過群組產生的債不會卡住。這一段的標籤也要誠實——它是**跨全部來源**的雙人餘額,不是只算這個群組產生的。
- 兩段都不能只靠顏色表達方向。

**D9 `FinanceController` 現在撐不起「一個數字失敗不拖垮另一個」,要改結構。** 它是單一 `status` + 一包 `Future.wait`;分帳自付額若併進那包,任一失敗整頁就變錯誤狀態。所以分帳自付額要有**自己的載入狀態與錯誤**,與記帳的數字互不影響。
**而且要沿用既有的換月競態防線**:`finance-ledger-ui` 已核准的「月份切換要防競態」要求對這條新請求同樣適用——切月要清掉舊值,回應回來時若 `selectedMonth != 請求的 month` 就丟棄。少了這條,慢回應會把上個月的分帳金額蓋到這個月上,而且不報錯。
**「切月清舊值」不夠——每次 `load` 都要清。** `summary`/`transactions` 可以在同月重載時留著舊值,因為 `status == loaded` 就代表產生它們的那次請求已經回來了;分帳自付額是**獨立的請求**,主請求 `loaded` 完全不代表這個欄位是誰的錢。而 `FinanceController` 是 app-lifetime 單例:第二個帳號在**同一個日曆月**登入,`isMonthChange == false`,主請求先回來就會把**上一個帳號**的分帳金額畫在畫面上。所以值與狀態不准分家——設 `loading` 時就一併清空。
**再加一道:登出時 `reset()`。** `FinanceScaffold` 每次進來都重載,但**重載不是清除**(同上)。所以 `app.dart` 的 `_resetControllersOnSignOut` 要一併重設 `FinanceController`,讓上一個帳號的錢在登出當下就不存在,而不是等下一次 fetch 回來。

## 架構

延伸既有的 `lib/contexts/split/`:

- `domain/`:`settlement.dart`(含 `fromDisplayName`/`toDisplayName`)、`split_spending.dart`(`currency`/`amount`);`split_repository.dart` 加三個方法;`split_exceptions.dart` 加 `CannotSettleWithSelf`。
- `application/`:`settlement_use_cases.dart`(create/list/delete);`FinanceRepository` 加 `getSplitSpending`。
- `presentation/`:`settle_up_sheet.dart`;`SplitController` 加 settlement 的載入與寫入;**`group_detail_screen.dart` / `group_detail_controller.dart` 加兩兩餘額那一段(要新注入 personal `GetBalances`,連同 DI 與 route builder)**;`FinanceController` 加分帳自付額。

**新的 controller 由畫面的 `State` 持有**(`initState` 建、`dispose` 釋放)。**注意 `FinanceController` 不是這樣的**——它是 `main.dart` 建的 app-lifetime 單例(初版設計把這句寫成全稱,是錯的);本 change 擴充它,所以新增的狀態同樣要能被既有的清除路徑清掉,不能變成登出後殘留上一個帳號分帳金額的新來源。

**結清 sheet 的「金額不能送出」原因不放進金額欄的 `errorText`。** 那個欄位是寫死 120dp 的 `SizedBox`,`InputDecoration.errorText` 預設 `errorMaxLines: 1`——一整句話進去就是**被裁掉**,而且不會噴任何 layout error(所以純粹「零 layout error」的守門是綠的,使用者卻只看到一顆按不下去的確認鈕跟半個字)。原因改成金額列下方的整寬 `Text`(沿用 `SplitExpenseSheet` 的 `_SaveBlock` 形狀),版面守門也要多一條**「訊息的 `RenderParagraph` 沒有 `didExceedMaxLines`」**的判準——裁切而非溢位正是 nav bar 那次漏掉的形狀。

**`SplitSpending` 放 finance 的 domain,不放 split。** `getSplitSpending` 是加在 `FinanceRepository` 上的,型別放 split 會讓 finance/domain 反向依賴 split/domain,憑空多一條跨 context 依賴。

## UI/UX 設計

### 使用者路徑

**主路徑 A — 結清**:財務 → 分帳 → 看到「Bob 欠你 450」→ 點該列的「結清」→ sheet 預填 450 TWD、方向已定 → 確認 → 餘額該幣別消失。

**主路徑 B — 看真實花費**:財務 → 總覽 → 支出 X、分帳自付 Y 兩列並排。

**例外路徑**:多還 → 送出前提醒會翻向另一邊,不阻擋;記錯 → 從還款紀錄刪除(限建立者/付款人);載入失敗 → 訊息 + 重試;401 → 既有 reauth 出口。

### 介面與一致性

- 沿用 `LedgeCard` 與 `LabelValueRow`;金額顯示一律 `formatMinorUnitsForDisplay`(千分位),輸入用不分位那支。
- 破壞性確認 dialog 一律 `scrollable: true`(320dp × textScale 2.0 下按鈕被推出畫面過)。
- 圖示鈕都要有 tooltip。
- 文案走 `AppLocalizations` 三個 ARB;錯誤文案在 presentation 映射。
- **版面守門的 fixture 要餵滿它名字裡的那個畫面,不是只餵新加的那一塊。** 總覽的守門原本只 seed 分帳自付額、不 seed 任何記帳交易,於是總覽走空月份分支,`_CurrencyTotalsCard` / `_CategoryBreakdown` / `_RecentTransactions` 從沒進過 widget tree——它宣稱守的畫面有一半不在場,而唯一真的 render 的那張新卡本來就已經用了 `LabelValueRow`,所以這個守門在任何情況下都不可能轉紅。餵真實資料(兩幣別 × 三分類 × 七位數 × 一個長分類名)之後才看見總覽**本來就有**的三處溢出,並一併修掉:`_TotalRow`(`Row(spaceBetween)` 兩邊都不讓)、`_CategoryBar`(`Expanded` 給了 label、金額變成鬆的那個,優先權相反)、`_TransactionRow`(金額在 `ListTile.trailing`,大字級時吃掉整個 tile,是 assertion 不是 RenderFlex 溢出)。三處都改成 `LabelValueRow`——**不要**自己重推一個等價排列,那個 65% cap 與 wrap 行為是好幾輪才收斂的,重推過就回歸過(見 `label_value_row.dart` 的註解)。`_CategoryBar` 的 icon 必須留在外層 `Row`、`LabelValueRow` 包在 `Expanded` 裡,否則整列多一個 flex child,`LabelValueRow` 那條「value 被拒的就是 label 拿到的」的算術不再成立。
- **`LabelValueRow` 的 65% 是套在你交給它的那條列上,不是套在螢幕上;所以「這一列還剩多少寬」要先算過再挑形狀。** `_TransactionRow` 把金額移進 `title` 之後,cap 變成套在 `ListTile` 已經扣掉 16dp 內距與 40dp `leading` 槽的 236dp(@360dp)上,七位數金額(165.0dp)拿到的 145.6dp 不夠,於是在**預設字級**的 360dp/375dp 斷成兩行、斷在千分位中間——而折行不丟 layout error,`expectNoLayoutErrors` 完全看不到。修法是把 icon 移進 **label 那半**,讓 `LabelValueRow` 量到整個 tile 寬(284dp),icon 由 label 的份額支出。這裡量過的數字:tile 全寬 284dp → cap 176.8dp ✓;`_CategoryBar` 那種 icon 留外層的形狀只剩 252dp → cap 158.6dp ✗。**兩個推論**:(1) 同一個 shared widget 的同一個修法,換一個宿主(多一個 `leading`、多一層內距)就可能不夠,要量;(2) 凡是「降級但不丟例外」的失效(折行、`errorText` 被裁、ellipsis),守門一定要有除「沒有 layout error」以外的判準——這裡是 `paintedTextLineCount == 1`。
- **分數 cap 保證不了絕對需求;`_TransactionRow` 最後沒有用 `LabelValueRow`。** 上一條把 icon 移進 label 之後 360/375dp 好了,320dp 沒有:那裡 `ListTile` title 只有 **236.0dp**,`LabelValueRow` 的 cap 是 `(236 − 12) × 0.65 = 145.6dp`,金額自然寬 **165.0dp**,照樣斷在千分位中間。要一行需要 `165/(236 − gap) ≥ 0.72`,而 0.65 是寫死的;連貼著卡片邊框(276dp)0.65 也只到 174.2dp、正常 16dp 內距只到 153.4dp——**沒有任何內距買得到差額**。根因不是數字調得不夠大,是**限制的形狀不對**:金額的需求是絕對寬度,分數上限保證不了絕對值。所以 `label_value_row.dart` **不動**(它是四處共用、幾輪才收斂的),只在 `_TransactionRow` 就地寫一份同形狀、下限改成**絕對 dp** 的排列:`Expanded(label) + gap + ConstrainedBox(maxWidth: row − gap − 48)`。量到 320dp cap 176dp ≥ 165.0dp(11dp 餘裕)、分類名 box 23.0dp,而 `main` 的 `trailing` 形狀給名字只有 15.0dp——金額與 `main` 齊、label 比 `main` 好。**推論**:共用 widget 的「已知限制」段落(這裡是那條寫死的 65%)要當成適用範圍讀,不合就在呼叫端另寫,別回頭改共用件的幾何。
- **守門排除某個寬度時,那個排除理由本身要量過。** 上一輪的守門在註解裡寫「320dp 兩種形狀都放不下」所以只掃 360/375——量過之後 `main` 在 320dp 是一行,那句話是錯的,而 bug 正好就活在被排除的那個寬度裡。現在掃 320/360/375/390/412 × 兩 locale,連從沒紅過的 390/412 也掃:失效區會跟著形狀移動,連兩輪都是栽在當時守門認定「不可能失敗」的寬度上。反過來,**只掃 textScale 1.0 是量出來的上限**:2.0 時金額自然寬 325.0dp,超過每一個寬度的 title(236.0–328.0dp),任何排列都不可能一行,在 2.0 斷言一行只會斷出一個假的;2.0 該守的是「這一列還能 layout」。

### 狀態設計

| 狀態 | 分帳 tab | 結清 sheet | 總覽 |
|---|---|---|---|
| loading | 既有 spinner | 送出中 disabled | 既有 spinner |
| 空 | 全部結清時說「都結清了」 | — | 沒分帳資料就不顯示那一列 |
| 錯誤 | 訊息 + 重試 | 依錯誤碼給對應說明,**已填內容保留** | **分帳自付額載入失敗不得讓整個總覽壞掉**——那一列自己顯示錯誤,記帳的數字照常 |
| 401 | 既有 reauth 出口 | 同左 | 同左 |

### 可及性/理解性

- 「Bob 欠你 450」與「你欠 Bob 450」用**文字**講清楚方向,顏色只是輔助。
- 結清 sheet 的標題要指名對象與方向(「還給 Bob」/「Bob 還你」),使用者不必回頭確認自己按到哪一列。
- 多還的提醒要說清楚後果與數字,**兩個方向各一句**(我多還 → 「Bob 會變成欠你 150」;我多記了 Bob 的還款 → 「你會變成欠 Bob 150」),不是泛泛的「金額較大」。

## 測試策略

- **domain/application**:fake repository;三個 settlement 方法與 `getSplitSpending` 的錯誤傳遞。
- **infrastructure**:mock `http.Client`,驗 method/path/body/`Authorization`,以及新的 `cannot_settle_with_self`。
- **presentation**:結清的**方向雙向測試**(欠與被欠,`from`/`to` 不得對調)、預填全額、多幣別各自結清、部分還款、多還提醒但不阻擋、刪除入口只對建立者/付款人出現、還款與支出在清單裡可區分。
- **總覽**:分帳自付額獨立一列、不進支出總額、**不進預算進度**、載入失敗不拖垮整頁、空月份不顯示。
- **版面**:結清 sheet 與總覽新那列,320/360dp × 各 locale × textScale 1.0/2.0 × **800dp 高**,零 layout error;**fixture 用夠寬的金額**(1,234,567 等級),900 那種落在失效區外、測不到東西。
- **時區**:`day` 是純日曆日期,直接餵 `mediumDateLabelOrDash`,**不要**套 `parseInstant`/`toLocalTime`(會平移一天);`TZ=UTC flutter test` 複驗。

## 不做

- 一鍵最少轉帳次數的債務重組(後端沒有,錯了會動到別人的帳)。
- 還款提醒/通知。
- 分帳自付額進趨勢圖(這一期只做總覽那一列)。
