# Tasks

由內而外,每層有測試才往下一層。重要邏輯(錯誤碼映射、拆法計算、名字解析、版面守門)一定要有測試 cover。

## 1. domain

- [ ] 1.1 `lib/contexts/split/domain/split_group.dart`:`SplitGroup`(`id`/`name`/`createdByUserId`/`archivedAt`/`members`)+ `fromJson`。**`members` 必須可選**——`POST /api/split/groups` 回的群組**沒有 members**(`GET /api/split/groups` 的每個群組物件裡有;`GET /api/split/groups/:id` 是 `{ group, members }` **兩個並列的鍵**,members 不在 group 物件裡)。寫成必填會讓建立成功但 UI 報錯,使用者重試 → 重複群組
- [ ] 1.2 `group_member.dart`:`GroupMember`(`groupId`/`userId`/`displayName`/`joinedAt`)
- [ ] 1.3 `split_expense.dart` + `split_share.dart`:`SplitExpense`(...`shares`);**`SplitShare` 有 `displayName`**(後端 PR #67),**`SplitExpense` 有 `payerDisplayName`**(PR #68——付款人可能不持 share,名字推不出來)
- [ ] 1.4 `balance.dart`:`Balance`(`userId`/`displayName`/`List<CurrencyBalance>`),`CurrencyBalance`(`currency`/`amount`,有號)。**雙人餘額**正 = 對方欠我;**群組餘額語意不同**——每位成員對整個群組、含呼叫者自己,不能套同一句解讀,否則方向會印反(design D2)
- [ ] 1.5 `split_exceptions.dart`:typed error——`SplitFetchFailure`、`SplitReauthenticationRequired`、`SplitNotFound`、`NotFriends`、`NotAGroupMember`、`GroupArchived`、`SharesDoNotSumToAmount`(帶差額訊息)、`SplitTooSmall`、`DuplicateParticipant`、`AlreadyAGroupMember`、`NotAParticipant`、`InvalidSplitInput`(帶訊息)、**`SplitBadRequest`(帶訊息)**——路由層輸入驗證回的第十種 400 `bad_request`,歸進「其餘 → SplitFetchFailure」會讓一個可修正的輸入錯誤變成泛用失敗。**不含使用者文案**
- [ ] 1.6 `split_repository.dart`:port,12 個方法,每個吃 `idToken`
- [ ] 1.7 測試:`fromJson` 缺欄位/型別錯誤丟 `SplitFetchFailure`

## 2. application

- [ ] 2.1 `group_use_cases.dart`(list/create/get/addMember/archive/groupBalances)
- [ ] 2.2 `expense_use_cases.dart`(list/create/get/update/delete)
- [ ] 2.3 `balance_use_cases.dart`(getBalances)
- [ ] 2.4 測試:fake repository,轉呼叫正確、錯誤原樣往上丟

## 3. infrastructure

- [ ] 3.1 `http_split_repository.dart`,照 `HttpSocialRepository` 的形狀——**吃整個 `http.Response`、讀 body 的 `error` 欄分派**,body 空或非 JSON **不得丟 decode error**(退回 `SplitFetchFailure`)
- [ ] 3.2 錯誤映射:401 → `SplitReauthenticationRequired`;404 → `SplitNotFound`;400 依 `error` 欄分派**十種**(含 `bad_request`);其餘 → `SplitFetchFailure`。帶 `message` 的三種(`shares_do_not_sum_to_amount`、`invalid_split_input`、`bad_request`)要把 message 帶進 typed error
- [ ] 3.3 測試(mock `http.Client`):逐條驗 method + path + body + `Authorization`;十種錯誤碼各一測;body 為空與非 JSON 各一測

## 4. 名字與身分

- [ ] 4.1 **名字直接用後端給的**(share 的 `display_name`、成員的 `display_name`、餘額的 `display_name`)。**不要自己維護名字表**——初版設計那套「靠群組成員 + 好友湊」的前提被證明是錯的(design D1)。只在後端真的沒給時退回中性佔位字串,**不是裸 uuid、不是空字串**
- [ ] 4.2 **好友清單重用 social context**:候選名單需要好友列表,注入 social 的 `ListFriends` use case;`SplitRepository` **不得**有 friends 方法(兩條路徑、兩套錯誤映射遲早不一致)
- [ ] 4.3 **呼叫者自己的 user id**:份額閘門、候選裡的「自己」、編輯入口判斷三處都要,而餘額端點不回自己;`homeController.profile` 只在首頁載入,直接重新整理 `/finance` 是 null。載入時若沒有就自己取一次,**取不到進錯誤狀態**,不得帶著 null 繼續跑把閘門悄悄跳過
- [ ] 4.4 測試:後端沒給名字時顯示佔位字串且畫面不出現 uuid;user id 取不到時進錯誤狀態而不是靜默放行

## 5. presentation — 分帳 tab

- [ ] 5.1 `split_controller.dart`:`ChangeNotifier`,狀態 loading/loaded/error/needsReauth;`load`(餘額 + 群組 + 最近支出 + 好友候選)——**不組名字表**,名字跟著後端資料來(task 4.1);好友只用來當候選名單、`createExpense`/`updateExpense`/`deleteExpense`/`createGroup`,寫入後讓畫面反映結果
- [ ] 5.2 `split_tab.dart`:餘額分「別人欠你 / 你欠別人」兩段,按幣別分列;**方向用文字說明,顏色只是輔助**;底下群組與最近支出
- [ ] 5.3 空狀態、錯誤 + 重試、401 reauth 出口
- [ ] 5.4 `FinanceScaffold` 加第四格「分帳」;controller 由 `FinanceScaffold` 的 `State` 在 `initState` 建、`dispose` 釋放。**不要照 `NetWorthController`**——它其實是 `main.dart` 建的 app-lifetime 單例、要靠 `_resetControllersOnSignOut` 清,正是要避開的登出殘留
- [ ] 5.4b **AppBar 標題陣列是三元素、用 `_index` 索引** → index 3 會 RangeError,必須補第四項
- [ ] 5.4c **FAB 目前只在 `_index == 2` 隱藏** → 分帳 tab 會冒出記帳的 FAB。分帳要有自己的 FAB(記一筆分帳)
- [ ] 5.4d 比照 `_netWorthOpened`/`_netWorthLoaded` 做**延遲建立與載入**:`IndexedStack` 會建構所有子節點,沒有閘門的話使用者還沒點進分帳就已渲染甚至發請求;每次重新進入財務 shell 要重新載入(不能因為單例殘留而永不 refetch)
- [ ] 5.5 測試:兩段分組、多幣別分列、方向文字、空狀態、錯誤+重試、401。**既有三個 tab 的行為與 test key 不變,但每一處建構 `FinanceScaffold` 的測試都要補上新的必要參數**——不要為了不動測試而把新參數設成可選預設,那會讓正式程式碼漏接也一樣綠

## 6. presentation — 記一筆分帳的 sheet

- [ ] 6.1 `split_expense_sheet.dart`:群組(可不選)、付款人、金額 + 幣別、說明、日期、參與者、拆法(均分/自訂)
- [ ] 6.1b **編輯時不顯示群組選擇器**(後端 `group_id` 不可變,改了回 400——給一個必定失敗的欄位比不給更糟);**PATCH 是整份取代**,編輯要把六個欄位全部送出,不是只送改動的那些
- [ ] 6.2 **候選名單受群組限制**:選了群組 → 只有該群組成員;沒選 → 好友 + 自己。錯的選項不該出現在畫面上,而不是送出去被 400
- [ ] 6.3 **呼叫者必須有實質份額**(自己是付款人,或自己的 share > 0):不符時**送出前就擋並說明**,不發請求
- [ ] 6.4 均分即時顯示每人分到多少(含餘數落點);自訂即時顯示**還差多少**
- [ ] 6.4b **餘數規則要跟後端一致**:整數除法後多出的 `amount % n` 個最小單位,分給**按 user_id 小寫 canonical 字串排序**的前 n 人。猜錯(付款人優先、勾選順序、名字順序)會讓預覽跟實際存的不一樣,而且不報錯。測試用後端 `equalSplit` 的同一組案例:100/3 = 34/33/33、1/3 = 1/0/0、7 分 10 人
- [ ] 6.5 金額:輸入用 `parseAmountToMinorUnits`(不分位那支),顯示用 `formatMinorUnitsForDisplay`(分位);上限 2147483647 前端就擋
- [ ] 6.6 送出中 disabled;失敗時**已填內容全部保留**
- [ ] 6.7 測試:候選受限、無份額被擋且沒發請求、均分預覽、自訂差額、上限、送出中 disabled、失敗保留輸入

## 7. presentation — 群組

- [ ] 7.1 `group_detail_screen.dart` + controller(由畫面 `State` 持有):成員、群組餘額、該群組支出
- [ ] 7.2 建立群組、從好友加成員(**不需二次確認**)、封存(**二次確認且指名群組**)。**封存入口只對 `created_by_user_id` 顯示**——後端只讓建立者封存、對其他人回 404,一般成員會看到確認 dialog 再拿到「找不到」
- [ ] 7.3 封存後:可讀、隱藏新增支出與成員的入口,但**既有支出仍可由建立者/付款人編輯刪除**(UI 不得比後端更嚴,否則封存群組裡打錯的金額永遠改不掉)
- [ ] 7.4 **編輯/刪除入口只對建立者或付款人顯示**——後端對其他人回 404,不該給一顆按下去必定失敗的按鈕
- [ ] 7.5 刪除支出要二次確認且指名
- [ ] 7.6 測試:成員名字、群組餘額、封存確認、封存後入口消失但編輯仍可用、非建立者/付款人看不到編輯入口、**非建立者看不到封存入口**

## 8. 接線與 i18n

- [ ] 8.1 `app.dart` 加群組詳情 route:**巢狀 `/finance/groups/:id`**(這個 repo 為了 web 返回鍵的慣例就是巢狀,見既有註解),builder 純由注入的 use case 建、**帶 `key: ValueKey(groupId)`**(go_router 的 pageKey 只認 path pattern,換 id 不換 key 會沿用同一個 `State`——好友那期踩過);`main.dart` 只注入無狀態的 repository 與 use case
- [ ] 8.1b 從群組詳情返回分帳 tab 時,**分帳頁要反映剛才在群組裡做的變更**(新增支出、封存)——明確選一種做法(返回時 reload,或把結果帶回)並寫進註解;測試釘住
- [ ] 8.2 三個 ARB 檔新增全部文案(`app_en` 含 `description`);`flutter gen-l10n` 產生的檔一併 commit
- [ ] 8.3 錯誤文案映射在 presentation,**每一種都要可行動**(`not_friends` → 先加好友;`group_archived` → 群組已封存無法新增;`shares_do_not_sum_to_amount` → 直接顯示差額)
- [ ] 8.4 圖示鈕都要有 tooltip(好友那期漏過,語意標籤是空的)

## 9. 版面與時區守門

- [ ] 9.1 `SplitTab`、群組詳情、支出 sheet 在 320/360dp × 各支援 locale × textScale 1.0/2.0 × **800dp 高**零 layout error(用既有 `test/support/layout_guard.dart`)。**不要用 2400dp 高的畫面**——比任何真手機都高,好友那期就是這樣讓 dialog 溢出漏掉的
- [ ] 9.2 **四格 nav bar 專門的守門**:320dp × textScale 2.0 × 各 locale,四個標籤不得溢出或被裁掉
- [ ] 9.3 破壞性確認 dialog 一律 `scrollable: true`,並在 320dp × textScale 2.0 下驗按鈕在畫面內且可點
- [ ] 9.4 長名字守門:名稱過長時換行或縮放,右側金額仍完整可見
- [ ] 9.5 支出的 `day` 是**純 `YYYY-MM-DD` 日曆日期**,直接餵 `mediumDateLabelOrDash`(它本來就吃日字串)。**絕對不要**套 `parseInstant` 或 `toLocalTime`——那會把日期平移一天,等於自己造出跨日 bug(design 127)。真正的 instant(如 `created_at`)才走 `parseInstant` + 可注入的 `toLocalTime`
- [ ] 9.5b 測試:在固定非 UTC 偏移下渲染某一天記的支出,顯示的**就是那一天**、不位移;`TZ=UTC flutter test` 複驗

## 10. 收尾

- [ ] 10.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test` 全綠
- [ ] 10.2 `TZ=UTC flutter test` 複驗
