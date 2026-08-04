## Why

`AsyncStateScaffold` 的 reauth 狀態(`lib/shared/widgets/async_state_scaffold.dart:40-47`)是一段置中文字,**沒有任何動作**:

```dart
if (isReauth) {
  return Scaffold(
    appBar: appBar,
    body: Center(child: Text(reauthMessage ?? '', textAlign: TextAlign.center)),
  );
}
```

15 個呼叫點共用它。**這 15 處全部都是無法行動的**——不論畫面上還有沒有別的可按之處,token 已經失效,返回、切 tab、重新載入都會再 401。唯一的出路是登出,讓 go_router 的頂層 `redirect` 把位置換到登入頁,而畫面上沒有任何地方能做到這件事。這就是 issue #106 回報的:「PWA 在記錄數值頁,如果 token 過期僅顯示重新登入,使用者只能滑掉重開」。

**「畫面上什麼都不能按」只對 1 個站點成立**,不要拿它當這個 change 的理由:15 處裡有 5 處沒傳 `appBar`(`split_tab`、`daily_target_screen`、`finance_overview_tab`、`finance_transactions_tab`、`networth_tab`),但其中 4 處是 `FinanceScaffold` 的 `IndexedStack` 子項,shell 自己的 AppBar(`finance_scaffold.dart:403`)與 NavigationBar(`:512`)一直在。真正毫無操作可用的只有 `DailyTargetScreen`。而 issue 點名的那些記錄數值頁(vitals/water/exercise/bowel/menstrual)其實**都有** appBar——它們卡住的原因是返回沒有用,不是沒有返回鍵。

repo 裡已有 **8 份手寫的出口**(`app.dart:1124`、`home_screen.dart:281`、`today_screen.dart:247`、`health_scaffold.dart:353`、`food_search_screen.dart:308` 與 `:498`、`invite_screen.dart:139`、`friends_screen.dart:341`),都是「文字 + 重新登入」,但**版面並不一致**:其中 `food_search` 那兩處用的是 `OutlinedButton`、間距也不同。被抽成共用元件的那一個反而是唯一沒有出口的。

## What Changes

- `AsyncStateScaffold` 新增 **`required VoidCallback onSignInAgain`**,reauth 分支渲染:置中 `Column` → 說明文字 → `SizedBox(height: 16)` → `FilledButton`(文案用既有的 `signInAgain` ARB 鍵,不新增字串)。版面以 `friends_screen.dart:333-343` 為準——那 8 份手寫的並不一致,不能籠統說「照抄既有的」。
- **15 個呼叫點全部補上**。required 是刻意的:optional 會讓「沒補出口」跟「不需要出口」在程式碼上長得一樣,而那正是這次要修掉的狀態。
- 10 個呼叫點目前沒有任何 auth 依賴,需要把登出動作串下來。**每個各只有 1 個建構點**,分別在 `_AppState`(持有 `widget.authRepository` 與 `widget.signOut`;`app.dart:452/459/467/474/481` 的 `_trackerFor` 與 `:756`)與 `FinanceScaffold`(`finance_scaffold.dart:416/422/432/444`)。**`health_scaffold` 不建構這 10 個之中的任何一個**。

**範圍界線:不動 token 更新策略。** issue #106 的另一半(token 只在 shell 載入時取一次;`AuthRouterNotifier` 訂的是不含換發的 `authStateChanges`)是獨立的下一個 change。兩者互不相依:即使 token 之後會自動更新,token 被撤銷、改密碼、後端因其他原因回 401 時,使用者仍然需要這個出口。

**不收編那 8 份手寫版本。** 它們不是 `AsyncStateScaffold` 的使用者,而且彼此就不一致(2 處用 `OutlinedButton`、3 處登出後還自己導航)。收編它們是另一個題目,與這次要修的死路無關。

## Capabilities

### Modified Capabilities

- `shared-widgets`:`AsyncStateScaffold` 的 reauth 狀態從「只有訊息」變成「訊息 + 可行動的出口」。

## Impact

- 修改 `lib/shared/widgets/async_state_scaffold.dart` 與其測試。
- 修改 15 個呼叫點;其中 10 個畫面新增建構參數,連帶 10 個建構點。
- **未決、須由測試判定**:按下之後要不要 `pop` 自己。CLAUDE.md 的 Sign-out-and-close 段描述的是 **go_router 之前**的架構;現在頂層 `redirect` 掛在 `refreshListenable` 上,理論上整個 stack 會被換掉。**repo 自己答不出來**:8 份手寫出口是 5 比 3 分裂(5 處只 `signOut`、3 處還自己導航),而且沒有任何既有測試斷言登出後的 route stack——全都停在「`signOut` 被呼叫」或「按鈕存在」。見 design.md D3。
- **無法實機驗證**:token 過期是時間相關的,widget test 只能用假 repository 模擬 401,證明不了真的 PWA 放一小時後的行為。
