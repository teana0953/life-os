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

**D7 沒有分帳資料的月份不顯示那一列**,不是顯示 0。後端該月回空陣列。**注意總覽的空月份分支**:目前沒有記帳交易時整個總額區塊會被換成 call-to-action;有分帳份額但沒記帳交易的月份**不能因此把分帳那列一起藏掉**。

**D8 群組頁同時顯示兩種餘額,而且標籤要誠實。**(使用者裁定「只做雙人結清,群組頁改顯示兩兩餘額」)
- 上面保留既有的**群組淨額**(每位成員對整個群組),但標籤要寫成**「分帳淨額(不含還款)」**——這一期建立的還款都是 `group_id = null`,而後端的群組餘額只加總 `s.group_id = 該群組` 的還款,所以這個數字**永遠不會因為結清而變動**。不標清楚就是兩個畫面對同一筆錢說法不一致。
- 下面新增**「我與各成員的往來」**:拿雙人餘額篩出該群組的成員,**每列都可結清**。後端 PR #70 已把無群組還款的對象條件放寬成「是好友**或**有共同群組」(照 Splitwise:加進群組本身就是關係),所以這裡不需要好友閘門——純粹透過群組產生的債不會卡住。這一段的標籤也要誠實——它是**跨全部來源**的雙人餘額,不是只算這個群組產生的。
- 兩段都不能只靠顏色表達方向。

**D9 `FinanceController` 現在撐不起「一個數字失敗不拖垮另一個」,要改結構。** 它是單一 `status` + 一包 `Future.wait`;分帳自付額若併進那包,任一失敗整頁就變錯誤狀態。所以分帳自付額要有**自己的載入狀態與錯誤**,與記帳的數字互不影響。
**而且要沿用既有的換月競態防線**:`finance-ledger-ui` 已核准的「月份切換要防競態」要求對這條新請求同樣適用——切月要清掉舊值,回應回來時若 `selectedMonth != 請求的 month` 就丟棄。少了這條,慢回應會把上個月的分帳金額蓋到這個月上,而且不報錯。

## 架構

延伸既有的 `lib/contexts/split/`:

- `domain/`:`settlement.dart`(含 `fromDisplayName`/`toDisplayName`)、`split_spending.dart`(`currency`/`amount`);`split_repository.dart` 加三個方法;`split_exceptions.dart` 加 `CannotSettleWithSelf`。
- `application/`:`settlement_use_cases.dart`(create/list/delete);`FinanceRepository` 加 `getSplitSpending`。
- `presentation/`:`settle_up_sheet.dart`;`SplitController` 加 settlement 的載入與寫入;**`group_detail_screen.dart` / `group_detail_controller.dart` 加兩兩餘額那一段(要新注入 personal `GetBalances`,連同 DI 與 route builder)**;`FinanceController` 加分帳自付額。

**新的 controller 由畫面的 `State` 持有**(`initState` 建、`dispose` 釋放)。**注意 `FinanceController` 不是這樣的**——它是 `main.dart` 建的 app-lifetime 單例(初版設計把這句寫成全稱,是錯的);本 change 擴充它,所以新增的狀態同樣要能被既有的清除路徑清掉,不能變成登出後殘留上一個帳號分帳金額的新來源。

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
