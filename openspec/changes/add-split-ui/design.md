# 分帳(sub-project 5,前端)— 設計

後端已在 `life-os-backend` main:PR #65(群組、分帳支出、拆分、按幣別餘額,12 條 endpoint)+ PR #66(群組成員帶名字)。本 change 只做前端。

## 使用者已裁定

- **入口是財務底部 nav 的第四格「分帳」**:總覽 / 明細 / 淨值 / 分帳。分帳本質就是財務,而且 sub-project 6 要把它整合進個人統計——放這裡就不用再搬。
- **分帳頁以餘額為主**:最上面是「別人欠你 / 你欠別人」的每人淨額(按幣別分列),底下才是群組與最近支出。使用者打開分帳頁的問題幾乎都是「現在誰欠誰」。

## 後端契約(已凍結)

```
GET    /api/split/groups                  → { groups: [{ id, name, created_by_user_id, archived_at,
                                                          created_at, updated_at,
                                                          members: [{ group_id, user_id, display_name, joined_at }] }] }
POST   /api/split/groups                  body { name } → 群組(201)
POST   /api/split/groups/:id/members      body { user_id } → 成員(201)
GET    /api/split/groups/:id              → { group, members }
GET    /api/split/groups/:id/balances     → { balances: [...] }
DELETE /api/split/groups/:id              → { archived: true }

GET    /api/split/expenses[?group_id=|?with=]  → { expenses: [...] }
POST   /api/split/expenses                body { group_id?, payer_user_id, amount, currency,
                                                 description, day, split } → 支出(201)
GET    /api/split/expenses/:id
PATCH  /api/split/expenses/:id
DELETE /api/split/expenses/:id

GET    /api/split/balances                → { balances: [{ user_id, display_name,
                                                            balances: [{ currency, amount }] }] }
```

`split` 兩種形狀:`{ mode: "equal", participant_user_ids: [...] }` 或 `{ mode: "exact", shares: [{ user_id, amount }] }`。

錯誤碼:`404 not_found`(可見性,永遠不是 403);400 的十種——`bad_request`(路由層輸入驗證,帶 `message`)、 `shares_do_not_sum_to_amount`(帶 `message`)、`not_a_participant`、`not_friends`、`not_a_group_member`、`group_archived`、`split_too_small`、`duplicate_participant`、`already_a_group_member`、`invalid_split_input`(帶 `message`);401 走既有 `needsReauth`。

## 架構

新 bounded context `lib/contexts/split/`,照 `contexts/social/` 四層佈局:

- `domain/`:`split_group.dart`(含 members)、`group_member.dart`、`split_expense.dart`(含 shares)、`split_share.dart`、`balance.dart`(`userId`/`displayName`/`List<CurrencyBalance>`)、`split_repository.dart`(port)、`split_exceptions.dart`(typed error,**不含文案**)。
- `application/`:`group_use_cases.dart`、`expense_use_cases.dart`、`balance_use_cases.dart`。
- `infrastructure/`:`http_split_repository.dart`,照 `HttpSocialRepository`——**吃整個 `http.Response`、讀 body 的 `error` 欄**分派,body 空或非 JSON 不得丟 decode error。
- `presentation/`:`split_controller.dart` + `split_tab.dart`、`group_detail_screen.dart` + `group_detail_controller.dart`、`split_expense_sheet.dart`。

**controller 由畫面的 `State` 持有**(`initState` 建、`dispose` 釋放),不進 `main.dart` 單例、也不在 route builder 裡建——go_router 每次 Router rebuild 都會重跑 builder,而語言/主題切換就會 rebuild(好友那期踩過,`_resetControllersOnSignOut` 只重設列名的三個 controller,新增單例漏掉就是登出換帳號後殘留)。

**`SplitTab` 的 controller 由 `FinanceScaffold` 的 `State` 持有**(`initState` 建、`dispose` 釋放)。**注意 `NetWorthController` 不是這樣的**——初版設計拿它當先例是錯的:它在 `main.dart` 建、注入進來,scaffold 自己的註解就寫著「app-lifetime singleton」,而且要靠 `app.dart` 的 `_resetControllersOnSignOut` 顯式清除。新的 controller **不要**走那條路,那正是這份設計自己警告的登出殘留。

**第四格會打斷兩個既有的東西,必須一起改**:
- AppBar 標題是一個用 `_index` 索引的**三元素**陣列 → index 3 直接 RangeError。
- FAB 只在 `_index == 2`(淨值)隱藏 → 分帳 tab 會冒出**記帳**的 FAB。分帳 tab 要有自己的 FAB(記一筆分帳),不是記帳那顆。
- 第四格也要比照 `_netWorthOpened`/`_netWorthLoaded` 的**延遲建立與載入**:`IndexedStack` 會建構所有子節點,沒有這道閘門的話,使用者還沒點進分帳就已經渲染甚至發請求了。

id token 每次請求現取(`authRepository.idToken()`),不用快取值。

## 決策要點

**D1 名字由後端直接給,前端不自己湊。** 初版設計說「群組支出的分擔人必然是群組成員、無群組支出的分擔人必然是呼叫者的好友,兩份來源就湊得齊」——**這是錯的**,proposal review 證明了:後端只檢查**建立者**的好友關係,而每個持有 share 的人都能讀這筆支出。所以 A 建 A/B/C 三人分帳(B、C 各自是 A 的好友、彼此不是)時,B 看得到 C 的 share,而 C 既不是 B 的好友也不在共同群組裡。三人一次性分帳是最常見的情境。

修法是改後端:**每個 share 都帶 `display_name`**(PR #67)、**支出帶 `payer_display_name`**(PR #68——付款人可能純代墊、完全不在 shares 裡,名字推不出來,是同一個洞往旁邊挪一格)、群組成員也帶(PR #66)。前端因此**不需要自己維護名字表**——名字跟著資料來。仍需要一個中性佔位字串,只用在後端真的沒給的邊角情況,**不是裸 uuid、不是空白**。

**D2 餘額分「別人欠你」與「你欠別人」兩段,不混在一起。** `GET /api/split/balances` 回的是**雙人**有號淨額(正 = 對方欠我)。**`GET /api/split/groups/:id/balances` 的語意不同**:那是「每位成員對整個群組」的淨額,而且**包含呼叫者自己**——照雙人那套「正 = 對方欠我」去解讀會**把錢的方向印反**。群組餘額要用自己的文案:每位成員各自「該收 / 該付」多少。按幣別分列、永不相加。**方向不能只靠顏色**(專案既有規則):用文字明說誰欠誰,顏色只是輔助。淨額 0 的人後端就不回,前端不需要處理。

**D3 建立支出的 sheet 是這一期最重的 UI。** 欄位:群組(可不選 = 一對一)、付款人、金額 + 幣別、說明、日期、參與者、拆法(均分/自訂)。**編輯時不顯示群組選擇器**——後端的 `group_id` 不可變(改了回 400),給一個必定失敗的欄位比不給更糟。PATCH 是**整份取代**,所以編輯要把全部欄位一起送,不是只送改動的那些。約束:
- **選了群組 → 參與者與付款人的候選只有該群組成員**;沒選群組 → 候選是好友 + 自己。這與後端規則一致,錯的選項根本不該出現在畫面上,而不是送出去被 400。
- **呼叫者必須有實質份額**:自己是付款人,或自己的 share > 0。UI 預設把自己勾進參與者;若使用者取消勾選自己且自己不是付款人,**送出前就擋下並說明**,不是等 400。
- 均分時即時顯示每人分到多少(含餘數落在誰身上),自訂時即時顯示**還差多少**。**餘數規則必須跟後端一模一樣**:整數除法後,多出來的 `amount % n` 個最小單位,分給**按 user_id 小寫 canonical 字串排序**的前 n 人。任何直覺猜法(付款人優先、勾選順序、名字順序)都會把餘數放在錯的人身上,於是預覽的數字跟存進去的不一樣——而且不會有任何錯誤。這條要有測試釘住,拿後端 `equalSplit` 的同一組案例(100/3、1/3、7 分 10 人)驗。——後端的 `shares_do_not_sum_to_amount` 帶 `message`,但使用者不該靠錯誤訊息才知道差額。
- 金額用既有的 `parseAmountToMinorUnits`(**不分位**的那支);顯示用 `formatMinorUnitsForDisplay`(分位)。上限 2147483647,超過在前端就擋。

**D4 只有做得到的人才看得到入口。** 後端對做不到的人一律回 404,前端不該給一個按下去必定失敗的按鈕:
- **編輯/刪除支出**:限 `created_by_user_id` 或 `payer_user_id`。
- **封存群組**:**限 `created_by_user_id`**(不是任一成員)。`created_by_user_id` 本來就在群組 JSON 裡,這道閘門不花成本;少了它,一般成員會先看到一個指名群組的確認 dialog、按下去再拿到「找不到」。

**D5 撤銷/封存的破壞性動作都要二次確認,且指名對象。** 刪除支出、封存群組。與好友那期的 D7 同一套慣例。加入成員不需確認。

**D5b 好友清單重用 social context,不新增一條路。** 名字現在由後端給,但**候選名單**(沒選群組時是「好友 + 自己」)仍需要好友列表。那是 `contexts/social` 既有的 port + adapter + typed error,所以 split controller **注入 social 的 `ListFriends` use case**;`SplitRepository` **不得**有任何 friends 方法。否則同一份資料兩條路徑、兩套錯誤映射,遲早不一致。

**D5c 呼叫者自己的 user id 從哪來。** 份額閘門、候選名單裡的「自己」、編輯入口的建立者/付款人判斷,三處都需要它,而餘額端點不會回自己。`/api/me` 有,但 `homeController.profile` 只在首頁載入——直接重新整理 `/finance` 時是 null。所以 **`SplitTab` 自己確保拿得到**:載入時若還沒有,就自己取一次;拿不到就進錯誤狀態,**不是**帶著 null 繼續跑然後把閘門悄悄跳過。

**D6 幣別怎麼選。** 沿用記帳既有的幣別清單與預設(TWD),不新做選擇器。多幣別「標記不換算」是全域決策。

**D7 分帳不進個人記帳。** 這一期不碰 `finance_transaction`,總覽/明細/淨值三個 tab 的數字完全不變。整合是 sub-project 6。

**D8 底部 nav 從三格變四格,窄螢幕要重驗。** `NavigationBar` 四個 destination 在 320dp × textScale 2.0 下的標籤會不會截斷/溢出,是這一期必測的東西——這專案整批窄螢幕 bug 都是因為測試跑在預設 800×600 才漏掉,而版面守門自己也踩過「測試視窗比真手機高」的失真。守門一律 **320/360dp × 各 locale × textScale 1.0/2.0 × 800dp 高**。

## UI/UX 設計

### 使用者路徑

**主路徑 A — 看誰欠誰**:財務 → 分帳 → 最上面就是每個人的淨額(按幣別)。**這一期餘額不可點**——與某人的往來明細(`?with=`)留到下一期,免得寫在使用者路徑裡卻沒有對應的驗收條件與任務,實作者做不做都不會被抓到。

**主路徑 B — 記一筆分帳**:分帳 tab 的 FAB → sheet → 填金額/說明/付款人/參與者/拆法 → 存 → 餘額立刻反映。

**主路徑 C — 開群組**:分帳頁「新增群組」→ 命名 → 從好友加人 → 群組詳情(成員、群組餘額、該群組的支出)。

**例外路徑**:載入失敗 → 訊息 + 重試;401 → 既有 reauth 出口;沒有任何分帳 → 空狀態說明怎麼開始(直接給「記一筆分帳」動作),不是空白頁;封存的群組 → 可讀、不能新增支出與成員,但既有支出仍可由建立者/付款人修改(與後端一致,**UI 不能比後端更嚴**,否則封存群組裡打錯的金額永遠改不掉)。

### 介面與一致性

- 沿用財務既有的 `LedgeCard` 卡片語彙與 `LabelValueRow`(名稱 + 右側金額,**兩邊都有下限**,長名字換行不把金額擠掉)。
- 金額一律 `formatMinorUnitsForDisplay`(千分位);輸入欄位用不分位那支。
- 破壞性動作的確認 dialog 一律 `scrollable: true`(好友那期在 320dp × textScale 2.0 下按鈕被推出畫面過)。
- 所有文案走 `AppLocalizations`,三個 ARB 檔同步;錯誤文案在 presentation 映射,domain/infrastructure 只丟 typed error。

### 狀態設計

| 狀態 | 分帳 tab | 群組詳情 | 支出 sheet |
|---|---|---|---|
| loading | 置中 spinner | 置中 spinner | 送出中,按鈕 disabled |
| 空 | 「還沒有分帳」+ 記一筆的動作 | 群組沒有支出 → 說明 + 記一筆 | — |
| 錯誤 | 訊息 + 重試 | 訊息 + 重試 | 依錯誤碼給對應說明,**已填內容保留** |
| 401 | 既有 reauth 出口 | 同左 | 同左 |
| 封存群組 | 標示「已封存」 | 新增支出/成員的入口不顯示 | — |

### 可及性/理解性

- 每個錯誤都要可行動:`not_friends` → 「對方還不是你的好友,先加好友再分帳」;`group_archived` → 「這個群組已封存,無法新增支出」;`shares_do_not_sum_to_amount` → 直接顯示差額。不出現「發生錯誤(400)」。
- 欠款方向用文字說明,顏色只是輔助(不能只靠顏色)。
- 圖示鈕都要有 tooltip(好友那期漏過,語意標籤是空的)。
- 破壞性確認指名對象。

## 測試策略

- **domain/application**:fake repository,錯誤傳遞。
- **infrastructure**:mock `http.Client`,逐條驗 method/path/body/`Authorization`,以及十種錯誤碼映射(含 body 空或非 JSON 不炸)。
- **presentation**:注入 fake repository 的 widget test——餘額兩段分組、多幣別分列、空狀態、錯誤+重試、401、拆法即時計算、參與者候選受群組限制、自己沒份額時送出前被擋、編輯入口只對建立者/付款人出現、確認 dialog。
- **版面**:`SplitTab`、群組詳情、支出 sheet、四格 nav bar,全部 320/360dp × 各 locale × textScale 1.0/2.0 × **800dp 高**,零 layout error;長名字守門。
- **時區**:支出的 `day` 是**純 `YYYY-MM-DD` 字串**,不是 instant——直接餵 `mediumDateLabelOrDash`(它本來就吃日字串)。**絕對不要**套 `parseInstant → toLocalTime`:那會把日期平移一天,等於自己製造出跨日 bug(初版設計把這條寫進了規範)。`created_at` 之類真正的 instant 才走 `parseInstant` + 可注入的 `toLocalTime`。仍要 `TZ=UTC flutter test` 複驗。

## 不做(明確排除)

- settle up / 還款紀錄(sub-project 6),與個人記帳連動(6)。
- 匯率換算(全域決策)。
- 離開群組、收據照片、分帳通知(後端都沒有)。
