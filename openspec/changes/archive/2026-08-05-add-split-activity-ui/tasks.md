# Tasks

**這個 change 只有一個真正困難的地方:還款方向的渲染。** 其餘(分頁、清單、空狀態)都是這個 repo 做過很多次的形狀。**寫錯方向的話畫面看起來完全正常,只是把「你還了錢」說成「別人還了你錢」。**

## 0. 盤點

- [x] 0.1 讀後端的契約:`GET /api/split/activity?limit=&cursor=` 的回傳欄位、八種 `type`、`actor_is_payer` 的語意(**相對於 actor**)、`next_cursor` 為 null 的意義。**自己讀 backend 的 route 與 domain 型別,不要只信這份文件。**
- [x] 0.2 確認現有「最近活動」清單(`split_tab.dart:110-116`)的位置與行為——它**留著不動**,新分頁是另一個東西。

## 1. 方向與主詞 —— 純函式,先寫測試

- [x] 1.1 **先寫表格驅動的測試**,把六種情況全部釘住:

  | 讀者是 | `actorIsPayer` | 應顯示 |
  |---|---|---|
  | actor | true | 你付給 B |
  | actor | false | B 付給你 |
  | counterpart | true | A 付給你 |
  | counterpart | false | 你付給 A |
  | 第三人 | true | A 付給 B |
  | 第三人 | false | B 付給 A |

- [x] 1.2 **每一種都要有能讓它單獨變紅的突變**(對調布林、把 counterpart 當成 actor、第三人分支拿掉)。**任何一種找不到讓它單獨紅的突變,就代表那一列沒被覆蓋。**
- [x] 1.3 邏輯抽成純函式(輸入:事件 + `selfUserId`;輸出:誰付、誰收、主詞要不要用「你」)。**不要散在 widget 的 build 裡**——散進去就只能靠 widget test 間接驗,而那正是這種錯誤躲得掉的地方。
- [x] 1.4 八種事件 × 你/別人 的主詞同樣要有測試,但不需要六種組合那麼細。
- [x] 1.5 **第三人那一行只在群組結清成立**——無群組的結清受眾就是 {建立者, 付款方, 收款方},不會有第三人。測試名稱要寫清楚是群組情境,否則下一個人會以為它涵蓋了無群組。

## 2. 分頁

- [x] 2.1 第一頁在**分頁被開啟時**載入,不是 app 啟動時。
- [x] 2.2 捲到底載下一頁。
- [x] 2.2b **`next_cursor` 不是 has-more 旗標**:它只在頁面不滿時才是 null,最後一頁剛好滿會回 cursor、**下一次請求才回空**。所以正常結束會多打一次拿到空頁——**那不是錯誤也不是空狀態**,已載入的內容要留著。
- [x] 2.3 **先寫正面對照,再寫終止條件。** 這個 repo 沒有「捲到底自動載下一頁」的既有實作(但**有** `ScrollController` 的用法可以參考:`food_search_screen.dart:619/698/758` 在讀 `maxScrollExtent`)。因為沒有 load-more 的先例:
  - (a) **捲到底會觸發下一頁請求** —— 沒有這條,(b) 在清單根本沒溢出的測試視窗裡是恆真的,**任何實作都會通過**。
  - (b) 拿到 `next_cursor == null` 之後不再請求。
  - **兩條各自突變驗證**;(a) 的突變是拿掉觸發、(b) 的突變是拿掉判斷。
  - **實作陷阱**:底部的 load-more spinner 會讓 `pumpAndSettle` 逾時,那條測試要用 `pump(Duration)`。撐開溢出用 `setSurfaceSize`(`split_layout_test.dart:515` 有先例),驅動捲動用 `scrollUntilVisible` / `drag`(`group_detail_screen_test.dart:151`)。
- [x] 2.4 **不可重複用同一個 cursor 請求。** 同上,要有測試。這跟 2.3 是無限迴圈最常見的兩種寫法。
- [x] 2.4b `limit` 的實際行為(讀後端讀出來的):未帶時預設 50、超過 100 靜默夾住、非數字回 400。**前端不要一次要很多。**
- [x] 2.5 下一頁載入失敗**不要把整頁變成錯誤**——保留已載入的,底部給可重試的提示。

## 3. 畫面

- [x] 3.1 分帳分頁多一層:總覽 / 變更紀錄。**不要動 `FinanceScaffold` 的底部導覽**(會變第三層)。
- [x] 3.1b **分頁切換要在 `SplitTab` 的 loading / 錯誤 / 空狀態分支之上**——放在下面的話,總覽載入失敗會把變更紀錄一起變成錯誤頁,而它們是兩份獨立的資料。
- [x] 3.1c **`split-fab` 在變更紀錄分頁怎麼辦?做決定並寫理由。** 留著或隱藏都可以,但不能沒想過。
- [x] 3.2 每列的形狀對齊既有的 `SplitExpenseRow` / `SettlementRow`,但**不帶編輯 affordance**,而且**不可點擊**。
- [x] 3.3 刪除類的事件仍顯示金額與描述(後端存了快照)。**注意:被刪除的結清有金額/幣別/方向,但沒有 note。**
- [x] 3.3b **金額有變動時顯示改前 → 改後。** 後端每一筆修改都記了 `previous_amount`,**就是為了不讓修改變成一句沒有內容的「某人修改了這筆」**。
  **但它不是「金額有變」的旗標**:只改描述/日期/參與者的修改**也會**寫它。判斷用 `previousAmount != amount`,不是 `!= null` —— 否則會渲染出「$2000 → $2000」。**寫一條測試:只改了描述的修改,不顯示金額箭頭。**
- [x] 3.3c **三種群組事件(建立群組、加成員、封存群組)各自要有文案**,不能落到泛用 fallback。
- [x] 3.3d **顯示名稱的 fallback,而且兩者的判斷式不一樣**:
  - `counterpart_display_name` **可為 null** → `?? splitUnknownMember`。
  - `actor_display_name` **不是 nullable**,後端沒名字時填的是**原始 UUID**。所以 `?? splitUnknownMember` 的 `??` **永遠不會觸發**、UUID 照樣顯示 —— 那是一個不可能失敗的守門。**判斷式是 `actorDisplayName == actorUserId`。**
  - 測試要能被突變弄紅(把判斷改回 `??`)。
- [x] 3.4 時間顯示照 `friends_screen` 私有的 `_localDateTimeLabel` 那個形狀(`parseInstant` + `mediumDateLabelOrDash` + inline `DateFormat('HH:mm')`)。**第一版寫的「既有的日期格式 helper」指的是一個不存在的東西。**
- [x] 3.5 loading / 錯誤 / 空狀態 / reauth 沿用既有慣例(`card_error_retry.dart`、`AsyncStateScaffold`)。

## 4. token 與分層

- [x] 4.1 用 `IdTokenProvider`(PR #126 之後的形狀)。**不要**寫 inline 的 `await repository.idToken() ?? ''`——`guardedIdToken` 的 doc 明文禁止,那一行正是先前六處未守衛 provider 的長相。
- [x] 4.2 照 CLAUDE.md 的分層:domain 型別 + repository port、infrastructure 的 `Http*` adapter、application 的 use case、presentation 的 controller + 畫面。

## 5. i18n

- [x] 5.1 所有文案進 ARB,**兩個語系都要**(`app_en.arb` + `app_zh_Hant.arb`),不可有硬寫的字串。
- [x] 5.2 **八種事件 × 你/別人**的文案會很多(修改類還要帶改前→改後,結清類還要帶方向)。**先把完整清單列出來再動手**,不要邊寫邊發現。八種是:建立/修改/刪除支出、建立/刪除還款、建立群組、加成員、封存群組。
- [x] 5.3 這個 repo 有既有 issue #99:ARB parity 零測試。**這次不修那個**,但不要讓兩邊不同步。

## 6. 無障礙

- [x] 6.1 每列要能被讀成一句完整的話(誰、做了什麼、多少錢、什麼時候),不是散落的片段。
- [x] 6.2 刪除類的事件要讀得出「這是已經被刪掉的東西」。
- [x] 6.3 **不要用 `getSemantics` / `bySemanticsLabel` 當作證據**——它們讀快取,證明不了節點真的送到平台語意樹(這個 repo 的既有教訓)。

## 7. 驗證

- [x] 7.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test`、`TZ=UTC flutter test` 全綠。
- [x] 7.2 **不可宣稱實機驗證過**——這批只有 widget test 的證據,而時間軸的排序與分頁在真資料下才看得出來。

## 8. 後續(review 提出、本次刻意不做)

- [ ] 8.1 **「修改」列說不出「改了什麼」**,除了金額以外。目前後端的 `split_activity` 只記了 `amount` / `previous_amount` 這一對,描述、日期、參與者的變更都沒有前後值 —— 前端無從渲染。**要先改後端**(記下變更欄位的前後值),前端才有東西可顯示。
- [ ] 8.2 **刪除與新增在視覺上只差一個單色 icon**。時間軸上「Amy 刪除了晚餐」和「Amy 新增了晚餐」兩列的排版、字重、顏色完全相同,掃視時分不出來。要不要用語意色(error/outline)或別的視覺編碼是設計決定,不是這次的 bug 修正。

## 9. 並發:同一個危害修了三次

`SplitActivityController` 有兩個寫入者(`_loadFirstPage` 與 `_loadMore`),兩者都會賦值 `entries` 與 `_cursor`,而不載入的刷新**刻意**讓 `status == loaded`、`loadingMore == false`、cursor 存活(讀者要繼續看得到清單)——所以 `loadMore` 在整段刷新期間都是可達的。

- [x] 9.1 **第一次**:`_loadingFirstPage` 旗標。只擋三個第一頁入口彼此,**沒擋 `loadMore`**。QA 第 3 輪:捲到底 → 記一筆 → **一筆永久消失**,而且它的 cursor 被丟掉、再也拿不回來。
- [x] 9.2 **第二次**:generation counter。只作廢**先開始**的 `loadMore`;在刷新**之後**才開始的那個記到已遞增的值、檢查通過、照樣覆蓋。QA 第 4 輪:**同一個資料遺失,鏡像順序**。抄的先例(`care_history_controller`)本身是對的,抄漏了 `++`。
- [x] 9.3 **第三次(現行)**:寫下不變式並由結構強制,而不是列舉配對 ——「更後頁的載入永遠不會在第一頁載入進行中執行,而第一頁載入會作廢所有已經在外的更後頁載入」。三個機制各對應一個方向,(a)(b)(c) 各自都有能單獨弄紅的測試。
- [x] 9.4 **移除了兩段自己實作、突變證明是死的程式碼**(`_loadMore` 的 `++`、`_loadFirstPage` 的 await 後檢查):`_loadingFirstPage` 橫跨 `_loadFirstPage` 的每一個 await,所以沒有東西能在它底下遞增;而且那個檢查若真的觸發,會靜默丟掉刷新剛拿到的新頁。QA 第 5 輪逐一建構交錯**驗證了這個論證**。
- [x] 9.5 **前兩次都通過了作者自己的測試與突變驗證,然後被新的交錯打穿。** 這個檔案上,「作者驗過了」已被證明不是充分證據 —— 每一次改動都要用「手動放行回應的假 repository」重新建構交錯,不能靠推論。

## 10. 這一輪未做的(follow-up)

- [ ] 10.1 「修改」那一列說不出**改了什麼**(只有金額對)。動到分攤比例的修改會改變餘額,而那一列的金額沒變、讀起來像什麼都沒發生。**需要後端先記錄更多**。
- [ ] 10.2 刪除與新增在視覺上只差一個單色 icon,金額還是同樣的粗體。這個功能的動機是「餘額變了、不知道為什麼」,關鍵的那筆刪除會淹在例行的新增裡。
- [ ] 10.3 沒有實機驗證:排序與分頁在真資料下才看得出來。
