# Tasks

由內而外。方向與「不進預算」是這一期最容易靜默出錯的兩處。

## 1. domain

- [x] 1.1 `settlement.dart`:`Settlement`(`id`/`groupId`/`fromUserId`/`fromDisplayName`/`toUserId`/`toDisplayName`/`amount`/`currency`/`day`/`note`/`createdByUserId`)+ `fromJson`。**名字由後端給**,不自己湊
- [x] 1.2 `SplitSpending`(`currency`/`amount`)放 **finance 的 domain**——`getSplitSpending` 是加在 `FinanceRepository` 上的,型別放 split 會讓 finance/domain 反向依賴 split/domain
- [x] 1.3 `split_repository.dart` 加 `createSettlement`/`listSettlements`/`deleteSettlement`;`split_exceptions.dart` 加 `CannotSettleWithSelf`
- [x] 1.4 `FinanceRepository` 加 `getSplitSpending(idToken, month)`
- [x] 1.5 測試:`fromJson` 缺欄位/型別錯誤丟既有的 fetch failure

## 2. application

- [x] 2.1 `settlement_use_cases.dart`(create/list/delete)
- [x] 2.2 `GetSplitSpending` use case,放 **finance 的 application**(與 `FinanceRepository` 同側)
- [x] 2.3 測試:fake repository,轉呼叫正確、錯誤原樣往上丟

## 3. infrastructure

- [x] 3.1 `HttpSplitRepository` 加三條;`HttpFinanceRepository` 加 `getSplitSpending`
- [x] 3.2 錯誤映射加 `cannot_settle_with_self` → `CannotSettleWithSelf`(第十一種);其餘沿用。**這個碼在本 UI 走不到**(方向是從與別人的餘額推出來的),所以**不要為它寫 UI 層測試**——那會是一個永遠不會失敗的守門;在 infrastructure 層測映射即可
- [x] 3.3 測試(mock `http.Client`):method/path/body/`Authorization`;新錯誤碼一測;body 空或非 JSON 不炸

## 4. 結清 sheet

- [x] 4.1 `settle_up_sheet.dart`:標題指名對象與方向;金額預填該幣別全額、可改;日期預設今天;備註選填
- [x] 4.2 **方向由餘額正負算好,使用者不能選**:餘額為正(對方欠我)→ `from = 對方, to = 我`;為負 → 反之。讓使用者選等於把後端「兩段 SQL 符號相反」的陷阱搬到 UI
- [x] 4.2a **只從雙人餘額發起,`group_id` 一律 `null`**(design D0)。群組淨額是「每位成員對整個群組」,沒有 from/to 這一對,套 4.2 的規則會把錢記反
- [x] 4.2c 結清入口要拿得到**對方的 user id**、**該幣別餘額的正負號**(方向靠它算,只傳金額會讓 4.2 無從判斷)(分帳 tab 的餘額列目前把它丟掉了)與**呼叫者自己的 id**(照 `SplitController` 既有的 profile 解析,**不要**再走一次 `?self=` 那條被拿掉的路)。*本次只完成 sheet 端的建構參數(`otherUserId`/`balanceAmount`/`selfUserId`);把它接到分帳 tab 的餘額列(讓列本身帶著符號)是第 5 節的範圍,尚未做。*
- [x] 4.2b 測試**雙向各一次**,斷言送出的 `from`/`to` 沒有對調——這是這一期唯一會靜默把錢記反的地方
- [x] 4.3 一列多幣別 → 每個幣別各一個結清入口,各自預填自己那個幣別的全額;**不做跨幣別還款**。*sheet 本身以「一個 currency/一個 balanceAmount」為建構參數,天生只認一個幣別;每列渲染出多個入口是第 5 節分帳 tab 的接線,尚未做。*
- [x] 4.4 部分還款照送;**多還在送出前提醒**,**兩個方向各一句文案**(我多還 → 「對方會變成欠你 X」;對方多還 → 「你會變成欠對方 X」)——表單兩個方向都到得了,寫死一句有一半情況會講反。要說出後果與數字,不是泛泛的「金額較大」,**但不阻擋**
- [x] 4.5 金額:輸入用 `parseAmountToMinorUnits`(不分位),顯示用 `formatMinorUnitsForDisplay`(分位)。前端要擋的**不只上限**:**非正數與非整數也要擋**(清空欄位或打 0 會拿到後端 400,而那是表單本來就能防的);上限 2147483647
- [x] 4.6 送出中 disabled;失敗時**已填內容全部保留**
- [x] 4.7 測試:預填全額、多幣別各自結清、部分還款、**兩個方向的多還提醒各一測**、上限與 0/空值、送出中 disabled、失敗保留輸入

## 5. 分帳 tab 的還款

- [ ] 5.1 `SplitController` 載入還款清單並與支出一起呈現;**還款與支出必須可區分**(不同圖示 **+ 文案寫明「還款」**,不能只靠圖示或顏色)
- [ ] 5.2 刪除還款:**入口只對 `createdByUserId` 或 `fromUserId` 顯示**(其他人後端回 404,不給必定失敗的按鈕);二次確認**指名對象與金額**,dialog `scrollable: true`
- [ ] 5.3 結清成功後餘額要反映(該幣別歸零就從列表消失);刪除還款後餘額要回到原本的數字
- [ ] 5.4 全部結清時的空狀態:「都結清了」,不是空白
- [ ] 5.5 測試:還款列可區分、刪除入口的權限、結清後餘額更新、刪除後餘額回復、全清空狀態

## 5b. 群組頁的兩種餘額(design D8)

- [ ] 5b.1 群組頁既有的「每位成員對整個群組」淨額**改標籤為「分帳淨額(不含還款)」**。這一期的還款都是 `group_id = null`,而後端的群組餘額只加總 `s.group_id = 該群組` 的還款,所以這個數字**永遠不會因為結清而變動**。**不改標籤就是永久且無聲的矛盾**:分帳 tab 顯示已結清,群組頁還寫著「Bob 應收 450」
- [ ] 5b.2 群組頁新增「我與各成員的往來」:拿**雙人餘額**篩出該群組成員,每列可結清(方向照 4.2、`group_id` 照 4.2a 為 null)。標籤要誠實寫明這是**跨全部來源**的雙人餘額,不是只算這個群組
- [ ] 5b.3 `GroupDetailController` 目前**沒有注入任何 personal `GetBalances`**,**也沒有任何 settlement 的寫入 use case**(它只有支出那幾支)——兩者都要新增,並補上對應的 DI 與 route builder 接線(`splitGetBalances` 已存在於 `main.dart` 且已是 `App` 的欄位,所以只要多傳參數,`main.dart` 不用動)
- [ ] 5b.3b **群組成員一律可結清,不需要先是好友**(後端 PR #70 已放寬:無群組還款的對象條件改成「是好友**或**有共同群組」)。所以群組頁那一段**不需要好友閘門**,每一列都給結清入口
- [ ] 5b.4 測試:群組淨額那段的標籤含「不含還款」字樣且**不提供結清入口**;雙人那段有結清入口且方向正確;兩段的方向都不只靠顏色
- [ ] 5b.5 版面守門涵蓋群組頁新的那一段(併入 7.4 的矩陣)

## 6. 財務總覽的分帳自付額

- [ ] 6.1 `FinanceController` 另外抓 `getSplitSpending`,**要有自己的載入狀態與錯誤**,不能併進既有那包 `Future.wait`(單一 `status` 會讓任一失敗把整頁變錯誤狀態);總覽卡加**獨立一列**,按幣別
- [ ] 6.1b **沿用既有的換月競態防線**(`finance-ledger-ui` 已核准的「月份切換要防競態」對這條新請求同樣適用):切月清舊值,回應回來時 `selectedMonth != 請求的 month` 就丟棄。少了這條,慢回應會把上個月的金額蓋到這個月,而且不報錯
- [ ] 6.2 **不加進支出總額**;**不進預算卡的已用金額與警示狀態**——後端預算刻意不算分帳,前端加了就會跟超支判定不一致
- [ ] 6.3 該月沒有分帳 → **不顯示那一列**,不是顯示 0。**但有分帳份額、沒有記帳交易的月份不能被空月份分支一起藏掉**——總覽目前在沒有交易時把整個總額區塊換成 call-to-action
- [ ] 6.4 **那一列載入失敗不得讓整個總覽壞掉**:記帳的數字照常顯示,那一列自己報錯
- [ ] 6.5 測試:獨立顯示、支出總額不變、**預算卡的已用金額與警示狀態完全不變**、空月份不顯示、**有分帳但無交易的月份仍看得到那一列**、分帳請求失敗時總覽其餘部分仍正常、**換月競態(舊月的慢回應不得蓋掉新月)**

## 7. i18n 與版面

- [ ] 7.1 三個 ARB 檔新增文案(`app_en` 含 `description`);`flutter gen-l10n` 產出一併 commit
- [ ] 7.2 錯誤文案映射在 presentation,每種都要可行動
- [ ] 7.3 圖示鈕都要有 tooltip
- [ ] 7.4 版面守門:結清 sheet、還款列、刪除確認、總覽新那列,320/360dp × 各 locale × textScale 1.0/2.0 × **800dp 高**,零 layout error。**fixture 金額用 1,234,567 等級**——900 那種落在失效區之外,守門測不到東西(上一期就是這樣漏掉 `ListTile.trailing` 吃掉整個 tile)
- [ ] 7.5 `day` 是純日曆日期,直接餵 `mediumDateLabelOrDash`;**不要**套 `parseInstant`/`toLocalTime`(會平移一天)

## 8. 收尾

- [ ] 8.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test` 全綠
- [ ] 8.2 `TZ=UTC flutter test` 複驗
