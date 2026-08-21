## Context

動機與根因見 `proposal.md`。這一節只記下形塑作法的現況與約束。

現況的交接鏈（前一次 change `2026-07-27-fix-push-deeplink` 建立）：

```
push 事件 → showNotification(title, { data: { path: data.path || '/care-today' } })
notificationclick → caches.put('lifeos-deeplink', '/pending', {path, savedAt})
                  → focus() 既有 window（成功才 postMessage）／否則 openWindow('/')
app 端 → PendingDeepLinkStoreImpl.take()（讀後即刪）
       → PendingDeepLinkController（守門/TTL/去重/單飛）
       → _router.push(path)
```

四個約束，會直接決定下面的每一個決策：

1. **push SW 刻意不隨 app 更新被 unregister**（前一次 design D6b：unregister 會毀掉推播訂閱）。
   因此**寫交接的 SW 版本與讀交接的 Flutter app 版本可以不同**——這不是邊角情境，是這個架構的常態。
2. **同一支 SW 服務所有推播類型**：照護提醒、預算警示、測試推播。SW 內既有註解已寫明後兩者
   沒有 `ack`，等於承認它們走同一條路。
3. **`CareTodayController` 是 app 生命週期的單例**，被今日照護畫面、健康總覽的批次讀取
   （`applyBatchSection`）、以及交接的安靜重載三方共用；`_fetching` 是它們共用的 in-flight 旗標。
4. **web 上 `AppLifecycleState.resumed` 與跨 scope `postMessage` 都不保證送達**（前一次 design D4
   自己就把 `visibilitychange`／`focus` 列為退路，只是沒實作）。

已量到的現場數據（本次診斷用一次性探測測試取得，非推論）：

| 探測 | 結果 |
| --- | --- |
| 交接 path = `/no-such-route` | 停在 go_router 英文 `Page Not Found`，首頁被蓋掉，**不丟任何例外** |
| `getToday` 永不 settle | `status` 永遠 `loading`、spinner 永遠轉；**再點一次通知，請求計數停在 1**（第二次請求根本沒送出） |
| 連續 8 次交接（目的地交替） | 要按 **8 次返回**才回得到首頁 |
| `_buildRouter()` | 沒有 `errorBuilder`，沒有 `onException` |

## Goals / Non-Goals

**Goals:**

- 通知點擊的目的地由**該則通知自己**決定；沒有目的地就不假造一個。
- 交接的路徑在導航前被驗證；認不得就當作沒有交接。
- 任何會擋住畫面的等待都有結局；任何 in-flight 旗標都不可能永久鎖死。
- 重複點通知不疊層、且是「卡住時的一條出路」而不是 no-op。
- 每條根因都有一個**修復前會紅**的迴歸測試。

**Non-Goals:**

- 不設計後端 payload 的 `path` 欄位內容（後端 change，另案）。本次只讓前端在後端還沒送之前
  不再說謊。
- 不改 Cache Storage 這個交接管道本身（D1/D2 契約維持）。
- 不改 `resolveAuthRedirect` 與 URL-driven 的 deep link 復原機制。
- 不做離線／重試佇列。

## Decisions

### D1 — 目的地在「顯示通知」時決定，`notificationclick` 只轉交

`push` handler 已經是唯一看得到 payload 的地方。決定：`showNotification` 的 `data` 存
`{ path: data.path }`——**沒有就是沒有**，不再 `|| '/care-today'`。`notificationclick` 讀不到
`path` 時**不寫 Cache**，只做 focus／openWindow。

替代方案（在 `notificationclick` 依 `notification.tag`／title 猜類型）被否決：那是把「這則通知是
什麼」的知識抄到第二個地方，而這個 repo 已經反覆吃過同一句錯前提散在多處的虧
（`hidden-field-still-enforced` 的教訓）。payload 是唯一事實來源。

代價：在後端開始送 `path` 之前，**照護提醒也會沒有目的地**，退化成「點通知只把 app 帶到前景」。
這是刻意的，且比現況誠實——現況是「所有推播都謊稱自己是照護提醒」。為了不讓照護提醒在後端跟上前
先退化，本 change 保留一個**明確標示為過渡**的相容分支：payload 帶 `type: 'care'`（或後端既有的
可辨識欄位）時映射到 `/care-today`；沒有任何可辨識訊號時才是「沒有目的地」。這個分支要用
與契約測試同一份常數釘住，並在後端送 `path` 後刪除。

### D2 — 「認不認得這個路徑」問 router 本人，不另抄白名單

導航前用 app 自己的 `GoRouter` 設定去 match 一次（`router.configuration.findMatch(uri).isError`），
match 不到就當作沒有交接。

替代方案是在 controller 裡維護一份允許路徑清單。否決：那份清單與 `GoRoute` 宣告是兩份會漂移的
事實，正是 `app_locations.dart` 當初存在的理由（前一次 design D6 的守門 2 已經為同一個理由做過
一次收斂）。用 router 本人 match，新增路由自動被涵蓋、刪掉路由自動被拒絕。

這個判斷屬於「app 認不認得」，所以放在 `app.dart` 注入給 controller 的 callback（與既有的
`canNavigate`／`currentPath`／`navigate` 同一層），controller 仍然只有純判斷、可單測。

### D3 — `errorBuilder` 是第二道防線，不是第一道

D2 之後理論上不會再有 unmatched location 從交接進來，但 unmatched location 還有別的來源
（舊書籤、手打網址、Pages 的 SPA fallback）。決定仍然補 `errorBuilder`：本地化文案 + 一個
`go('/')` 的出口。

刻意寫成第二道防線而不是唯一防線：如果只補 `errorBuilder`，交接失敗的表現會是「使用者被通知丟到
一個錯誤畫面」，那還是「非預期的頁面」。D2 才是把它變成「什麼都沒發生」。

### D4 — 目的地已在堆疊中就收回到它，而不是再疊一層

現行去重只比對**最上層**路徑（`matches.last.matchedLocation`）。改成：若目的地已在目前的
match list 裡的任何一層，就收回（pop）到那一層並觸發該畫面的重載；不在才 `push`。

這同時修好「8 次通知 = 8 次返回」與「A→B→A 交錯疊出兩份 A」。返回語意不變：使用者原本那一層仍然
在下面（規格要求「一次返回回到第一次點通知前的畫面」）。

替代方案「push 前先 pop 掉所有先前由交接推上去的頁」被否決：需要記住「哪幾層是交接推的」這個額外
狀態，而 match list 本來就答得出「這個路徑在不在堆疊裡」。

### D5 — 等待要有結局：逾時放在 controller，且被擋下的呼叫要**等待那一輪的答案**

兩件事分開做，缺一不可：

1. **逾時**：`load()`／`reloadQuietly()` 的 fetch 套一個有界的逾時（含取 id token 那一段——
   實測卡住的形狀不只 HTTP）。逾時後 `load()` 落到可重試的 `error`，`reloadQuietly()` 沿用既有
   的安靜規則（有內容就保留內容，沒有內容過就落到 `error`）。`_fetching` 一律在 `finally` 釋放。
2. **被單飛旗標擋下的呼叫不能直接 `return`**：現況 `if (_fetching) return;` 讓後到的
   `load()` 什麼都不做，於是 `status` 停在別人設定的 `loading` 上——這正是實測到的永久 spinner。
   改成把「這一輪的結果」存成一個已解析的 Future 欄位，後到者 `await` 它。這是這個 repo 已經寫進
   記憶的規則：**答案要放進已解析的 future 值，不是放進共用欄位**。

   例外必須明確：規格要求「再點一次通知一定會重新發出請求」。所以**使用者發動的重試／通知重載**
   在前一輪已逾時的情況下要開新的一輪，而不是掛在那個永遠不會回來的 Future 上。逾時本身
   （D5.1）就是讓這件事成立的機制：逾時一到 `_fetching` 就已經放掉了。

### D6 — 交接消費端套同一條規則

`PendingDeepLinkController`：`_store.take()` 套有界逾時；`_checking` 在 `finally` 釋放
（現況已有 `finally`，但 `take()` 永不 settle 時根本走不到 `finally`——逾時才是真正的解法）。

### D7 — 前景觸發改成「畫面對使用者可見時」，不綁定單一訊號

在 web adapter 把 `document.visibilitychange`（轉為 visible）與 `window.focus` 併入
`handoverSignals`，controller 完全不變（它本來就只收「可能有東西可讀」的無資料信號）。
多餘的信號無害：`take()` 讀到 `null` 就結束，D6 的單飛 + TTL 已經涵蓋。

這正是前一次 design D4 自己列的退路，只是當時把跨 scope `postMessage` 當成唯一路徑。實機事故
（`lifeos-push-silent-failure`）已經示範過「只有一條訊號路徑」的代價。

### D8 — 契約測試跟著擴張

`push_sw.js` 與 Dart 端的常數比對測試（既有）要涵蓋新的 `data` 形狀，並**額外斷言 SW 裡不再有
硬編的 `/care-today` 預設**——否則 D1 可以被一次 revert 悄悄推翻而全綠。

### D9 — 測試策略：每條迴歸測試都要先紅，且要用最壞情況的 fixture

| 根因 | 測試 | 修復前必須紅在哪 |
| --- | --- | --- |
| 目的地與通知無關 | SW 契約測試 + widget 測試（無目的地的交接） | 現況 SW 硬編 `/care-today`；現況 widget 會推 `/care-today` |
| 認不得的路徑 | widget：交接 `/no-such-route` → 停在首頁、無錯誤畫面 | 現況顯示 `Page Not Found`（已實測） |
| 永久 spinner | widget + controller：`getToday` 永不 settle → 逾時後出現可重試錯誤 | 現況 `status` 永遠 `loading`（已實測） |
| 再點一次是 no-op | controller：卡住後第二次交接 → 請求計數要 ≥ 2 | 現況計數停在 1（已實測） |
| 疊層 | widget：8 次交接後一次返回回到起點 | 現況要 8 次（已實測） |
| 前景無訊號 | web adapter 不可測；controller 測「任一信號都會觸發 check」+ 實機驗證 | — |

**守門要能失敗**：`getToday` 的假替身必須是「永不 settle」而不是「立刻丟例外」——零延遲的假替身
會讓觀察窗口在第一次 pump 前關掉，這個 repo 已經因此吃過全綠的假守門
（`guards-that-cannot-fail`、`fakes-never-reject-what-real-apis-reject`）。逾時測試要用
`FakeAsync`／`tester.pump(duration)` 推進時間，不能靠真實等待。

實機驗證（自動化涵蓋不到，需在 Android 上做）：冷啟動／背景／前景各一次，加上
「非照護通知不再落到今日照護」與「連點多則通知後一次返回回到原處」。

## Risks / Trade-offs

- **D1 讓照護提醒在後端跟上前退化成「只把 app 帶到前景」** → 用 D1 的過渡相容分支保住照護提醒，
  並把「刪掉這個分支」寫進 tasks 的後續項；相容分支必須被契約測試釘住，否則它會靜靜留一年。
- **逾時的長度選錯**：太短會把慢網路誤判成失敗，太長等於沒有 → 取一個明顯長於正常回應、又短於
  使用者放棄的值，並讓逾時後的狀態是**可重試**的（而不是終局失敗），誤判的代價因此只是多一次點擊。
- **D4 的 pop-to-existing 會丟掉使用者在目的地之上開的那幾層** → 這正是使用者要求的（他點通知就是
  要去那裡），且規格明寫「一次返回回到第一次點通知前的畫面」；風險是若目的地之上有未儲存的表單，
  會被收掉——目前唯二會被交接指到的路徑都不是表單畫面，若未來新增則需在該畫面自行守門。
- **D7 增加觸發次數** → 每次多一次 Cache 讀，讀到 `null` 就結束；TTL 與讀後即刪已經保證不會重複導航。
- **SW 與 app 版本永遠可能不同步**（架構常態，消不掉）→ D2 把它的後果從「死路」降級為「什麼都沒發生」。

## Migration Plan

無資料遷移。部署順序：前端可獨立上線（D1 的過渡分支讓照護提醒行為不變）。後端開始送 `path` 之後，
再刪掉 D1 的過渡分支與其契約測試。舊 SW 顯示、還留在通知匣裡的通知在新版下沒有 `path` → 走
「沒有目的地」路徑，退化為只帶到前景，可接受。

回滾：前端整包 revert 即可，交接契約（cache name／key／欄位）不變，不會留下讀不回來的殘留狀態。
