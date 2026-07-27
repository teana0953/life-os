# 修復 Android PWA 推播 deep link（冷啟動）與返回箭頭

## 問題

點擊照護推播通知後，應該進到「今日照護」(`/care-today`)，實際行為分三種：

| 情境 | 現況 | 期望 |
| --- | --- | --- |
| PWA 冷啟動（task 已清） | 停在首頁 | 進到今日照護，可返回首頁 |
| PWA 在背景 | **有**進到今日照護，但沒有返回箭頭，返回鍵離開 app | 進到今日照護，可返回原本頁面 |
| PWA 在前景（heads-up 通知） | 有進到今日照護（同樣沒有返回箭頭） | 進到今日照護，可返回原本頁面 |

### Root cause（實機證據）

`web/push_sw.js` 的 `notificationclick` 走 `clients.openWindow('/#/care-today')`，**目的地完全靠 URL fragment 傳遞**。實機驗證：

1. 線上 `push_sw.js` 已是含 `/#/care-today` 的新版，`cache-control: public, max-age=0, must-revalidate` → 裝置跑舊 SW 的可能性排除。
2. 後端 `run-care-tick.ts` 只送 `{ title, body }`，不送 url → 走 SW 預設值。
3. 手動在瀏覽器開 `https://life-os-6oo.pages.dev/#/care-today` → 正常進到今日照護 → app 內的 `resolveAuthRedirect` deep-link 復原機制正常。
4. 從最近使用清單清掉 PWA 後點通知（真冷啟動）→ 停首頁，PWA 內「複製連結」得到 `https://life-os-6oo.pages.dev/`，**連 `#/` 都沒有** → WebAPK 冷啟動時用 `start_url`（manifest 為 `.`）啟動，`openWindow` 給的 fragment 遺失。

因此兩個症狀是同一個設計缺陷的兩面：

- **冷啟動失敗**：fragment 在 WebAPK 啟動路徑上被丟掉，app 收不到目的地。
- **沒有返回箭頭**：既有 window 收得到 hash 導航，但那是 URL 驅動的**取代**語意，go_router 直接把堆疊重建成單層 `/care-today`，沒有 parent 可返回。

## 設計決策

### D1 — 目的地改走 Cache Storage 交接，不再依賴 URL

`notificationclick` 時 SW 把目標路徑寫進 Cache Storage（同源共享，SW 與頁面都能存取），app 端自己讀出來導航。URL 不再是傳遞目的地的管道，於是 WebAPK 丟不丟 fragment 都不影響。

選 Cache Storage 而非 IndexedDB：讀寫各一行 (`cache.put` / `cache.match`)，不需要開 DB、升級 schema、處理 `onupgradeneeded`。存的是「一筆會被立刻消費掉的短命記錄」，不需要 IndexedDB 的查詢能力。

localStorage 不可用 —— service worker 沒有它。

### D2 — 交接契約（單一事實來源）

SW（JS）與 adapter（Dart）各寫一次讀寫，拼錯會**整條靜默失效**且沒有任何測試抓得到，所以契約釘在這裡，兩邊都以本節為準：

| 項目 | 值 |
| --- | --- |
| cache name | `lifeos-deeplink` |
| key | `'/pending'` —— **必須**以 `/` 開頭 |
| payload | `{ "path": string, "savedAt": number }`，`savedAt` 為 epoch 毫秒 (`Date.now()`) |
| `path` 形式 | app router 的路徑，例如 `/care-today` —— **不是** hash URL |

key 以 `/` 開頭是必要條件而非風格：`cache.put` 會把相對 key 依 base 解析成絕對 URL，而 SW 的 base 是 `/push_sw.js`、頁面的 base 是 `/`，只有根相對路徑能保證兩邊解析成同一個 URL。

**通知本身攜帶的 `data` 也改成 path 形式**：`push` handler 現況存的是 `{ url: data.url || '/#/care-today' }`，`notificationclick` 再讀它。D9 之後那個 hash URL 不能再流進 Cache（`push('/#/care-today')` 匹配不到任何 route），所以 `push` handler 改存 `{ path: ... }`，預設 `/care-today`，`notificationclick` 直接取用。

Dart 端讀出 `savedAt` 後以 `DateTime.fromMillisecondsSinceEpoch` 轉換。**時鐘回退**（`savedAt` 落在未來）不特別處理：`now - savedAt` 為負，自然不超過 TTL，視為有效——這比丟棄安全，因為丟棄會讓一次正常的通知點擊無聲失效。

Flutter 自己的 service worker 只 `caches.delete` 它自己那三個具名 cache，`index.html` 的 `pwaUpdate.apply()` 也只 unregister root registration，都不會動到 `lifeos-deeplink`。

### D3 — SW 依既有 window 分岔：focus 或 openWindow

```
notificationclick
  → 寫 pending 到 Cache（await 完成）
  → matchAll({ type: 'window', includeUncontrolled: true })
      有既有 window → client.focus()
                       成功 → client.postMessage(信號)
                       reject → clients.openWindow('/')，且不送信號
      沒有          → clients.openWindow('/')
```

**信號一定要在 `focus()` 成功之後才送**。反過來的話，fallback 路徑會同時做兩件打架的事：信號已經送給那個舊 window，它可能在背景就把 pending `take()` 掉並導航（使用者看不到），而隨後 `openWindow('/')` 開出來的新 window 讀到空 Cache、停在首頁 —— 使用者點了通知反而落在首頁，比不修還糟。

`includeUncontrolled: true` 讓 `/push/`-scope 的 SW 也看得到 `/`-scope 的 app window —— 規格上這個旗標的可見範圍以 **origin** 判定、與 scope 無關（現有程式碼註解說看不到，只在沒帶這個旗標時成立，需一併更正）。`WindowClient.navigate()` 仍然不能用（它要求 client 被此 SW 控制），但 `focus()` 沒有這個限制，而導航本來就交給 app 自己做。

**寫入必須在 focus/open 之前 await 完成**，整條串在同一個 `event.waitUntil` promise chain 上，否則冷啟動有機會先開 window 後寫 cache。

**對既有 window 只 focus 不導航**是刻意的：使用者原本可能停在飲食頁，導航會洗掉那層堆疊，違反 D5 的返回語意。

`focus()` 會 reject（缺 user activation、client 不可 focus、Android 版本差異），此時 fallback 到 `openWindow`，否則 warm 情境會靜默失效。

`matchAll` 可能回多個 window（桌機分頁 + 手機端），挑選規則：**優先 `focused === true` 的，其次第一個**。

### D4 — 前景情境靠 postMessage 信號補觸發

Android 的照護提醒常在使用者正在用 app 時跳 heads-up banner。此時 client 本來就 focused/visible，`focus()` 不造成 visibility 變化 → Flutter 不會派送 `resumed` → pending 寫進 Cache 卻沒人消費，畫面完全不動。**現況在這個情境是會導航的，所以少了這條就是退化。**

SW 對既有 window `postMessage` 一個**不帶資料的信號**，web adapter 掛 `navigator.serviceWorker` 的 message 事件，收到就觸發一次 check。

信號不帶目的地是關鍵：Cache 仍是唯一的事實來源，所有時效／去重／守門判斷只有 controller 那一份，不會長出第二套消費邏輯而彼此不同步。

**必須呼叫 `startMessages()`**：`ServiceWorkerContainer` 的 client message queue 預設是關閉的，只有設定 `onmessage` 屬性或呼叫 `startMessages()` 之後才會開始派送。單用 `addEventListener('message', ...)` 註冊（Dart 端最自然的寫法）訊息會被無聲地排隊、永遠收不到 —— 症狀與這一節要修的問題一模一樣，而 SW 與 adapter 兩層都不在自動測試覆蓋範圍內，只有實機才會發現。

`Client.postMessage` 由非受控的 `/push/` scope 送到 `/`-scope 頁面在規格上成立（message queue 屬於 `ServiceWorkerContainer` 而非個別 registration），但這是本設計**唯一沒有既有程式碼佐證的假設**，所以「SW 送信號 → app 收到」列為實機驗證的第一項；若不成立，退路是 web adapter 自己掛 `document` 的 `visibilitychange` 與 `window` 的 `focus`。

### D5 — 導航用 `push`，疊在既有堆疊之上

消費 pending 時用 `push` 而非 `go`：

```
冷啟動：        [首頁] → push → [今日照護]        返回鍵 → 首頁
已在執行（飲食）：[首頁] → [飲食] → push → [今日照護]  返回鍵 → 飲食
```

這同時修好返回箭頭，並與 app 內既有的進入方式一致（總覽卡片、更多頁都是 `context.push('/care-today')`）。

### D6 — 消費時機：auth 就緒之後，且不落在過場畫面上

三個觸發點：**啟動後**、**auth 狀態轉換**（涵蓋「點通知時未登入 → 登入後」）、**回到前景**（`didChangeAppLifecycleState(resumed)`，比照既有 `PwaUpdateController`），加上 D4 的 postMessage 信號。

兩道守門：

1. **auth 未就緒不消費**：`loading`／`error`／未登入時直接 return，**且不 take**（留給下一個觸發點）。冷啟動時 auth 還在 bootstrap，router 被 `resolveAuthRedirect` 壓在 `/splash`，此時 push 會被 redirect 吃掉並改由 `pendingDeepLink` 以 `go` replay —— 那條路徑沒有返回箭頭。
2. **過場位置不消費**：`currentPath` 落在 `/splash`、`/auth-error`、`/login`、`/register` 時同樣 return 且不 take。**空字串或未匹配的 `currentPath` 視同過場位置** —— `start()` 在 `initState` 跑第一次 check 時 router 還沒完成首次 parse，`currentConfiguration` 是空的，若放行就會在無效的 base 上 push。

這四個位置名稱與 `resolveAuthRedirect` 讀的是**同一份宣告**（`lib/shared/routing/app_locations.dart`）：兩邊各抄一份的話，日後新增或改名一個過場／登入閘門路由只會改到 router 那一份，controller 這份靜默失準（今日照護疊在登入頁上）而沒有任何測試會紅。

**守門被拒後必須有人重新觸發，而那個重試點是「auth 狀態轉換」**。兩道守門都只 return 不 take，被擋下的 pending 得等下一次觸發；關鍵是**每一條會通過守門的路徑，都必然在被擋之後還有一次 auth 通知**：

- 冷啟動第一次 check 由 `initState` 裡的 `start()` 發動，此時 auth 還在 loading（守門 1）、router 還沒 parse（守門 2），必被擋下；而 `AuthRouterNotifier` 的 `notifyListeners` 只可能發生在 auth stream callback 的 microtask 裡，**必定晚於** `initState` 掛好的 listener，所以那一次通知一定收得到。
- 「點通知時未登入」被守門 1 擋下，靠的是登入後的那一次 auth 通知。
- 已登入卻停在過場／登入畫面（守門 2）不會是穩定狀態 —— `resolveAuthRedirect` 會把它導走，而那個 redirect 是**同步**的（回傳 `String?`，parser 走 `SynchronousFuture`、`setNewRoutePath` 同步更新 `currentConfiguration`）。我們的 listener 又註冊得比 go_router 自己的 `refreshListenable` 早，所以同一次 `notifyListeners` 裡：我們先排下 post-frame callback，go_router 當場把 router 從 `/splash` 帶走，等 callback 真的執行時 `currentPath` 已經是真畫面。

因此**不需要**額外訂閱 `GoRouterDelegate` 當「守門拒絕後的重試點」：在目前這個同步 redirect 的架構下，那個訂閱到不了任何 auth 通知到不了的地方。實測佐證：把該訂閱整組拿掉，完整測試套件的結果與保留時一模一樣（沒有任何測試釘得住它）。依 CLAUDE.md §2（不為不可能的情境寫處理）不保留 —— 若日後 redirect 變成非同步，這個推論的前提就不成立，屆時要重新加回一個重試點。

重複觸發不會失控：消費成功後 `take()` 已把 Cache 清空，之後任何觸發（resumed、信號）只會讀到 `null`，加上 D8 的單飛旗標與「已在目標路徑改為重載」的守門，收斂在一次。

**時序**：auth listener 只負責「排程」，實際 check 用 `addPostFrameCallback` 延到下一幀（callback 內先確認 `mounted`，否則 widget 測試 teardown 與 hot reload 會對已 dispose 的 router 呼叫 push）。原因是 go_router 的 `refreshListenable` 是在 `_buildRouter()` 時才註冊的，晚於 `_AppState.initState` 掛的 listener，所以 auth 一 resolve 我們會**先**跑；不延一幀的話 `push` 的 base 可能還是尚未被 redirect 掉的 `/splash`，返回鍵會先閃一下 splash，測試也會 race。

`resolveAuthRedirect` 與其 `pendingDeepLink` 機制**完全不動** —— 它處理的是「URL 本來就帶著 deep link 的冷啟動」（手動輸入網址），仍然有效，且已有完整測試。

### D7 — 時效與讀後清除

寫入時附時戳，消費時：**先清除、再判斷時效**（讀後即刪，無論採不採用），逾時者丟棄不導航。TTL 取 **5 分鐘**。

防的是這個情境：SW 寫了 pending 但 app 始終沒開起來（使用者點了通知又立刻切走、或啟動失敗），殘留值會在下一次「使用者自己打開 app」時劫持導航，把人莫名其妙丟到今日照護。5 分鐘足夠涵蓋正常的「點通知 → app 起來」延遲，又短到不會跨越到下一次自主開啟。

### D8 — 併發防護

觸發點有五個（啟動、auth 轉換、resumed、導航、信號），兩次 check 併發時各自發一個非同步 Cache 讀取，可能都在對方 delete 之前讀到同一筆 pending，疊出兩層今日照護（`currentPath` 去重擋不住，因為第一次導航還沒完成）。controller 用一個 in-flight 旗標：已有未完成的 check 就不再平行跑一次。

但單純 return 會**丟掉**那次觸發，而觸發本身可能帶著新資訊：in-flight 的那次 check 也許剛好在 SW 寫入之前讀到空 Cache，隨後的信號才是「現在有東西了」。前景情境（D4）沒有後續觸發點可以兜底 —— 沒有 resumed、沒有導航 —— 這一次交接就會懸在 Cache 裡直到下次回前景，正是本 change 要修的症狀。所以被擋下時記一個 `_recheckRequested`，當前 check 結束後補跑一次（補跑仍在同一條 in-flight 內，不會平行）。代價是每次併發觸發多一次 Cache 讀，讀到 `null` 就結束。

### D9 — `openWindow` 一律開 `/`，不帶 hash

原本打算保留 `/#/care-today` 當桌機分頁的 fallback，但那條路徑會走既有 `resolveAuthRedirect` 的 `pendingDeepLink` replay，用的是 `go` 語意 → **沒有返回箭頭**，與本 change 的驗收標準直接衝突。

改成一律開 `/`，所有平台（WebAPK、桌機分頁、Android 瀏覽器分頁）都走同一條 Cache 路徑、都用 `push`、都有返回箭頭。代價是失去「Cache 不可用時仍能靠 URL 到達」的防禦；接受，因為行為一致比多一條會產生不同結果的路徑更有價值，而 Cache 不可用時的退化（停在首頁）與今天的冷啟動現況相同。

**「停在首頁」這個退化必須真的成立**：SW 寫 Cache 可能 reject（配額、使用者封鎖站台資料、隱私模式），寫入若不獨立包 try/catch，整個 `notificationclick` 的 `waitUntil` 會 reject，既不 focus 也不 openWindow —— 點通知什麼都不發生，比現況更糟。寫入因此是 best-effort：失敗照樣往下走 focus/openWindow，app 讀不到 pending 就正常開在首頁。

`currentPath` 去重因此從「必要」降級為「純防禦」，仍然保留 —— 但**不是靜默 return**。使用者主要就停在今日照護頁，「已在目標路徑」是常見情境而非罕見競態：畫面上的清單是 `initState` 那一次載入的結果，不重載的話點通知完全沒回饋；跨日更糟，隔天早上點提醒看到的是昨天的清單，按 Done 會用 `slot.localDate` 送出昨天的日期。所以這個分支改為觸發一次目的地畫面的重載（controller 呼叫注入的 `refresh` callback）—— 判斷仍然只有 controller 那一份，畫面不知道有這條路徑存在。

這個重載必須是**安靜的**：使用者正盯著那份清單，不能因為重載而先被換成 spinner，更不能因為重載失敗就把一份好好的清單換成錯誤畫面。`app.dart` 因此接到 `CareTodayController.reloadQuietly`，語意與既有的「標記完成後的重抓」（FIX 2）完全一致：`status` 全程維持 `loaded`、失敗保留既有 slots 且不出錯誤訊息（呼應本節下方「導航失敗一律安靜」），只有 401 仍然路由到 reauth；並帶一個 in-flight 守衛，連點多則通知不會有兩個 GET 亂序落地。

token 也必須是**當下重新取得的**：`refresh` callback 走 `await authRepository.idToken()`（比照 `CareTodayScreen._load`），不能用 `AuthRouterNotifier.idToken` 那份快照 —— 它是最後一次 `authStateChanges` 事件當時 await 到的值，而 Firebase 的 `authStateChanges()` **不在 token 續期時發射**、ID token 一小時就過期。「隔夜早上點提醒」正是這條重載存在的理由，卻剛好是快照最可能已經過期的時刻，那會變成 401 → 整頁「請重新登入」，而使用者根本沒登出。

### D10 — 平台隔離比照既有 PWA 模組

`lib/shared/pwa/` 既有的三件組模式：抽象介面 + `export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart'`。Cache Storage 與 `navigator.serviceWorker` 只有 web 有，非 web target（android/ios/VM 測試）用 no-op stub 保持可編譯，widget 測試注入 fake。

## 元件

| 檔案 | 職責 | 測試 |
| --- | --- | --- |
| `web/push_sw.js` | 依 D2 契約寫 pending；focus 既有 window 成功後送信號，否則 openWindow | 行為無測試（瀏覽器端 glue，比照現況）；D2 契約有原始碼比對測試 |
| `lib/shared/pwa/pending_deep_link.dart` | 抽象介面：`take()` → `PendingDeepLink?`、`handoverSignals` stream，conditional export | — |
| `..._stub.dart` / `..._web.dart` | 非 web no-op／Cache Storage 讀取＋刪除、serviceWorker message 轉信號 | web impl 不測（薄 adapter，比照 `BrowserWebPushGateway`） |
| `lib/shared/pwa/pending_deep_link_controller.dart` | 守門 + 時效 + 去重（已在目標路徑改為觸發重載）+ 併發防護 + 生命週期觀察 + 信號訂閱 + 觸發導航 | **單元測試**（注入 fake store + 固定 now） |
| `lib/app.dart` | 接線：建 controller、訂閱 auth、排程 post-frame check、callback 打 `push`／取新 token 後安靜重載 | widget 測試 |

判斷邏輯全部落在 controller 這個**可測的純 Dart 層**，adapter 只做 Cache 讀寫與事件轉譯，SW 只做寫入與 focus/open 分岔 —— 沿用專案既有的「薄 adapter + 可測 controller」分工。

## UI/UX 設計

### 使用者路徑

**主路徑（冷啟動）**：使用者收到照護提醒 → 點通知 → PWA 啟動 → `/splash` 的 spinner（auth bootstrap）→ 首頁自己的 loading（首頁在 `initState` 打 profile API）→ 首頁 spaces grid → 今日照護以完整轉場動畫疊上來 → 按 Done/Skip → 按返回箭頭或返回鍵回到首頁 spaces grid。

**這四段畫面是刻意接受的，不是異常**（實機驗證時不必當缺陷回報）：底下要有一層**真的畫面**，返回才有地方去，所以一定得先落地首頁再 `push`；三種避開的方式都更糟 —— 不 push 就沒有返回箭頭；在第一幀之前先讀 Cache 會拖慢每一次冷啟動（包含 99% 沒點通知的情況）；在 router 離開 `/splash` 之前 push 會被 redirect 吃掉（D6 守門 2 存在的理由）。唯一的選配優化是讓這次 push 不帶轉場動畫（讀起來像「app 就是開在今日照護」），但那要為 `/care-today` 加一個吃 extra 旗標的 pageBuilder、多一條程式路徑，以本 change 的規模不划算，留到真有人抱怨再說。

**主路徑（app 在背景）**：點通知 → PWA 帶到前景，停在使用者原本那一頁 → 自動疊上今日照護 → 返回鍵回到原本那一頁。

**主路徑（app 在前景）**：heads-up 通知蓋在使用中的畫面上 → 點它 → 今日照護當場疊上來 → 返回鍵回到原本那一頁。

**例外路徑**：
- 未登入：點通知 → 走既有登入流程 → 登入後才消費 pending → 疊上今日照護。
- pending 逾時（>5 分鐘）：不導航，使用者停在正常的啟動畫面，與沒點通知一樣。
- 已經在今日照護頁：不重複疊加，但清單會重新載入 —— 使用者看到的是最新的（且跨日時是今天的）狀態，而不是畫面停格不動。
- Cache 不可用：不導航，app 正常開啟。

### 介面與一致性

不新增任何畫面或元件。導航後看到的就是既有的 `CareTodayScreen`，返回箭頭由 `push` 自動提供：**返回箭頭的存在與操作語意，與從總覽卡片、「更多」頁進入時一致**，落點則是使用者原本所在的那一層 —— 冷啟動時是首頁 spaces grid，從總覽卡片進入時是帶底部導覽的健康總覽。

落點不一致是刻意不修的：要讓冷啟動也落在健康總覽，得先 `go('/health')` 再 push，那等於偽造一段使用者沒走過的歷史；而且只有冷啟動做得到（暖啟動必須完全不碰使用者既有的堆疊，正是 D3「focus only, never navigate」的核心），於是冷／暖兩條路徑又會產生不同結果 —— D9 才剛為了消除這種分岔把 `openWindow` 統一成 `/`。現行規則最誠實：**返回永遠回到當時真正在下面的那一層**。已知的附帶摩擦（不在本 change 處理）：spaces grid 沒有底部導覽，冷啟動處理完提醒按返回會落在那裡，要回熟悉的健康總覽得多點一次；真要改，該改的是 app 層的首頁定位，不是這個 change。

### 狀態設計

- **loading**：冷啟動時先出現既有的 splash（auth bootstrap），再落地首頁、疊上今日照護。今日照護頁自己的 loading／錯誤／空狀態沿用現況，不因來源是通知而不同。
- **導航失敗**：Cache 讀取失敗或 pending 逾時，一律**安靜地不導航**，app 停在正常啟動位置。不顯示錯誤訊息 —— 使用者的實際意圖（看照護項目）用 app 內既有入口一步就能達成，跳錯誤對話框只會擋路。
- **已在目標路徑的重載**：不進入 loading（畫面上的清單不會被 spinner 換掉），失敗也不進入錯誤畫面 —— 使用者沒要求這次重載，它不能把已經看得好好的清單拿走（見 D9）。
- **邊界**：多則通知連續點擊只會留下最後一筆 pending（同一個 key 覆寫），不會疊出多層。

### 可及性/理解性

導航是使用者主動點通知觸發的，結果與預期一致（點照護提醒 → 到照護頁），不需要額外說明文案。返回箭頭的存在讓「我可以回去」變成可見的、可操作的，而不是要靠猜測按系統返回鍵。

## 測試策略

- **controller 單元測試**（TDD 主戰場）：時效內採用／逾時丟棄但仍消費／auth 未就緒不 take／過場路徑不 take／空 `currentPath` 不 take／已在目標路徑改為重載而不導航（逾時者連重載也不做）／`null` 不炸／消費過不重複／`resumed` 觸發而其他生命週期不觸發／信號觸發／併發 check 只導航一次／in-flight 期間的觸發結束後補跑（D8）／`dispose()` 後即使 store 讀取已在途也不導航／dispose 前排到的補跑那一圈連 `take()` 都不做（`take` 是讀後即刪，跑下去會把一筆有效交接無聲吃掉）。
- **安靜重載的單元測試**（`CareTodayController.reloadQuietly`）：重載期間 `status` 不曾掉到 `loading`／重載失敗保留既有 slots 且維持 `loaded`／401 仍路由 reauth／in-flight 期間的第二次重載被忽略／初次 `load` 在途時的重載被忽略。這些正是 D9 那條「安靜」承諾唯一能被自動釘住的地方。
- **D2 契約測試**：SW（JS）與 adapter（Dart）各硬編一份 cache name／key／欄位名，拼錯會整條靜默失效。一個測試讀 `web/push_sw.js` 原始碼，用 adapter 裡宣告的常數值去斷言 worker 用的是同一組值 —— 兩邊互不 import，只能做文字比對。**另外斷言 key 以 `/` 開頭**：只比對「兩邊相同」的話，兩側同時去掉斜線仍會全綠，但實際上各自依 base 解析成不同 URL，整條交接靜默失效。
- **widget 測試**：注入 fake store，驗證 app 啟動後 push 到 `/care-today` 且底下那層仍是首頁（`push` 而非 `go`）—— 這條測試同時釘住 D6 那個「post-frame 時 router 已離開 `/splash`」的時序假設；逾時的 pending 讓 app 停在首頁；store 拋例外不影響啟動；已在今日照護時的第二筆交接會重載清單，且該次重載用的是**當下重新取得的** token（fake auth 中途換 token，斷言後端收到新的那個）、重載失敗時清單仍在畫面上。
- **既有測試不得退化**：`test/app_redirect_test.dart` 全綠（D6 的前提是不動那套邏輯）。
- **實機驗證（需使用者在 Android 上做，非自動化）**：三個情境（冷啟動／背景／前景）各驗一次「進到今日照護 + 有返回箭頭 + 返回鍵回到原處」。**前景那一項先驗**，因為它同時驗證 D4 那個唯一沒有既有程式碼佐證的假設（跨 scope 的 `postMessage` 送得到）。

## 不做（YAGNI）

- 後端送目的地讓通知連到特定 slot —— 目前所有照護提醒都指向同一頁，等真的有多目的地再說（`push` handler 保留 `data.path` 的位置，但預設值涵蓋全部）。
- 改成 path URL strategy（`usePathUrlStrategy` + Pages SPA fallback）—— D1 已經讓目的地不依賴 URL，這個大改動失去理由，而且如果 WebAPK 是整個 URL 換成 `start_url`，改了也沒用。
- 定時輪詢 Cache —— D4 的信號 + D6 的四個觸發點已覆蓋所有已知情境，輪詢只是拿電力換一個沒被證實存在的漏網情境。
