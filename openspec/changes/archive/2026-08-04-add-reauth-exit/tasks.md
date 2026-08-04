# Tasks

**這個 change 的價值是「不再有沉默的死路」,不是「加了一顆按鈕」。** 驗證要證明每個呼叫點都真的有出口,不是證明共用元件會渲染按鈕。

## 0. 盤點(動手前先做完)

- [x] 0.1 **逐檔重數 `AsyncStateScaffold` 的呼叫點**,列出每一處:檔案、有沒有傳 `appBar`、目前有沒有 auth 依賴、`reauthMessage` 傳的是什麼。proposal review 已經逐檔驗過一輪,更正了三個數字(沒 appBar 的是 5 不是 6、`care_history` 有傳、手寫出口是 8 份不是 4 份);15 與 10 被確認正確。**仍然自己再數一次**——這個 change 的盤點已經錯過一輪,而且錯的是最核心的那個「為什麼」。
- [x] 0.2 確認每個要新增建構參數的畫面**實際的建構點數量**(design 說各只有 1 個,自己數)。

## 1. D3 先測試後實作 —— 這條不准反過來

- [x] 1.1 **先寫測試**:在 go_router 環境下,從一個 push 上去的畫面進入 reauth 狀態,按下「重新登入」,斷言(a)`signOut` 被呼叫、(b)最終停在登入頁、(c)原本那個 push 上去的畫面**不在** widget 樹上。
- [x] 1.2 用這個測試的結果決定 `onSignInAgain` 的呼叫點實作是單純 `signOut` 還是 `signOut` + pop。**不要先寫實作再補測試**——CLAUDE.md 的 Sign-out-and-close 段描述的是 go_router **之前**的架構,直接照抄可能是多餘的,也可能是必要的,不知道就是不知道。
- [x] 1.3 把 1.1 的結論寫進 `async_state_scaffold.dart` 的 doc comment(以及,如果結論是「不需要 pop」,寫明為什麼——否則下一個人會照著 `friends_screen` 再抄一次)。
- [x] 1.4 `friends_screen` 的 `_signOutAndClose` 若因此顯得多餘,**本 change 不動它**(CLAUDE.md 第 3 條),記進 follow-up。

## 2. 共用元件

- [x] 2.1 `AsyncStateScaffold` 新增 `required VoidCallback onSignInAgain`。
- [x] 2.2 reauth 分支改為:置中 `Column(mainAxisSize: min)` → 說明文字(`textAlign: center`) → `SizedBox(height: 16)` → `FilledButton`。**版面以 `friends_screen.dart:333-343` 為準**,先去讀那一處。那 8 份手寫的並不一致(`food_search_screen.dart:308` 與 `:498` 用 `OutlinedButton`),不要「找一份來抄」。
- [x] 2.3 按鈕文案由**呼叫點**傳入還是元件內查 l10n?**結論:元件內查。** 先做成呼叫點傳入(跟 `reauthMessage` 一致),code review 指出 `card_error_retry.dart` 是同形狀的最近鄰居而做法相反——訊息由呼叫點給、按鈕文字自己查 `loc.retry`——所以「`shared/widgets` 不該假設呼叫點的 l10n」這個理由在 repo 裡站不住(19 個共用元件有 7 個 import `AppLocalizations`)。改成內部查表,並補一條對 ARB 查表斷言的測試:查錯鍵(`loc.retry`)與寫死英文字面值兩種突變都驗過會紅。`reauthMessage` 維持呼叫點傳入,因為它早於這個 change,不是刻意要跟按鈕不一致。
- [x] 2.4 按鈕帶固定 `Key`(共用元件只有一份實作,不需要 caller 提供 key)。

## 3. 共用元件的測試

- [x] 3.1 reauth 狀態下訊息與按鈕同時出現,按鈕可點,點了會呼叫 callback。
- [x] 3.2 `isLoading` 與 `isReauth` 同時為 true 時顯示 loading、**沒有**按鈕(既有優先序不變)。
- [x] 3.3 **沒有 `appBar`** 時按鈕仍存在且 `hitTestable`——這是那 5 個站點的守門(其中 `DailyTargetScreen` 是唯一畫面上真的一個可按之處都沒有的)。
- [x] 3.4 **每一條各自突變**:把修法拿掉(移除按鈕、把優先序對調、把按鈕塞進 appBar 才有的分支),確認**對應那一條**紅。任何一條找不到能讓它紅的突變就不要留著它。

## 4. 十五個呼叫點

- [x] 4.1 每個呼叫點傳入 `onSignInAgain`。10 個沒有 auth 依賴的畫面新增建構參數,從已持有 `authRepository` 的 shell/router 串下來。
- [x] 4.2 **不要**把 `AuthRepository` 整個傳進畫面。傳 `VoidCallback` 而不是 `SignOut` use case:出口可能需要「登出**並且**導航」(視 D3 的測試結論),而導航不該由 use case 擁有。**這是刻意偏離** CLAUDE.md settings 那條「傳 use case」的先例,理由如上。
- [x] 4.2b 若 D3 的結論是「登出後還要導航」,15 個 closure 都會在 await 之後碰 `BuildContext`。**在 shell 層寫一個共用 closure 往下傳**,不要讓 15 處各自重新發現 `mounted` 守衛。
- [x] 4.3 那 10 個畫面既有的測試會因為新增 required 參數而編譯失敗,逐一補上。**補的時候不要順手改測試的其他斷言。**
- [x] 4.4 為 **`DailyTargetScreen`** 寫端到端的畫面層測試:進入 reauth → 按鈕在且可點 → 按下 → callback 被呼叫。挑它是因為它是唯一「畫面上一個可按之處都沒有」的站點——別處至少還有 shell 的 AppBar/NavigationBar。只測共用元件不能證明呼叫點真的接對了。

## 5. 驗證

- [x] 5.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test`、`TZ=UTC flutter test` 全綠。
- [x] 5.2 **不可宣稱已實機驗證**。widget test 用的是假 repository 模擬的 401,證明不了真的 PWA 放一小時之後的行為。PR 要寫明這條界線。
