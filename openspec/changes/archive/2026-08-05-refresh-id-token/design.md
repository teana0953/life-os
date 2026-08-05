# 設計:請求時才解析 ID token(issue #106 的 D1)

## 問題

畫面拿到的 ID token 是**建構時抓住的一個字串**。`AuthRouterNotifier` 訂閱 `authStateChanges`(只在登入/登出時發),把當下取到的值存進 `_idToken`,`app.dart:438` 餵給所有 route builder。Firebase ID token 壽命 1 小時,所以 PWA 開著或從背景回來超過那個時間之後,任何寫入都帶死 token → 401。

`app.dart:369-372` 的既有註解已經寫明這件事,也有一些地方為了繞過它而自己 `await authRepository.idToken()`。**但那些繞道大多也是壞的**:逐檔看過之後,有些地方是對的(`app.dart:374`/`:1226`、`invite_screen:73/79`、`reminder_settings:47/68`、`chaodays_import:110` 每次動作時取進區域變數;`friends_screen.dart:144` 的 `_token()` 是最乾淨的形狀),但`finance_scaffold`、`health_scaffold`、`group_detail_screen` 與三個 care 畫面都是**掛載時取一次就快取**(見 D2 的例外 1)。這個 change 要推廣的是 `friends_screen` 那個形狀,不是「有自己取就算數」。

## 決策

### D1:拉取,不是推送 —— 這條被 spike 推翻過一次

**選:每次請求前解析 token(拉取)。** `getIdToken()` 無參數版本在快過期時會自己換發,所以「用時才取」直接消滅過期問題。

**先前選的是推送**(訂閱 `idTokenChanges()`、讓 notifier 通知、route 重建帶新值下去),理由是「只改一個地方」。它被兩件事推翻:

1. **成本不是「零重建」。** 畫面收的是建構時抓住的字串,新值要送達就得重建 widget tree,而 `AuthRouterNotifier` 正是 go_router 的 `refreshListenable`。訂閱與重建不可分割。
2. **重建會弄壞 awaited push,這是 spike 實測的,不是推論。** 對照組(不發 notify)通過、實驗組(發一次 notify)失敗:`refreshListenable` 上一次通知之後,`await context.push<T>()` 的 future **永遠不會返回**。畫面還在、Navigator state 還在,只有 completer 變成孤兒(go_router 16.3.0 會用新的隨機 `pageKey` 重建 `ImperativeRouteMatch`)。

   repo 裡兩個 awaited push **都在 `diet_day_screen.dart`**(`:117` 開食物搜尋、`:147` 開字典),形狀都是 `if (result == true) await _reloadCurrentDay();`。換發若落在使用者挑食物那段時間,回來之後那天不會重載 —— **看起來就像剛記的一餐沒存進去**。訂閱等於每小時把記錄飲食流程上膛一次。

拉取式沒有這個問題,而且 proposal review 針對推送提的五條 blocking **有四條因為不存在而消失**:

| 推送路線的 blocking | 拉取式 |
|---|---|
| `auth_router_notifier.dart:50-54` 的 `try/catch` 把有效 token 設成 null | 快照整個移除,沒有可清的東西 |
| `diet_day_screen.dart:84` 與 `DictionaryController` 凍結 token | 沒有快照可凍 |
| go_router 每次 notify 弄壞 awaited push | 不新增 notify,不上膛 |
| resume 補取要判斷 token 有沒有變,否則每次前景都重建 | **整條不需要** |

第五條(`PushHealthController` 是 `authStateChanges` 的第二個訂閱者)在拉取式下不受影響 —— 它訂的仍是 auth 狀態,而這個 change 不動那個 stream。

### D2:改到哪一層?

**選:S1 —— 只改畫面(presentation)。**

| 形狀 | 範圍 |
|---|---|
| **S1 畫面持有 provider** | 29 個宣告 / 25 檔 / 71 個使用點 |
| S2 controller 持有 | 再加 26 個 controller 檔、94 處簽章 |
| S3 repository 持有 | 再加 20 個 domain port、20 個 infra 檔(110 處);測試有 104 檔碰到 `idToken` |

S3 在分層上最正確(token 是傳輸層的事,不該出現在 presentation),但測試面積大到會把這個 change 變成一次大重構。目標是「請求送出時 token 是新的」,**S1 加上下面兩個例外就達成了**。presentation 在處理 token 這個怪異是既有的,不是這次造成的,也不在這次範圍。

**S1 的兩個必要例外:**

1. **7 個 State 層的快取欄位**(`finance_scaffold:71`、`health_scaffold:151`、`group_detail_screen:86`、三個 care 畫面、`diet_day_screen:84`)。這份設計的第一版說它們「已經自己重取、是對的、不要動」——**錯得剛好相反**:它們是掛載時取一次就快取,是同一個 bug 的短時鐘版本,而 `FinanceScaffold` / `HealthScaffold` 正是 issue 描述的長時間掛著的殼(`finance_scaffold` 從那一個欄位餵 15 個讀取點)。**拿 `friends_screen.dart:144` 的 `_token()` 當範本**——它是 repo 裡最乾淨的每次重取形狀(其他每次重取的地方是取進區域變數,也對,只是不成形)。
2. **`DictionaryController._idToken`**(controller 層)。它在 `load()` 被設、被不收 token 的 `search()` / `toggleFavorite()` 重用,所以修它必然要動 controller 簽章或讓 controller 持有 provider。**刻意突破「只改 presentation」**,因為不動它字典流程就是壞的。只有這一個 controller 例外,其餘 25 個不動。

**還有一個會靜默保留 bug 的陷阱:** 改完 71 個使用點會破壞 8 個檔案的 34 個建構點,而最省事的補法 `idToken: () async => _idToken!` 能編譯、review 起來乾淨,**卻把快取原封不動包起來**。tasks 3.3 明令禁止,並要求改完 grep 一次確認。

### D3:`AuthRouterNotifier` 的 `_idToken` 移除

改完之後沒有人讀它。連同 `try { … } catch (_) { _idToken = null; }` 一起移除 —— 那個 catch 正是 proposal review 指出「會把還有效的 token 設成 null」的地方,拉取式讓它自然消失,而不是靠修補。

notifier 剩下 `loading` / `error` / `signedIn`,職責變乾淨:**它驅動路由,不保管憑證。**

`retry()`、`loading`、`error`、`signedIn` 的對外行為必須完全不變,要有回歸釘子。

### D4:provider 的型別與空值

- 型別留給 apply 決定(`Future<String> Function()` 還是具名小類別),但要寫下理由 —— 71 處要讀,可讀性有代價。
- **空 token 維持現行語意**:現在是 `?? ''`,送出去被後端擋成 401。不要在這個 change 裡發明新的錯誤路徑;401 現在有 PR #125 的出口接住。

## UI/UX 設計

### 使用者路徑

**誰/情境**:PWA 使用者,把 app 放背景超過一小時,回來記一筆。

**主路徑(修好之後)**:喚醒 → 按儲存 → 送出前解析 token(SDK 判斷已過期 → 自動換發)→ 成功。**使用者什麼都沒看到**,這就是成功的樣貌。

**例外路徑**:換發失敗(沒網路)→ 拿到空字串或舊值 → 後端 401 → 走 PR #125 的 reauth 出口。**沒有新的錯誤路徑。**

**現況(壞掉的)**:喚醒 → 按儲存 → 401 → 整頁換成 reauth → 剛打的數字消失。

### 介面與一致性

**這個 change 不應該有任何可見的 UI 變化。** 沒有提示、沒有 spinner。任何可見的東西都代表做錯了。

唯一可能的可感知影響:每次請求多一次 `getIdToken()`。token 未過期時它回傳快取值(不打網路),所以正常情況下沒有額外延遲;過期那一次會多一趟換發的往返。**QA 要確認那一次不會讓按鈕看起來沒反應**(既有的 saving 狀態應該已經涵蓋,要驗)。

### 狀態設計

- **loading / error / 空狀態**:全部不變,這個 change 不碰它們。
- **登入 / 登出**:行為必須完全不變。

### 可及性/理解性

不適用 —— 沒有新的可見元素。

## 驗收(可觀察的行為)

1. WHEN 畫面在建構後一段時間才發出請求,THEN 送出的是**請求當下**解析到的 token,不是建構時的。
2. WHEN 同一個畫面連續兩次請求而 token 在中間變了,THEN 第二次帶的是第二個 token。
3. WHEN 使用者登入或登出,THEN 路由行為與改動前完全相同。
4. `AuthRouterNotifier` 不再持有任何 token。

## 風險

- **面積大而機械**:71 個使用點 + 7 個 State 快取 + 34 個建構點。最麻煩的同步語境不是 `build()` 而是 `dispose()`(`app.dart:1041`),它會限制 provider 的型別選擇。tasks 0.2 要求**先分類再動手**。
- **測試證錯東西**:很容易寫成「provider 有被呼叫」而不是「送出去的值變了」。tasks 2.1 明訂斷言要落在**送出的值**上,2.2 要求用「改回建構時取一次」這個突變驗證。
- **既有註解會變成誤導**:`app.dart:369-372` 解釋「為什麼這裡要自己重取」,前提改完就不成立。**這個 session 已經犯過「只改看得到的那一處、漏掉同一份文件另一節」的錯**,tasks 4.2 要求 grep 過一遍。
- **無法驗證真正的過期**:要等一小時,測試只能注入假 provider。
- **我在這條路上錯過兩次,兩次都是「很有把握地說錯」**:(1) 先前向使用者推薦訂閱,理由是「3 處 vs 28 檔」,漏掉了重建成本,spike 才發現重建會弄壞 awaited push;(2) 這份設計的第一版說那 7 個快取「已經是對的、不要動」,方向完全相反,照著做會交出一個「71 處都改了、兩個最大的殼還壞著」的 change。**文件裡任何關於現況的斷言都要能對應到逐檔看過的結果,不是 grep 的印象。**
