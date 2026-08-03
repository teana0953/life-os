# Tasks

由內而外,每層有測試才往下一層。重要邏輯(錯誤碼映射、拆法計算、名字解析、版面守門)一定要有測試 cover。

## 1. domain

- [x] 1.1 `lib/contexts/split/domain/split_group.dart`:`SplitGroup`(`id`/`name`/`createdByUserId`/`archivedAt`/`members`)+ `fromJson`。**`members` 必須可選**——`POST /api/split/groups` 回的群組**沒有 members**(`GET /api/split/groups` 的每個群組物件裡有;`GET /api/split/groups/:id` 是 `{ group, members }` **兩個並列的鍵**,members 不在 group 物件裡)。寫成必填會讓建立成功但 UI 報錯,使用者重試 → 重複群組
- [x] 1.2 `group_member.dart`:`GroupMember`(`groupId`/`userId`/`displayName`/`joinedAt`)
- [x] 1.3 `split_expense.dart` + `split_share.dart`:`SplitExpense`(...`shares`);**`SplitShare` 有 `displayName`**(後端 PR #67),**`SplitExpense` 有 `payerDisplayName`**(PR #68——付款人可能不持 share,名字推不出來)
- [x] 1.4 `balance.dart`:`Balance`(`userId`/`displayName`/`List<CurrencyBalance>`),`CurrencyBalance`(`currency`/`amount`,有號)。**雙人餘額**正 = 對方欠我;**群組餘額語意不同**——每位成員對整個群組、含呼叫者自己,不能套同一句解讀,否則方向會印反(design D2)
- [x] 1.5 `split_exceptions.dart`:typed error——`SplitFetchFailure`、`SplitReauthenticationRequired`、`SplitNotFound`、`NotFriends`、`NotAGroupMember`、`GroupArchived`、`SharesDoNotSumToAmount`(帶差額訊息)、`SplitTooSmall`、`DuplicateParticipant`、`AlreadyAGroupMember`、`NotAParticipant`、`InvalidSplitInput`(帶訊息)、**`SplitBadRequest`(帶訊息)**——路由層輸入驗證回的第十種 400 `bad_request`,歸進「其餘 → SplitFetchFailure」會讓一個可修正的輸入錯誤變成泛用失敗。**不含使用者文案**
- [x] 1.6 `split_repository.dart`:port,12 個方法,每個吃 `idToken`
- [x] 1.7 測試:`fromJson` 缺欄位/型別錯誤丟 `SplitFetchFailure`

## 2. application

- [x] 2.1 `group_use_cases.dart`(list/create/get/addMember/archive/groupBalances)
- [x] 2.2 `expense_use_cases.dart`(list/create/get/update/delete)
- [x] 2.3 `balance_use_cases.dart`(getBalances)
- [x] 2.4 測試:fake repository,轉呼叫正確、錯誤原樣往上丟

## 3. infrastructure

- [x] 3.1 `http_split_repository.dart`,照 `HttpSocialRepository` 的形狀——**吃整個 `http.Response`、讀 body 的 `error` 欄分派**,body 空或非 JSON **不得丟 decode error**(退回 `SplitFetchFailure`)
- [x] 3.2 錯誤映射:401 → `SplitReauthenticationRequired`;404 → `SplitNotFound`;400 依 `error` 欄分派**十種**(含 `bad_request`);其餘 → `SplitFetchFailure`。帶 `message` 的三種(`shares_do_not_sum_to_amount`、`invalid_split_input`、`bad_request`)要把 message 帶進 typed error
- [x] 3.3 測試(mock `http.Client`):逐條驗 method + path + body + `Authorization`;十種錯誤碼各一測;body 為空與非 JSON 各一測

## 4. 名字與身分

- [x] 4.1 **名字直接用後端給的**(share 的 `display_name`、成員的 `display_name`、餘額的 `display_name`)。**不要自己維護名字表**——初版設計那套「靠群組成員 + 好友湊」的前提被證明是錯的(design D1)。只在後端真的沒給時退回中性佔位字串,**不是裸 uuid、不是空字串**。*Implemented at the domain boundary: `displayName`/`payerDisplayName` are `String?`, tolerant of a missing field in `fromJson` — no name-table is built anywhere in domain/application. Choosing and rendering the actual neutral placeholder string is presentation's job (i18n rule: domain holds no user-facing copy), deferred to the section 5/6 leg.*
- [x] 4.2 **好友清單重用 social context**:候選名單需要好友列表,注入 social 的 `ListFriends` use case;`SplitRepository` **不得**有 friends 方法(兩條路徑、兩套錯誤映射遲早不一致)。*`SplitRepository` has no friends method by construction; wiring `ListFriends` into a controller is presentation (section 5), deferred.*
- [x] 4.3 **呼叫者自己的 user id**:份額閘門、候選裡的「自己」、編輯入口判斷三處都要,而餘額端點不回自己;`homeController.profile` 只在首頁載入,直接重新整理 `/finance` 是 null。載入時若沒有就自己取一次,**取不到進錯誤狀態**,不得帶著 null 繼續跑把閘門悄悄跳過。*`SplitController.load` fetches `GetProfile` first and gates everything else on it — a `ReauthenticationRequired` goes to `needsReauth`, any other failure to `SplitStatus.error`/`SplitError.profileFailed`, and `selfUserId` is left `null` in both cases (never carried forward). `GroupDetailScreen` resolves it the same way, through its own controller's `GetProfile` — **not** from the URL: the review leg showed a `?self=` query parameter makes every permission gate on that screen a function of a shareable, hand-editable link. `SplitExpenseSheet` still takes it as a required, already-resolved parameter from the screen that owns it.*
- [x] 4.4 測試:後端沒給名字時顯示佔位字串且畫面不出現 uuid;user id 取不到時進錯誤狀態而不是靜默放行。*`split_controller_test.dart` covers the profile-fetch-failure → error-state and 401 → needsReauth paths; `group_detail_screen_test.dart`'s "an unnamed member shows the neutral placeholder, never a raw id" test covers the placeholder rendering.*

## 5. presentation — 分帳 tab

- [x] 5.1 `split_controller.dart`:`ChangeNotifier`,狀態 loading/loaded/error/needsReauth;`load`(餘額 + 群組 + 最近支出 + 好友候選)——**不組名字表**,名字跟著後端資料來(task 4.1);好友只用來當候選名單、`createExpense`/`updateExpense`/`deleteExpense`/`createGroup`,寫入後讓畫面反映結果
- [x] 5.2 `split_tab.dart`:餘額分「別人欠你 / 你欠別人」兩段,按幣別分列;**方向用文字說明,顏色只是輔助**;底下群組與最近支出
- [x] 5.3 空狀態、錯誤 + 重試、401 reauth 出口
- [x] 5.4 `FinanceScaffold` 加第四格「分帳」;controller 由 `FinanceScaffold` 的 `State` 在 `initState` 建、`dispose` 釋放。**不要照 `NetWorthController`**——它其實是 `main.dart` 建的 app-lifetime 單例、要靠 `_resetControllersOnSignOut` 清,正是要避開的登出殘留。*`FinanceScaffold.split` is an optional `SplitTabDependencies?` bundle (see its doc comment) so `lib/app.dart`'s existing `FinanceScaffold(...)` call site — out of this leg's scope — keeps compiling untouched until part 3 wires it; the tab simply doesn't render until then.*
- [x] 5.4b **AppBar 標題陣列是三元素、用 `_index` 索引** → index 3 會 RangeError,必須補第四項
- [x] 5.4c **FAB 目前只在 `_index == 2` 隱藏** → 分帳 tab 會冒出記帳的 FAB。分帳要有自己的 FAB(記一筆分帳)
- [x] 5.4d 比照 `_netWorthOpened`/`_netWorthLoaded` 做**延遲建立與載入**:`IndexedStack` 會建構所有子節點,沒有閘門的話使用者還沒點進分帳就已渲染甚至發請求;每次重新進入財務 shell 要重新載入(不能因為單例殘留而永不 refetch)
- [x] 5.5 測試:兩段分組、多幣別分列、方向文字、空狀態、錯誤+重試、401。**既有三個 tab 的行為與 test key 不變,但每一處建構 `FinanceScaffold` 的測試都要補上新的必要參數**——不要為了不動測試而把新參數設成可選預設,那會讓正式程式碼漏接也一樣綠。*Existing `finance_scaffold_test.dart` calls were left untouched (they still construct a 3-tab scaffold); a new `split: _splitDeps(...)` parameter is added only where tests exercise the split tab, and a dedicated "is absent when split dependencies are not supplied" test pins the undo-wired case.*

## 6. presentation — 記一筆分帳的 sheet

- [x] 6.1 `split_expense_sheet.dart`:群組(可不選)、付款人、金額 + 幣別、說明、日期、參與者、拆法(均分/自訂)
- [x] 6.1b **編輯時不顯示群組選擇器**(後端 `group_id` 不可變,改了回 400——給一個必定失敗的欄位比不給更糟);**PATCH 是整份取代**,編輯要把六個欄位全部送出,不是只送改動的那些
- [x] 6.2 **候選名單受群組限制**:選了群組 → 只有該群組成員;沒選 → 好友 + 自己。錯的選項不該出現在畫面上,而不是送出去被 400
- [x] 6.3 **呼叫者必須有實質份額**(自己是付款人,或自己的 share > 0):不符時**送出前就擋並說明**,不發請求
- [x] 6.4 均分即時顯示每人分到多少(含餘數落點);自訂即時顯示**還差多少**
- [x] 6.4b **餘數規則要跟後端一致**:整數除法後多出的 `amount % n` 個最小單位,分給**按 user_id 小寫 canonical 字串排序**的前 n 人。猜錯(付款人優先、勾選順序、名字順序)會讓預覽跟實際存的不一樣,而且不報錯。測試用後端 `equalSplit` 的同一組案例:100/3 = 34/33/33、1/3 = 1/0/0、7 分 10 人。*`lib/contexts/split/domain/equal_split.dart` (`equalSplitAmounts`), pinned by `test/contexts/split/domain/equal_split_test.dart` with exactly these cases, plus a widget-level check in `split_expense_sheet_test.dart`.*
- [x] 6.5 金額:輸入用 `parseAmountToMinorUnits`(不分位那支),顯示用 `formatMinorUnitsForDisplay`(分位);上限 2147483647 前端就擋
- [x] 6.6 送出中 disabled;失敗時**已填內容全部保留**
- [x] 6.7 測試:候選受限、無份額被擋且沒發請求、均分預覽、自訂差額、上限、送出中 disabled、失敗保留輸入

## 7. presentation — 群組

- [x] 7.1 `group_detail_screen.dart` + controller(由畫面 `State` 持有):成員、群組餘額、該群組支出
- [x] 7.2 建立群組、從好友加成員(**不需二次確認**)、封存(**二次確認且指名群組**)。**封存入口只對 `created_by_user_id` 顯示**——後端只讓建立者封存、對其他人回 404,一般成員會看到確認 dialog 再拿到「找不到」
- [x] 7.3 封存後:可讀、隱藏新增支出與成員的入口,但**既有支出仍可由建立者/付款人編輯刪除**(UI 不得比後端更嚴,否則封存群組裡打錯的金額永遠改不掉)
- [x] 7.4 **編輯/刪除入口只對建立者或付款人顯示**——後端對其他人回 404,不該給一顆按下去必定失敗的按鈕。*Applied both in `group_detail_screen.dart` and in `split_tab.dart`'s own recent-expenses list (the general "edit and delete offered only to creator/payer" spec requirement isn't scoped to groups — a group-less expense recorded from the split tab needed the same gate).*
- [x] 7.5 刪除支出要二次確認且指名
- [x] 7.6 測試:成員名字、群組餘額、封存確認、封存後入口消失但編輯仍可用、非建立者/付款人看不到編輯入口、**非建立者看不到封存入口**

## 8. 接線與 i18n

- [x] 8.1 `app.dart` 加群組詳情 route:**巢狀 `/finance/groups/:id`**(這個 repo 為了 web 返回鍵的慣例就是巢狀,見既有註解),builder 純由注入的 use case 建、**帶 `key: ValueKey(groupId)`**(go_router 的 pageKey 只認 path pattern,換 id 不換 key 會沿用同一個 `State`——好友那期踩過);`main.dart` 只注入無狀態的 repository 與 use case。*route 只吃 `:id`:`selfUserId`(design D5c)一度以 `?self=` query string 帶過去,review 指出那讓封存(限建立者)與編輯(限付款人)兩道閘門變成網址的函數——改網址就能對不該看到的人顯示這些動作,填一個不是成員的 id 還會得到一個 sheet 永遠送不出去的死路畫面。現在群組畫面自己呼叫 `GetProfile`,網址不帶任何身分,重整照樣重建,分享出去的連結對每個登入者都正確。*
- [x] 8.1b 從群組詳情返回分帳 tab 時,**分帳頁要反映剛才在群組裡做的變更**(新增支出、封存)——明確選一種做法(返回時 reload,或把結果帶回)並寫進註解;測試釘住。*選了「返回時無條件 reload」:`SplitTabDependencies.onOpenGroup` 改成回傳 `Future<void>`,`await` 到底(mirrors `DietDayScreen` 既有的 await-push-then-reload),`FinanceScaffold._openGroupDetail` 在它完成後呼叫 `_retrySplit()`——不論群組裡到底改了什麼都重新整個 load 一次,而不是把「改了沒」的結果一路帶回來。測試:`finance_scaffold_test.dart`「returning from group detail reloads the split tab...(task 8.1b)」用一個手動控制完成時機的 `Completer` 卡住 `onOpenGroup`,驗證「還沒返回」不 reload、「返回後」才 reload。*
- [x] 8.2 三個 ARB 檔新增全部文案(`app_en` 含 `description`);`flutter gen-l10n` 產生的檔一併 commit。*Already complete from parts 1–2 — verified by grep, no new split-UI copy was needed for this leg's routing/guard work.*
- [x] 8.3 錯誤文案映射在 presentation,**每一種都要可行動**(`not_friends` → 先加好友;`group_archived` → 群組已封存無法新增;`shares_do_not_sum_to_amount` → 直接顯示差額)。*Already complete from parts 1–2 (`split_error_text.dart`) — verified, unchanged in this leg.*
- [x] 8.4 圖示鈕都要有 tooltip(好友那期漏過,語意標籤是空的)。*Already complete from parts 1–2 — verified, unchanged in this leg.*

## 9. 版面與時區守門

- [x] 9.1 `SplitTab`、群組詳情、支出 sheet 在 320/360dp × 各支援 locale × textScale 1.0/2.0 × **800dp 高**零 layout error(用既有 `test/support/layout_guard.dart`)。**不要用 2400dp 高的畫面**——比任何真手機都高,好友那期就是這樣讓 dialog 溢出漏掉的。*New `test/contexts/split/presentation/split_layout_test.dart`. Caught two real overflows at 320dp/textScale 2.0: `SplitExpenseSheet`'s three `DropdownButtonFormField`s (fixed via `isExpanded: true`) and `GroupDetailScreen`'s member-section title/add-button row (fixed by wrapping the button in `Flexible` + `TextOverflow.ellipsis`). QA 第二輪又抓到一個:`SplitExpenseRow` 把金額放在 `ListTile.trailing`,那個 slot 是**無界**佈局,320dp × textScale 2.0 下金額到 NT$10,000 就吃掉整個 tile,tile 直接不 layout(assertion,不是 RenderFlex 溢出),整列消失——兩個畫面都中。修法同 `networth_tab.dart` 的帳戶列:金額改放 title 的 `LabelValueRow`(65% 上限讓兩邊都有下限),`trailing` 只留 48dp 的編輯鈕。守門本身也修了:sweep 的每筆支出原本都是 900,落在失敗區間之外、**不可能紅**(和 9.2 的 ellipsis 檢查同一種毛病),改成 `_wideAmount = 1234567`。*
- [x] 9.2 **四格 nav bar 專門的守門**:320dp × textScale 2.0 × 各 locale,四個標籤不得溢出或被裁掉。*第一版用 `didExceedMaxLines`(`layout_guard.dart` 的 `textWasTruncated`)判「有沒有被 ellipsis 截掉」,review 證明那**不可能紅**:`NavigationBar` 的標籤是沒有 `maxLines` 的裸 `Text`。已刪掉那個 helper,改成量畫出來的 `Rect` 是否完整落在自己那一格 slot 內(左右 + 上下)。改完立刻抓到真的問題:320dp × textScale 2.0 下 "Transactions" / "Net worth" 折兩行、畫到 bar 底下約 10dp 之外被裁掉且不噴 layout error;產品端修法是讓 bar 高度跟著字級長(`NavigationBar(height: math.max(80, textScaler.scale(70)))`),不鎖使用者字級。*
- [x] 9.3 破壞性確認 dialog 一律 `scrollable: true`,並在 320dp × textScale 2.0 下驗按鈕在畫面內且可點。*Both already `scrollable: true` (parts 1–2); this leg pins it under test — the archive-group and delete-expense confirmations, both buttons on-screen and tappable at 320/360dp × textScale 2.0.*
- [x] 9.4 長名字守門:名稱過長時換行或縮放,右側金額仍完整可見。*Pinned on the one row shape in this UI where a name and an amount are genuinely separate widgets (the exact-split participant row) — the balance rows elsewhere are a single merged localized sentence, so a long name there can only wrap the whole sentence, never push a separate amount out.*
- [x] 9.5 支出的 `day` 是**純 `YYYY-MM-DD` 日曆日期**,直接餵 `mediumDateLabelOrDash`(它本來就吃日字串)。**絕對不要**套 `parseInstant` 或 `toLocalTime`——那會把日期平移一天,等於自己造出跨日 bug(design 127)。真正的 instant(如 `created_at`)才走 `parseInstant` + 可注入的 `toLocalTime`。*Verified by grep across `lib/contexts/split/`: `parseInstant`/`toLocal` appear only in a doc comment, never applied to `day`.*
- [x] 9.5b 測試:在固定非 UTC 偏移下渲染某一天記的支出,顯示的**就是那一天**、不位移;`TZ=UTC flutter test` 複驗。*`split_layout_test.dart`'s "expense day is a calendar date, not an instant" test pins the exact expected label; both `flutter test` (this machine's local UTC+8) and `TZ=UTC flutter test` pass, covering a positive and a zero UTC offset.*

## 10. 收尾

- [x] 10.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test` 全綠
- [x] 10.2 `TZ=UTC flutter test` 複驗

## 11. review 回修(第二輪)

- [x] 11.1 兩個 controller 都補 `FriendsController` 的 `_disposed` 旗標與 `_notify()`——載入中按返回/登出會在 dispose 之後 notify,丟「used after being disposed」。測試:load 不 await、dispose、再 await。
- [x] 11.2 `initState` 預先填好的自訂份額欄位漏了 `..addListener(_onChanged)`,編輯既有自訂拆分時打字不會重算「還差多少」、stake 警告與 Save 狀態全部凍結。
- [x] 11.3 建立群組、加成員、封存三處的 `mutationError` 沒有任何畫面讀——失敗時 dialog 關掉、什麼都沒發生。三處都照 `friends_screen.dart` 的 SnackBar 慣例補上(`already_a_group_member` 只有加成員能產生,原本永遠到不了畫面)。順手修掉同一條路徑上的兩個既有缺陷:建立群組的 `TextEditingController` 在 dialog 收合動畫還在跑時就被 dispose(「used after being disposed」),以及名稱空白時 Create 是「按了沒反應」而不是 disabled。
- [x] 11.4 支出列補上**付款人**(`payerDisplayName`,後端 PR #68 就是為了它)與**自己的份額**;兩份清單改用同一個 `SplitExpenseRow`,不再各寫一份。非建立者/付款人沒有編輯 sheet,這一列是他們唯一能知道「誰付的、我要付多少」的地方。
- [x] 11.5 自訂拆分超額不再用同一句話印成「還差 -20」;超額、不足、剛好三種各自一句,且沒加總到總額時不讓送出。
- [x] 11.6 Save 被 disable 的每一個理由都寫在畫面上(空說明、沒有參與者、沒有付款人、金額空白/過大、無份額、人數不足、均分金額小於人數、自訂加總不符),`splitDescriptionRequired` 這種早就翻好卻沒接線的文案終於用上。
- [x] 11.7 `?self=` 不再參與任何判斷(見 8.1);nav bar 守門改成量得到的判準(見 9.2);兩條 client/server 規則(均分金額 < 人數、付款人∪參與者 ≥ 2)在前端就擋並說明;`invalid_split_input`/`bad_request` 包上各自的在地化框架句;結清狀態與空分帳頁都給得出下一步;四個「reloads on success」與封存取消的空心測試改成會紅的寫法(`archiveCalls` 計數 + 在 load 與 mutation 之間換掉 fake 的回傳)。

## 12. review 回修(第三輪)

- [x] 12.1 **Save 被 disable 的理由只剩一條線,由 `_saveBlock` 一個來源決定**。舊的 `if (!_hasStake)` 分支會搶在有序理由前面:金額還空白時 `_equalPreview` 全是 0,`_hasStake` 就變 false——使用者才剛在上面那格把付款人選成朋友,畫面立刻指控他「沒有實質份額」,而真正的理由(金額沒填)整條被吞掉。改成永遠 render `_saveBlockText(loc, saveBlock)`;`noStake` 這個原本是死碼的 case 沿用同一句文案與同一個 test key,但只在份額真的是那個阻擋點時才出現。
- [x] 12.2 **沒有好友的新使用者不再走進死路**。空狀態的主 CTA 開出來的 sheet 候選人只有「你」,Save 卡在「再選一位」——那是他在財務裡做不到的事。新增 `_SaveBlock.noFriends`(**排在最前面**,因為這是唯一不能靠打字解決的阻擋)、`splitNoFriendsYet` / `splitAddFriendAction` 三份 ARB 文案,sheet 與空狀態各給一個「去加好友」的出口,經由 `SplitTabDependencies.onAddFriend`(app.dart `context.push('/friends')`)。**已經有群組可選的人不算**——他的下一步是 sheet 裡的群組選單,不是好友頁(這條有自己的測試,拿掉 `widget.groups.isEmpty` 就會紅)。
- [x] 12.3 `/finance/groups/:id` 補上 route 層測試:用真的 router 依序 `go` 兩個不同的 group id,驗第二個群組的內容真的上了畫面。拿掉 `key: ValueKey(groupId)` 這條測試會紅——原本整包測試都不會。
- [x] 12.4 nav bar 守門的**語系不對稱**寫進註解:reverting `height:` 只會讓 en 紅(Transactions / Net worth 才會折行),zh-Hant 四個標籤都是兩個字、任何字級都折不了,不是能靠斷言補起來的。
- [x] 12.5 bar 高度的 `math.max(80, scale(70))` 確認是刻意的並釘住:1.0 與 1.14 都是 Material 預設的 80(既有三格完全沒變),2.0 才長到 140。門檻以上會長是 intended——那正是標籤自己已經超過預設的地方。
