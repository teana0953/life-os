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

- [x] 5.1 `SplitController` 載入還款清單並與支出一起呈現;**還款與支出必須可區分**(不同圖示 **+ 文案寫明「還款」**,不能只靠圖示或顏色)
- [x] 5.2 刪除還款:**入口只對 `createdByUserId` 或 `fromUserId` 顯示**(其他人後端回 404,不給必定失敗的按鈕);二次確認**指名對象與金額**,dialog `scrollable: true`
- [x] 5.3 結清成功後餘額要反映(該幣別歸零就從列表消失);刪除還款後餘額要回到原本的數字
- [x] 5.4 全部結清時的空狀態:「都結清了」,不是空白
- [x] 5.5 測試:還款列可區分、刪除入口的權限、結清後餘額更新、刪除後餘額回復、全清空狀態

## 5b. 群組頁的兩種餘額(design D8)

- [x] 5b.1 群組頁既有的「每位成員對整個群組」淨額**改標籤為「分帳淨額(不含還款)」**。這一期的還款都是 `group_id = null`,而後端的群組餘額只加總 `s.group_id = 該群組` 的還款,所以這個數字**永遠不會因為結清而變動**。**不改標籤就是永久且無聲的矛盾**:分帳 tab 顯示已結清,群組頁還寫著「Bob 應收 450」
- [x] 5b.2 群組頁新增「我與各成員的往來」:拿**雙人餘額**篩出該群組成員,每列可結清(方向照 4.2、`group_id` 照 4.2a 為 null)。標籤要誠實寫明這是**跨全部來源**的雙人餘額,不是只算這個群組
- [x] 5b.3 `GroupDetailController` 目前**沒有注入任何 personal `GetBalances`**,**也沒有任何 settlement 的寫入 use case**(它只有支出那幾支)——兩者都要新增,並補上對應的 DI 與 route builder 接線(`splitGetBalances` 已存在於 `main.dart` 且已是 `App` 的欄位,所以只要多傳參數,`main.dart` 不用動)
- [x] 5b.3b **群組成員一律可結清,不需要先是好友**(後端 PR #70 已放寬:無群組還款的對象條件改成「是好友**或**有共同群組」)。所以群組頁那一段**不需要好友閘門**,每一列都給結清入口
- [x] 5b.4 測試:群組淨額那段的標籤含「不含還款」字樣且**不提供結清入口**;雙人那段有結清入口且方向正確;兩段的方向都不只靠顏色
- [x] 5b.5 版面守門涵蓋群組頁新的那一段(併入 7.4 的矩陣)

## 6. 財務總覽的分帳自付額

- [x] 6.1 `FinanceController` 另外抓 `getSplitSpending`,**要有自己的載入狀態與錯誤**,不能併進既有那包 `Future.wait`(單一 `status` 會讓任一失敗把整頁變錯誤狀態);總覽卡加**獨立一列**,按幣別
- [x] 6.1b **沿用既有的換月競態防線**(`finance-ledger-ui` 已核准的「月份切換要防競態」對這條新請求同樣適用):切月清舊值,回應回來時 `selectedMonth != 請求的 month` 就丟棄。少了這條,慢回應會把上個月的金額蓋到這個月,而且不報錯
- [x] 6.2 **不加進支出總額**;**不進預算卡的已用金額與警示狀態**——後端預算刻意不算分帳,前端加了就會跟超支判定不一致
- [x] 6.3 該月沒有分帳 → **不顯示那一列**,不是顯示 0。**但有分帳份額、沒有記帳交易的月份不能被空月份分支一起藏掉**——總覽目前在沒有交易時把整個總額區塊換成 call-to-action
- [x] 6.4 **那一列載入失敗不得讓整個總覽壞掉**:記帳的數字照常顯示,那一列自己報錯
- [x] 6.5 測試:獨立顯示、支出總額不變、**預算卡的已用金額與警示狀態完全不變**、空月份不顯示、**有分帳但無交易的月份仍看得到那一列**、分帳請求失敗時總覽其餘部分仍正常、**換月競態(舊月的慢回應不得蓋掉新月)**

## 7. i18n 與版面

- [x] 7.1 三個 ARB 檔新增文案(`app_en` 含 `description`);`flutter gen-l10n` 產出一併 commit
- [x] 7.2 錯誤文案映射在 presentation,每種都要可行動
- [x] 7.3 圖示鈕都要有 tooltip
- [x] 7.4 版面守門:結清 sheet、還款列、刪除確認、總覽新那列,320/360dp × 各 locale × textScale 1.0/2.0 × **800dp 高**,零 layout error。**fixture 金額用 1,234,567 等級**——900 那種落在失效區之外,守門測不到東西(上一期就是這樣漏掉 `ListTile.trailing` 吃掉整個 tile)
- [x] 7.5 `day` 是純日曆日期,直接餵 `mediumDateLabelOrDash`;**不要**套 `parseInstant`/`toLocalTime`(會平移一天)

## 8. 收尾

- [x] 8.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test` 全綠
- [x] 8.2 `TZ=UTC flutter test` 複驗

## 9. review/QA 回饋修正

- [x] 9.1 **總覽的分帳自付額不得殘留上一個帳號的數字**:`FinanceController.load` 每次都清空 `splitSpending`(不只切月),並新增 `reset()` 讓 `app.dart` 的 `_resetControllersOnSignOut` 一併清掉(design D9 補述)
- [x] 9.2 **分帳 tab 的結清接線與刪除還款確認要有測試**:`FinanceScaffold` 層的兩方向結清(方向、from/to、`group_id` 為 null)與刪除確認(取消不刪、確認才刪);兩者都以 `balanceAmount: -balanceAmount` 的變異驗證會轉紅
- [x] 9.3 `split_controller_test` 的「`group_id` 永遠是 null」改讀 `gotCreateSettlementGroupId`——原本讀的 `gotGroupId` 會被隨後的 `load` 重設,斷言等於沒斷
- [x] 9.4 **金額被拒的原因要看得完**:移出 120dp 欄位的 `errorText`,改成金額列下方整寬 `Text`;版面守門加上「`didExceedMaxLines` 為 false」的判準(design D6/D9 之後的補述)
- [x] 9.5 **總覽的分帳自付額卡要說清楚它不算在哪裡**:新增 `financeSplitSpendingNote` 三語文案,卡片移到記帳總額之後
- [x] 9.6 `splitErrorText` 補上 `CannotSettleWithSelf` 分支(spec 的 MODIFIED 需求本來就列了它);它從現有兩個入口不可達,所以只在**映射層**測,不加一個永遠不會失敗的 UI 測試
- [x] 9.7 刪除還款的版面守門改成**真的 render `FinanceScaffold._confirmDeleteSettlement`**,並併入 320/360dp × locale × 1.0/2.0 的矩陣
- [x] 9.8 **總覽的版面守門原本不可能轉紅**:它只餵分帳自付額、不餵任何記帳交易,所以 `_CurrencyTotalsCard` / `_CategoryBreakdown` / `_RecentTransactions` 根本沒被 build——守的是它自己名字裡那半個畫面之外的東西。fixture 改成兩種幣別 × 三個支出分類(其中一個用 `_longName`)× 七位數金額,並在守門內把整個 `ListView` 捲到底再捲回來(大字級時卡片在 fold 之下,單純 pump 建不出來)
- [x] 9.9 **9.8 的 fixture 揭出總覽本來就有的溢出**(不是本次改動造成的:`git diff main` 對 `finance_overview_tab.dart` 全部是新的分帳卡)。三處都改成 `LabelValueRow` 的形狀——value 是非 flex 的那半、label 才會 wrap:
      - `_TotalRow`:原本是 `Row(spaceBetween)`,兩邊都不會讓,320dp/1x 的 1,234,567 溢 4.3px、320dp/2x 的 900 溢 51px
      - `_CategoryBar`:原本 `Expanded` 在分類名、金額是鬆的那個,優先權剛好相反;icon 留在外層 `Row`,`LabelValueRow` 包在 `Expanded` 裡,維持「整列只有一個 flex child」這個它的 65% cap 賴以成立的前提
      - `_TransactionRow`:金額從 `trailing` 移進 `title` 的列裡,和 `networth_tab` 的帳戶列同一個修法——`ListTile.trailing` 不受約束,2x 時「Trailing widget consumes the entire tile width」是 assertion 而非 RenderFlex 溢出,後面跟著一整串沒 layout 的祖先
      變異驗證:把這三處還原,守門 8 個 case 紅 5 個(320/1x、320/2x×2 locale、360/2x×2 locale);修回來 8/8 綠
- [x] 9.10 **9.9 的 `_TransactionRow` 修法自己長出新 bug**(QA 第三輪):金額進了 `title` 的 `LabelValueRow`,但那條 65% cap 這次是套在 `ListTile` **已經**扣掉 16dp 內距與 40dp `leading` 槽之後的列上,於是預設字級的七位數金額在 360dp/375dp 斷成兩行、斷在千分位中間(`+1,234,5` / `67`、`+1,234,56` / `7`,列高 24→48dp),390dp 以上才正常——而**折行不會丟出任何 layout error**,原本的 320/360 × 1.0/2.0 守門因此全綠。
      - 修法:分類 icon 從 `ListTile.leading` 移進 **label 自己那半**(`Row(Icon, SizedBox, Flexible(Text(name)))`)。`LabelValueRow` 量到的因此是整個 tile 的寬(和 `networth_tab` 的帳戶列一樣的 284dp@360dp,而不是 236dp),icon 改由 label 那半的份額支出——label 本來就是會讓的那半——它自己的列仍然只有一個 flex child。**注意**:`_CategoryBar` 那種「icon 留在外層 `Row`」的形狀在這裡量過不夠:tile 內距 32dp + icon 32dp 只剩 252dp,cap 158.6dp < 金額所需的 165.0dp,360dp 與 375dp 都還是會折。
      - 守門:`expectNoLayoutErrors` 對這種無聲降級沒有判準,所以新增「總覽最近交易的金額在 360dp/375dp、textScale 1.0 維持一行」的 `paintedTextLineCount == 1` 斷言(斷在**帶正負號**的字串上——總額卡與分類條印的是同樣的數字但不帶號,斷不到別的列去)
      變異驗證:把 icon 移回 `leading`,新守門 360dp/375dp 兩個 case 轉紅(`-1,234,567 was broken across lines`),其餘 76 綠;把金額放回 `ListTile.trailing`,原本的 2.0 字級守門 4 個 case 轉紅(320/360dp × 兩 locale),證明 9.9 修掉的那個 assertion 沒有回來
- [x] 9.11 **9.10 的修法又長出新 bug,而且是在守門自己排除掉的那個寬度**(QA 第四輪):icon 移進 label 之後 360dp/375dp 修好了,320dp 沒有——`-1,234,567` 仍然畫成 `-1,234,5` / `67`,兩個 locale 都是。9.10 的守門看不到,因為它只掃 360/375,並在註解裡把 320 排除掉,理由是「320dp 兩種形狀都放不下」;量過之後那句是錯的,`main` 在 320dp 是**一行**。
      - 量到的數字(textScale 1.0、`bodyLarge`/w700、`-1,234,567`):320dp 螢幕 → 280dp 卡 → 邊框內 276dp → `ListTile` title **236.0dp**;金額自然寬 **165.0dp**;`LabelValueRow` 給的 cap `(236 - 12) × 0.65 = 145.6dp` → 折成兩行。`main`(金額在 `trailing`、不受約束)拿到 165.0dp → 一行,但分類名的 box 只剩 **15.0dp**,`餐飲` 一行一個字。
      - **`LabelValueRow` 在這一列表達不出來,這是量出來的、不是風格判斷**:320dp 要一行需要 `165/(236 - gap) ≥ 0.72` 的 cap,而它固定 0.65;而且沒有任何內距能買到差額——就算貼著卡片邊框(276dp)0.65 也只給到 174.2dp、正常 16dp 內距只給到 153.4dp。**根因是限制的形狀不對**:金額的需求是一個**絕對寬度**,分數 cap 保證不了絕對值。`label_value_row.dart` 是 `_TotalRow` / `_CategoryBar` / `_SplitSpendingCard` / 淨值列共用、幾輪才收斂的,所以**不動它**,只在 `_TransactionRow` 就地換成同形狀但**絕對下限**的版本:`Expanded(label) + gap + ConstrainedBox(maxWidth: row - gap - _amountLabelFloor)`,`_amountLabelFloor = 48`(icon 24 + 12 + 12dp 名字)。
      - 換完量到:320dp cap `236 - 12 - 48 = 176dp` ≥ 165.0dp(11dp 餘裕)→ 一行;分類名 box 23.0dp(`main` 是 15.0dp,所以 label 那半比 `main` 好、金額那半跟 `main` 齊)。320/360/375/390/412dp × 兩 locale 全部一行。
      - 守門:寬度掃到 **320/360/375/390/412 × 兩 locale**(390/412 從沒紅過也掃——失效區會跟著形狀移動,連兩輪都是栽在當時守門認定「不可能失敗」的寬度上)。**只掃 textScale 1.0,而這是量出來的上限不是遺漏**:2.0 時同一個金額自然寬 325.0dp,超過每一個寬度的 title(236.0–328.0dp),任何排列都不可能一行,在 2.0 斷言一行只會斷出一個假的。2.0 守的是「這一列還能 layout」——就是上面那組 320/360dp × 2.0 的掃描。
      變異驗證:把 cap 改回 `(row - gap) × 0.65`(即 9.10 的形狀),新守門 320dp 兩個 locale 轉紅(`-1,234,567 was broken across lines at 320dp`),360/375/390/412 共 8 個仍綠;把金額放回 `ListTile.trailing`,320dp/2.0 與 360dp/2.0 × 兩 locale 共 4 個「總覽 lays out cleanly」轉紅(`RenderBox was not laid out`,即 `Trailing widget consumes entire tile width` 之後那串沒 layout 的祖先),證明 9.9 修掉的那個 assertion 沒有回來
      - 順帶記錄(**本次不修**):`budget_card.dart:105` 的 `_BudgetRow` 在七位數預算+七位數已花時右溢(320dp 55px、360dp 15px、375dp 0.25px),在 `main` 上量到完全相同的數字,本次沒有動過那個檔案,屬既有問題
