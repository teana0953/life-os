## Why

畫面拿到的 ID token 是**建構時抓住的一個字串**,之後永遠不變。`AuthRouterNotifier` 訂閱 `authStateChanges`(**只在登入/登出時發,不含 token 換發**),把當下取到的 token 存進 `_idToken`,`app.dart:438` 再餵給所有 route builder。全 repo 有 **29 個 `final String idToken` 宣告(25 個檔)、71 個 `widget.idToken` 使用點**,外加 **7 個 State 層的快取**(`finance_scaffold.dart:71`、`health_scaffold.dart:151`、`group_detail_screen.dart:86`、`care_today_screen.dart:227`、`care_items_screen.dart:114`、`care_history_screen.dart:92`,以及 `diet_day_screen.dart:84` 的 `late final`)與 **1 個 controller 快取**(`DictionaryController._idToken`)。

Firebase ID token 壽命 1 小時。PWA 開著不動或從背景喚醒超過那個時間之後,任何寫入都帶著死 token → 401。**這是 issue #106 的病因**;PR #125 修的是「撞到之後出不去」,這個 change 修「不該撞到」。

codebase 早就知道:`app.dart:369-372` 的註解一字不差寫著 `authStateChanges`「does not fire on token renewal」,並因此讓 care-today 的靜默重載自己重取。

**但「自己重取」的那些地方,大多數其實也是壞的。** 這份提案的第一版寫著「那 7+ 處已經自己重取,它們現在就是對的,不要動」——**那是錯的,而且方向相反**。逐檔看過之後:`finance_scaffold`、`health_scaffold`、`group_detail_screen` 與三個 care 畫面都是 `String? _idToken` **在掛載時取一次就快取**,`finance_scaffold` 更從那個欄位餵 15 個讀取點(含寫入與它建的每個 sheet)。它們是同一個 bug、只是時鐘短一點,而且 `FinanceScaffold` / `HealthScaffold` 正是 issue #106 描述的那種長時間掛著的殼。每次重取的地方確實有(`app.dart:374`/`:1226`、`invite_screen:73/79`、`reminder_settings:47/68`、`chaodays_import:110` 取進區域變數),而 **`friends_screen.dart:144` 的 `_token()` 是最乾淨的形狀**,拿它當範本。分界不是「有沒有自己取」,是**「取一次存起來」還是「每次用之前才取」**。

## What Changes

**把畫面持有的 `String idToken` 換成一個取 token 的 callback,在每次請求前才取。** `getIdToken()`(無參數)在 token 快過期時會自己換發,所以「用時才取」就消滅了過期問題,不需要訂閱、不需要推送、不需要 resume hook。

- 29 個宣告改型別,71 個使用點改成 `await widget.idToken()`。
- **7 個 State 層的快取欄位一併改掉**(見上)。這不是可選項:留著它們等於改完之後兩個最大的殼仍然壞著。
- **`DictionaryController._idToken` 也要處理。** 它在 `load()` 時被設定、被不收 token 的 `search()` / `toggleFavorite()` 重複使用,所以修它需要動 controller 的簽章或讓 controller 持有 provider ——**這一點刻意突破 D2 的「只改 presentation」界線**,理由是不動它就修不好字典流程。
- `AuthRouterNotifier` **移除 `_idToken`**:它只剩 loading / error / signedIn 供路由判斷。
- 更新 `app.dart:369-372` 那段解釋「為什麼要繞過快照」的註解——前提改掉後它會誤導。

### 為什麼不是訂閱 `idTokenChanges()`

先前的方向是訂閱推送,已被 spike **實測推翻**:

畫面收的是建構時抓住的字串,新 token 要送達就得讓 widget tree 重建,而 `AuthRouterNotifier` 正是 go_router 的 `refreshListenable`。spike(對照組驗證)顯示:**`refreshListenable` 上發一次通知,`await context.push<T>()` 的 future 就永遠不會返回**——畫面還在、Navigator state 還在,只有 completer 變成孤兒。repo 裡兩個 awaited push **都在 `diet_day_screen.dart`**(`:117`、`:147`),形狀是 `if (result == true) await _reloadCurrentDay();`。換發若發生在使用者挑食物那段時間,回來之後那天的畫面不會重載,**看起來就像剛記的一餐沒存進去**。訂閱等於每小時把記錄飲食流程上膛一次。

拉取式沒有這個問題,而且讓 proposal review 提出的五條 blocking 有四條**因為不存在而消失**(快照被清成 null、兩處凍結、go_router 孤兒、resume 補取)。

## Capabilities

### Modified Capabilities

- `login-flow`:畫面取得 ID token 的方式從「登入時的快照」變成「每次請求前解析」。

## Impact

- 25 個檔、29 個宣告、71 個使用點,加上它們的測試。機械性但面積大。
- **不改** controller / domain port / repository 的簽章(它們仍收 `String idToken`)。改那三層會多動 20 個 port、20 個 infra 檔(110 處)、26 個 controller(94 處),而目標是「請求時 token 是新的」,S1 就達成了。分層的怪異(presentation 在處理 token)是既有的,不在這次範圍。
- **危險的省事補法**:改完 71 個使用點會破壞 8 個檔案裡的 **34 個建構點**(其中 finance_scaffold、group_detail_screen、care_items_screen 不在那 25 檔裡)。最省事的補法是 `idToken: () async => _idToken!` —— 它**能編譯、review 起來也乾淨,卻把 bug 原封不動保留下來**。tasks 明令禁止這個形狀。
- **無法驗證真正的過期**:要等一小時。測試只能注入假的 provider。PR 寫明。
