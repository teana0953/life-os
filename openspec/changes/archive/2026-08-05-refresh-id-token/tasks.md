# Tasks

**目標是「請求送出的當下 token 是新的」**,不是「加了一個 callback」。驗證要證明**送出去的值**變了,不是證明 callback 被呼叫了。

## 0. 盤點(動手前先做完,而且要自己數)

- [x] 0.1 列出每一個 `final String idToken` 宣告(29 個 / 25 檔)、每一個 `widget.idToken` 使用點(71 個)、**每一個 State 層的快取欄位**(7 個:`finance_scaffold:71`、`health_scaffold:151`、`group_detail_screen:86`、`care_today_screen:227`、`care_items_screen:114`、`care_history_screen:92`、`diet_day_screen:84`)、以及 controller 層的快取(`DictionaryController._idToken`)。**第一版把那 7 個說成 4 個,而且宣稱它們「已經是對的、不要動」——完全反了**;它們是同一個 bug、時鐘短一點。逐檔重數。
- [x] 0.1b 對每一個持有點問:**它是「掛載時取一次存起來」還是「每次用之前才取」?** 只有後者是對的。範本是 `friends_screen.dart:144` 的 `_token()`;`app.dart:374` 那類「取進區域變數」也是對的,只是沒有成形。
- [x] 0.2 把 71 個使用點依「語境」分類:已經在 async 函式裡的、在同步 callback 裡的(要改 `() async`)、直接往下傳給子 widget 的(傳 provider 本身即可,4 處:`app.dart:1193`、`food_search_screen.dart:166`、`today_screen.dart:320`、`:338`)。**最麻煩的不是 `build()` 而是 `dispose()`**(`app.dart:1041`)——那裡不能 await,會限制 D4 的型別選擇。**先分類再動手**,不要邊改邊發現。

## 1. provider 的形狀

- [x] 1.1 決定型別:`typedef IdTokenProvider = Future<String> Function()`(`lib/shared/auth/id_token_provider.dart`,理由寫在該檔 doc:71 處讀作 `await widget.idToken()`、34 個建構點可以直接傳 closure/tear-off,不必包一層物件)。原題::`Future<String> Function()`,還是一個具名的小類別?**做決定並寫理由。** 注意 71 處要讀,可讀性有代價。
- [x] 1.2 空 token 怎麼辦?現在是 `?? ''`,送出去會被後端擋成 401。維持這個行為(它現在有 PR #125 的出口接住),**不要**在這個 change 裡發明新的錯誤路徑。
- [x] 1.3 `AuthRouterNotifier` 移除 `_idToken` 與那個 `try/catch`。**確認移除後 `retry()`、`loading`、`error`、`signedIn` 的行為完全不變**——這是既有行為,要有回歸釘子。注意:現在的程式碼在 `notifyListeners()` **之前** await `idToken()`,移除後通知會早一個 microtask。lib 裡看來無害,但要確認沒有測試依賴那個時序。

## 2. 證明它真的變新了 —— 這是唯一重要的測試

- [x] 2.1 **先寫測試**:注入一個每次呼叫回傳不同值的 provider,讓畫面做兩次請求,斷言**送到 controller/repository 的第二個值是第二個 token**。斷言在**送出的值**上,不是在「provider 被呼叫過」上。
- [x] 2.2 **突變**:把實作改回「建構時取一次存起來」,2.1 必須紅。找不到能讓它紅的突變就代表它證不到那件事。
- [x] 2.3 針對 `diet_day_screen.dart:84` 那個 `late final` **單獨寫一條**:它是唯一一個連重建都換不掉的持有,也是 issue #106 描述的記錄流程所在。
- [x] 2.4 `DictionaryController._idToken`:它在 `load()` 被設定、被**不收 token** 的 `search()` / `toggleFavorite()` 重複使用。**它一定要改**,而修它必然要動 controller 簽章或讓 controller 持有 provider ——**這是刻意突破 3.4 的界線**,不動它字典流程就是壞的。寫一條測試證明第二次 `search()` 帶的是新 token。
- [x] 2.5 **7 個 State 層快取各自一條測試**,證明第二次請求帶的是新 token。`finance_scaffold` 特別重要:它從一個欄位餵 15 個讀取點,含寫入與它建的每個 sheet。

## 3. 不可以壞掉的既有行為

- [x] 3.1 登入/登出的路由行為完全不變。
- [x] 3.2 `_resetControllersOnSignOut` 與 `_scheduleDeepLinkCheck` 的行為不變(它們掛在 notifier 上,而 notifier 這次會被改)。
- [x] 3.3 **禁止這個省事補法**:改完 71 個使用點會破壞 8 個檔案裡的 **34 個建構點**。最省事的補法是 `idToken: () async => _idToken!` —— 它能編譯、review 起來也乾淨,**卻把 bug 原封不動保留下來**。建構點要傳的是真正每次重取的 provider,不是包裝過的快取。改完 grep 一次 `() async => ` 確認沒有這個形狀。
- [x] 3.4 **不要**改 domain port / repository 的簽章。controller 只有 `DictionaryController` 例外(見 2.4),而且要寫明為什麼只有它。

## 4. 過時的註解

- [x] 4.1 `app.dart:369-372` 解釋「為什麼這裡要自己重取」的那段:前提(快照不會更新)改完就不成立。更新它,否則下一個人會照著它做出錯誤結論。
- [x] 4.2 掃一遍其他提到 token 快照的註解,一起更新。**用英文詞去 grep**(`snapshot`、`does not fire`、`token renewal`、`stale`)——這些註解是英文寫的,用中文詞搜不到。**這個 session 已經犯過「只改看得到的那一處、漏掉同一份文件另一節」的錯。**

## 5. 驗證

- [x] 5.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test`、`TZ=UTC flutter test` 全綠。
- [x] 5.2(未驗證真正的過期,只注入假 provider)**不可宣稱已驗證真正的過期**:那要等一小時,測試裡只能注入假 provider。PR 寫明。

## 7. escalated 之後補上的(iteration cap 後的最後一輪 QA)

- [x] 7.1 **`getIdToken()` 換發失敗會拋,而拉取式把它搬到了 71 個沒有防護的呼叫點。** 例外在 controller 被進入**之前**逃逸,所以沒有任何 controller 的錯誤處理會跑 —— 單一次點擊、沒有寫入、沒有任何訊息、項目還在。改動前 `AuthRouterNotifier._subscribe` 的 try/catch 明確擋著這件事(它的註解就寫著「must NOT become an unhandled async error」),而 design D3 說那個 catch「拉取式讓它自然消失」—— **那句話錯了**:catch 消失了,但它的職責還在,只是換了地方。
- [x] 7.2 修法在唯一的收斂點 `_AppState._idToken`(`app.dart`):`try/catch` 回傳 `''`,重現改動前的結果(請求送出 → 後端 401 → reauth 出口)。`IdTokenProvider` 的 doc 原本寫著「This type does not introduce a new error path」,那是假的,已改成對實作的明確要求。
- [x] 7.3 測試驅動真實流程(app → 健康 → 記錄 → 水分 → 快速新增),斷言 `addTokens == ['']` —— **證明請求真的送出去了**,而不是只斷言「沒有例外」(後者在動作無聲消失時也會通過)。突變:拿掉 catch → 紅。

## 8. 五輪 QA 的次級效應鏈(全部已修,逐條可突變驗證)

核心修法(token 用時再取)在 QA 第 1 輪就通過。之後四輪找到的**全部是它引發的次級效應**,而且每一層都是上一層修法造成的:

- [x] 8.1 **重複送出**(7 個畫面)。同步 tap handler 變成 `() async` 之後,controller 的 `status = saving` 要等 token 回來才翻轉,按鈕整趟保持可按。修法:同步旗標 + 接進 `busy`。
- [x] 8.2 **被丟棄的呼叫報告成功**。守衛 return 之後呼叫端照跑,顯示「已移除」+復原鈕而根本沒刪。修法:`_runMutation` 回傳 `Future<bool>`,呼叫端依它中止。
- [x] 8.3 **被拒絕的復原不可恢復,而新文案在說謊**。`SnackBarAction` 在守衛能拒絕前就 latch 並收起。修法:重新顯示同一個提示、復原動作保留。
- [x] 8.4 **`getIdToken()` 換發失敗會拋,而例外在 controller 被進入前逃逸** —— 單次點擊、沒有寫入、沒有訊息。design D3 說那個 `try/catch`「拉取式讓它自然消失」,**那句錯了**:catch 消失了,職責沒有。
- [x] 8.5 **8.4 的修法只守住 7 個 provider 裡的 1 個。** 當時宣稱 `_AppState._idToken` 是「唯一的收斂點、一次涵蓋 71 個呼叫點」——**沒有數過,而且是假的**。另外 6 個(finance / split / care ×3 / health scaffold)各自寫著同一行未守衛的 `await repository.idToken() ?? ''`,餵給它們整個子樹。`CareTodayScreen` 按一次完成就無聲消失;`AddTransactionSheet` 更把儲存鈕**永久鎖死**,輸入的交易只能連同 sheet 丟掉。修法:`guardedIdToken(repository)`,7 處全部委派,typedef doc 明文禁止 inline 寫法。

**這一輪也弄紅了一條既有測試,而那是對的**:`health_scaffold` 那條靠 token 拋例外來證明「`_loading` 會清掉」的測試,前提被守衛消滅了。沒有把 1 改成 2 了事——改成同時斷言「換發失敗不再中止 reload」與「後續 bump 仍有效」,並更新 `health_scaffold` 裡那句已經不成立的註解。

## 9. 未做的第 6 輪 QA(刻意)

五輪 QA **每一輪都找到真的東西**,而且第 4、5 輪比第 2、3 輪更嚴重、更容易觸發 —— **沒有收斂訊號**。停在這裡是刻意的決定,理由是這個 diff(82 檔 / +2699 −506)已經大到無法靠再跑一輪建立信心,而它每輪都在變大。交給 review 與實機。
