# 設計:reauth 狀態要有出口(issue #106 的 D2)

## 問題

`AsyncStateScaffold` 的 reauth 分支(`lib/shared/widgets/async_state_scaffold.dart:40-47`)是這樣:

```dart
if (isReauth) {
  return Scaffold(
    appBar: appBar,
    body: Center(child: Text(reauthMessage ?? '', textAlign: TextAlign.center)),
  );
}
```

一段置中的文字,**沒有任何動作**。15 個呼叫點共用它。**這 15 處全部無法行動**:token 已失效,返回、切 tab、重新載入都會再 401,而畫面上沒有任何地方能登出。這才是 issue #106 的「使用者只能滑掉重開」。

「畫面上什麼都不能按」這個更強的說法**只對 1 個站點成立**,不要拿它當理由:沒傳 `appBar` 的是 5 處(`split_tab`、`daily_target_screen`、`finance_overview_tab`、`finance_transactions_tab`、`networth_tab`;`care_history_screen` 有傳,`:249` 建、`:284` 傳),而其中 4 處是 `FinanceScaffold` 的 `IndexedStack` 子項,shell 的 AppBar 與 NavigationBar 一直在畫面上。真正毫無操作可用的只有 `DailyTargetScreen`。issue 點名的記錄數值頁(vitals/water/exercise/bowel/menstrual)**都有** appBar。

而且**就算有返回鍵也救不了**:token 已經失效,回到哪一頁都會再 401。唯一的出路是登出 → 回登入頁(`signOut()` 讓 `authStateChanges` 發出 false,`AuthRouterNotifier` 通知 go_router 的 `refreshListenable`,頂層 `redirect` 把位置換成登入頁)。

repo 裡已經有 **8 份手寫的出口**,而且彼此並不一致:

| 位置 | 按鈕 | 登出後 |
|---|---|---|
| `app.dart:1124`(dictionary) | FilledButton | 只 signOut |
| `home_screen.dart:281` | FilledButton | 只 signOut |
| `today_screen.dart:247` | FilledButton | 只 signOut |
| `food_search_screen.dart:308` | **OutlinedButton** | 只 signOut |
| `food_search_screen.dart:498` | **OutlinedButton** | 只 signOut |
| `health_scaffold.dart:353` | FilledButton | signOut + 導航 |
| `friends_screen.dart:341` | FilledButton | signOut + pop |
| `invite_screen.dart:139` | FilledButton | signOut + 導航 |

被抽成共用元件的那一個,反而是唯一沒有出口的。**照抄時要指名對象**(見 D4),不能說「照既有的做」——既有的有兩種按鈕、兩種登出後行為。

**範圍界線**:本 change 只補出口。**不動 token 更新策略**(issue #106 的另一半 D1:token 只在 shell 載入時取一次、`AuthRouterNotifier` 訂的是不含換發的 `authStateChanges`),那是獨立的下一個 change。兩者互不相依:即使 token 之後會自動更新,token 被撤銷、改密碼、後端因其他原因回 401 時,使用者仍然需要這個出口。

## 決策

### D1:`AsyncStateScaffold` 怎麼拿到登出動作?

**選:新增 `required VoidCallback onSignInAgain` 建構參數,由呼叫點串下來。**

現況:15 個呼叫點裡只有 5 個(`reminder_settings`、`care_items`、`chaodays_import`、`care_today`、`care_history`)持有 `AuthRepository`,其餘 10 個完全沒有 auth 依賴。

但串接成本比預期低:那 10 個畫面**各只有 1 個建構點**,分別在 `_AppState`(持有 `widget.authRepository` 與 `widget.signOut`;`app.dart:452/459/467/474/481` 的 `_trackerFor` 與 `:756`)與 `FinanceScaffold`(`finance_scaffold.dart:416/422/432/444`)。**`health_scaffold` 不建構這 10 個之中的任何一個**,不要照著找。

**呼叫點的 closure 要帶 `mounted` 守衛**:`VoidCallback` 不能 await,若 D3 的結論是「登出後還要導航」,那 15 個 closure 每一個都會在 await 之後碰 `BuildContext`(`use_build_context_synchronously`)。與其讓 15 處各自重新發現這件事,**在 shell 層寫一個共用的 closure 傳下去**。

**否決的替代方案:用 `InheritedWidget` 從 context 取 `signOut`。** 不需要改任何建構子,但 CLAUDE.md 明寫「`main.dart` is the only place that wires concrete adapters … via manual dependency injection — no DI framework」,而且 settings 那次的先例是**明確串接**(「threaded through `App` → `_AuthenticatedHome` → `HomeScreen` as required constructor parameters (not pulled out of `HomeController`)」)。跟既有慣例一致比省幾個參數重要。

### D2:參數要 required 還是 optional?

**選:required。**

optional 會讓「這個畫面沒補出口」跟「這個畫面不需要出口」在程式碼上長得一模一樣——這正是這次要修掉的那種狀態。required 讓編譯器保證不會再有第二個沉默的死路。

代價:所有 15 個呼叫點都要改,包含那些現在其實不太會撞到 reauth 的。可以接受。

### D3:按下之後要不要 pop 自己?**這條必須用測試判定,不能用推論。**

`friends_screen` 用的是 `_signOutAndClose`(`signOut()` 之後再 `_back()`),CLAUDE.md 的 Sign-out-and-close 段也寫著「`MaterialApp`'s root `Navigator` doesn't auto-discard routes pushed on top of that root」。

**但那段描述的是 go_router 之前的架構**(`MaterialApp.home` 隨 auth stream 翻頁)。現在(PR #70/#71 之後)是 go_router,頂層 `redirect` 掛在 `refreshListenable: _authNotifier` 上,登出時 redirect 會回傳登入頁的位置——**理論上整個 stack 會被換掉,不需要自己 pop**。

我不確定這件事,而且這正是那種「照著推論寫、看起來會動、實際上留一個失效畫面在上面」的地方。

**repo 自己答不出來,所以不能靠模仿。** 上表的 8 份手寫出口是 **5 比 3 分裂**(5 處只 `signOut`、3 處還自己導航或 pop),而且**沒有任何既有測試斷言登出後的 route stack**——它們全都停在「`signOut` 被呼叫」或「按鈕存在」。答案取決於 go_router 16 在 refresh 觸發的 redirect 下會不會取代一個 imperative push 上去的 match list,這件事 repo 裡沒有任何程式碼釘住。

**做法**:apply 階段先寫一個測試,在 go_router 環境下從一個 push 上去的 reauth 畫面按下按鈕,斷言最後停在登入頁、且原畫面不在樹上。測試結果決定 `onSignInAgain` 的預設實作是單純 `signOut` 還是 `signOut + pop`。**不要**先寫好實作再補測試。

同時要確認:`friends_screen` 的 `_signOutAndClose` 如果已經是多餘的,那是既有程式碼,**本 change 不動它**(CLAUDE.md 第 3 條:不要順手改相鄰程式碼),只在 follow-up 記一筆。

### D4:文案與版面來源

沿用既有的 ARB 鍵,不新增:`pleaseSignInAgain`(訊息)、`signInAgain`(按鈕)。

**版面以 `friends_screen.dart:333-343` 為準**(`Column(mainAxisSize: min)` → `Text(textAlign: center)` → `SizedBox(height: 16)` → `FilledButton`)。指名一份,而不是說「照既有的做」——8 份手寫的並不一致,籠統的指示會讓實作者照到 `food_search` 的 `OutlinedButton` 版本。那 8 份手寫的都用這兩個鍵,所以 15 個站點補上之後全 app 的 reauth **文案**一致(**版面**不會,見 D5)。

`AsyncStateScaffold` 現在的 `reauthMessage` 是 `String?` 由呼叫點傳入,15 處傳的都是 `loc.pleaseSignInAgain`(apply 時要逐處確認,不要信這句)。保持由呼叫點傳入,不在共用元件裡查 l10n——`shared/widgets` 不該假設呼叫點的語意。

### D5:那 8 份手寫版本要不要一併收編?

**不要。** 它們不是 `AsyncStateScaffold` 的使用者,而且彼此就不一致(兩種按鈕、兩種登出後行為,見上表)。統一它們是一個關於「reauth 出口該長什麼樣」的獨立題目,與本 change 要修的死路無關;而且要先決定按鈕該是 Filled 還是 Outlined、登出後該不該導航——後者正是 D3 要用測試回答的問題,答案出來之前不該動它們。記進 follow-up。

## UI/UX 設計

### 使用者路徑

**誰/情境**:已登入的 PWA 使用者,在記錄數值頁(vitals / water / exercise / bowel / menstrual 等)停留或從背景喚醒後,token 已失效。

**主路徑**:使用者按下儲存 → 後端回 401 → 畫面切到 reauth 狀態 → 使用者看到「請重新登入」與一個「重新登入」按鈕 → 按下 → 登出 → 回到登入頁 → 登入後回到 app。

**例外路徑**:
- 使用者不想現在登入 → 有 appBar 的 10 個站點仍可返回,另外 4 個(finance/split 的 tab)有 shell 的 AppBar 與 NavigationBar。回去也會再 401,但那是使用者的選擇,不是被困住。
- **登出本身失敗** → **這條沒有處理,是刻意的缺口。** 15 個呼叫點的 closure 都把 `signOut()` 的 Future 丟掉(9 處 `unawaited(...)`、6 處直接丟),失敗就是靜默無事發生——使用者按了唯一的出口而畫面不動。判斷:Firebase 的 `signOut()` 是本機操作(清掉本機憑證),不打網路,失敗機率極低;而要處理它就得讓 `onSignInAgain` 變成 `Future<void> Function()` 並在共用元件裡加 in-flight/失敗狀態,那是比這個 change 大得多的題目。**寫進 follow-up,不要假裝已經處理。**

**現況(壞掉的路徑)**:切到 reauth 狀態 → 一段文字,無按鈕。**15 處都無法從這個狀態脫身**(能按的地方都不能讓 token 復活);其中 `DailyTargetScreen` 更是連一個可按之處都沒有 → 只能關掉 PWA 重開。

### 介面與一致性

reauth 狀態的版面**以 `friends_screen.dart:333-343` 這一處為準**(D4):置中的 `Column(mainAxisSize: min)`,`Text(pleaseSignInAgain, textAlign: center)` → `SizedBox(height: 16)` → `FilledButton(signInAgain)`。`FilledButton` 是本專案的主要動作慣例(CLAUDE.md 設計系統節),pill 形狀與 ledge shadow 由 theme 提供。

**不要說「對齊既有的」**——8 份手寫的並不一致(`food_search_screen.dart:495-499` 是 `OutlinedButton` 配 `SizedBox(height: 8)`;`:305` 也是 `OutlinedButton`,但包在 `_ResultsMessage` 的 icon+title+action 結構裡、根本沒有 `SizedBox`)。

補上之後,共用元件的 15 處長相一致;那 8 處手寫的仍然分歧,D5 刻意不動它們。

### 狀態設計

- **loading**:不變。`isLoading` 優先於 `isReauth`,行為不動。
- **錯誤**:screen-specific 的 error 狀態仍在 `builder` 裡,不受影響。
- **登出進行中**:`signOut()` 是 async,而 `VoidCallback` 不能 await。要不要顯示 pending 狀態?**決定:不做**(連帶也就無法顯示失敗,見上)。 那 8 份既有手寫版本都沒有,Firebase 的 signOut 在本機是即時的,加一個只在此處出現的 pending 樣式反而是新的不一致。若 QA 實測發現有可感知的延遲,再回頭處理。
- **空狀態**:不適用。

### 可及性/理解性

- 訊息**可行動**:現在只說「請重新登入」卻沒有給任何登入的方法,是典型的「說了問題不給出路」。加上按鈕之後,訊息與動作在同一個視野內。
- 按鈕帶 `Key`,讓 15 個站點的測試可以指名斷言。命名沿用既有慣例 `<scope>-sign-in-again-button`;共用元件用單一固定 key(`async-state-reauth-sign-in-button`),因為它現在只有一份實作。

## 驗收(可觀察的行為)

1. WHEN 任一使用 `AsyncStateScaffold` 的畫面進入 reauth 狀態,THEN 畫面上同時有說明文字與一個可點擊的「重新登入」按鈕。
2. WHEN 使用者在 reauth 狀態按下「重新登入」,THEN 呼叫 `signOut`,且最終停在登入頁、原畫面不在 widget 樹上(D3 的測試同時決定實作)。
3. WHEN `isLoading` 與 `isReauth` 同時為 true,THEN 顯示 loading(既有優先序不變)。
4. 15 個呼叫點**每一個**都傳了 `onSignInAgain`(由 required 參數在編譯期保證,不需另寫測試;但盤點要逐檔重數並列出)。

## 風險

- **盤點錯誤**:這份文件的第一版就錯了三個數字(把沒 appBar 的說成 6、把 `care_history` 算進去、把手寫出口說成 4 份),而且錯的正是「為什麼要修」那一段。現在的數字(15 呼叫點 / 5 沒 appBar / 10 沒 auth 依賴 / 8 份手寫出口)已由 proposal review 逐檔驗過兩輪,tasks.md 0.1 仍要求 apply 時再數一次。**這條風險已經實現過一次,不是假設。**
- **D3 若判斷錯**,會留下一個「登出了但畫面還在」的狀態,比原本的死路更難察覺。所以要求先測試後實作。
- **無法實機驗證**:token 過期是時間相關的,widget test 只能用假的 repository 模擬 401 回應,證明不了真的 PWA 放一小時後的行為。這條要誠實寫進 PR。
