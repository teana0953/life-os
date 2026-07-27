# 修復 Android PWA 推播 deep link（冷啟動）與返回箭頭

## 問題

點擊照護推播通知後，應該進到「今日照護」(`/care-today`)，實際行為分兩種：

| 情境 | 現況 | 期望 |
| --- | --- | --- |
| PWA 已在執行（背景） | **有**進到今日照護，但沒有返回箭頭，返回鍵離開 app | 進到今日照護，且可返回原本頁面 |
| PWA 冷啟動（task 已清） | 停在首頁 | 進到今日照護，可返回首頁 |

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

`notificationclick` 時 SW 把目標路徑寫進 Cache Storage（同源共享，SW 與頁面都能存取），app 端自己讀出來導航。URL 不再是傳遞目的地的必要管道，於是 WebAPK 丟不丟 fragment 都不影響。

選 Cache Storage 而非 IndexedDB：讀寫各一行 (`cache.put` / `cache.match`)，不需要開 DB、升級 schema、處理 `onupgradeneeded`。存的是「一筆會被立刻消費掉的短命記錄」，不需要 IndexedDB 的查詢能力。

localStorage 不可用 —— service worker 沒有它。

### D2 — SW 依既有 window 分岔：focus 或 openWindow

```
notificationclick
  → 寫 pending 到 Cache
  → matchAll({ type: 'window', includeUncontrolled: true })
      有既有 window → client.focus()      （不導航，保住使用者原本的頁面堆疊）
      沒有          → clients.openWindow() （冷啟動）
```

`includeUncontrolled: true` 讓 `/push/`-scope 的 SW 也看得到 `/`-scope 的 app window（現有註解說看不到，只在沒帶這個旗標時成立）。`WindowClient.navigate()` 仍然不能用 —— 它要求 client 被此 SW 控制 —— 但 `focus()` 沒有這個限制，而導航本來就交給 app 自己做。

對既有 window 只 focus 不導航是刻意的：使用者原本可能停在飲食頁，導航會洗掉那層堆疊，違反 D3 的返回語意。

### D3 — 導航用 `push`，疊在既有堆疊之上

消費 pending 時用 `context.push(path)` 而非 `go`：

```
冷啟動：        [首頁] → push → [今日照護]        返回鍵 → 首頁
已在執行（飲食）：[首頁] → [飲食] → push → [今日照護]  返回鍵 → 飲食
```

這同時修好返回箭頭，並與 app 內既有的進入方式一致（總覽卡片、更多頁都是 `context.push('/care-today')`）。

### D4 — 消費時機：auth 就緒之後，以及每次回到前景

兩個觸發點：

1. **啟動後**：必須等 auth 不再 `loading` 且已登入才消費。冷啟動時 auth 還在 bootstrap，router 被 `resolveAuthRedirect` 壓在 `/splash`，此時 push 會被 redirect 吃掉並改由 `pendingDeepLink` 以 `go` replay —— 那條路徑沒有返回箭頭，正是 D3 要避免的。
2. **回到前景**：`WidgetsBindingObserver.didChangeAppLifecycleState(resumed)`，比照既有的 `PwaUpdateController`。這是「app 在背景被 focus」情境的觸發點。

`resolveAuthRedirect` 與其 `pendingDeepLink` 機制**完全不動** —— 它處理的是「URL 本來就帶著 deep link 的冷啟動」（例如手動輸入網址、桌機瀏覽器分頁），仍然有效，且已有完整測試。

### D5 — 時效與讀後清除

寫入時附時戳，消費時：**先清除、再判斷時效**（讀後即刪，無論採不採用），逾時者丟棄不導航。TTL 取 **5 分鐘**。

防的是這個情境：SW 寫了 pending 但 app 始終沒開起來（使用者點了通知又立刻切走、或啟動失敗），殘留值會在下一次「使用者自己打開 app」時劫持導航，把人莫名其妙丟到今日照護。5 分鐘足夠涵蓋正常的「點通知 → app 起來」延遲，又短到不會跨越到下一次自主開啟。

### D6 — `openWindow` 仍傳 `/#/care-today`，重複導航由 app 端去重

冷啟動的 URL 保留 hash 形式，因為在**桌機瀏覽器分頁**情境下 `openWindow` 會正確帶著 fragment 開啟，是一條免費的 fallback。這會造成 Cache 與 URL 兩條路都生效、可能疊出兩層今日照護，因此消費 pending 前先檢查：**當前 location 已經是目標路徑就不 push**。

這個去重守門對所有情境都安全，不只針對這一個 case。

### D7 — 平台隔離比照既有 PWA 模組

`lib/shared/pwa/` 既有的三件組模式：抽象介面 + `export 'x_stub.dart' if (dart.library.js_interop) 'x_web.dart'`。Cache Storage 只有 web 有，非 web target（android/ios/VM 測試）用 no-op stub 保持可編譯，widget 測試注入 fake。

## 元件

| 檔案 | 職責 | 測試 |
| --- | --- | --- |
| `web/push_sw.js` | 寫 pending 到 Cache；focus 既有 window 或 openWindow | 無（瀏覽器端 glue，比照現況） |
| `lib/shared/pwa/pending_deep_link.dart` | 抽象介面 `take()` → `PendingDeepLink?`（路徑 + 時戳），conditional export | — |
| `..._stub.dart` / `..._web.dart` | 非 web no-op／Cache Storage 讀取＋刪除 | web impl 不測（薄 adapter，比照 `BrowserWebPushGateway`） |
| `lib/shared/pwa/pending_deep_link_controller.dart` | 生命週期觀察 + 時效判斷 + 去重 + 觸發導航 callback | **單元測試**（注入 fake gateway + 固定 now） |
| `lib/app.dart` | 接線：auth 就緒後 start controller，callback 打 `router.push` | widget 測試 |

判斷邏輯（時效、去重、要不要導航）全部落在 controller 這個**可測的純 Dart 層**，adapter 只做 Cache 讀寫，SW 只做寫入與 focus/open 分岔 —— 沿用專案既有的「薄 adapter + 可測 controller」分工。

## UI/UX 設計

### 使用者路徑

**主路徑（冷啟動）**：使用者收到照護提醒 → 點通知 → PWA 啟動 → 首頁短暫出現（auth bootstrap）→ 自動疊上今日照護 → 使用者按 Done/Skip → 按返回箭頭或返回鍵回到首頁。

**主路徑（app 在背景）**：點通知 → PWA 帶到前景，停在使用者原本那一頁 → 自動疊上今日照護 → 返回鍵回到原本那一頁。

**例外路徑**：
- 未登入：點通知 → 走既有登入流程 → 登入後才消費 pending → 疊上今日照護。
- pending 逾時（>5 分鐘）：不導航，使用者停在正常的啟動畫面（首頁），與沒點通知一樣。
- 已經在今日照護頁：不重複疊加，畫面不變。

### 介面與一致性

不新增任何畫面或元件。導航後看到的就是既有的 `CareTodayScreen`，返回箭頭由 go_router 的 `push` 自動提供，與從總覽卡片、「更多」頁進入時完全一致 —— 使用者不會感覺到「從通知進來」和「自己點進來」是兩種東西。

### 狀態設計

- **loading**：冷啟動時先出現既有的 splash（auth bootstrap），再落地首頁、疊上今日照護。今日照護頁自己的 loading／錯誤／空狀態沿用現況，不因來源是通知而不同。
- **導航失敗**：Cache 讀取失敗或 pending 逾時，一律**安靜地不導航**，app 停在正常啟動位置。不顯示錯誤訊息 —— 使用者的實際意圖（看照護項目）用 app 內既有入口一步就能達成，跳錯誤對話框只會擋路。
- **邊界**：多則通知連續點擊只會留下最後一筆 pending（同一個 key 覆寫），不會疊出多層。

### 可及性/理解性

導航是使用者主動點通知觸發的，結果與預期一致（點照護提醒 → 到照護頁），不需要額外說明文案。返回箭頭的存在讓「我可以回去」變成可見的、可操作的，而不是要靠猜測按系統返回鍵。

## 測試策略

- **controller 單元測試**（TDD 主戰場）：時效內採用／逾時丟棄／讀後即清（即使逾時也清）／當前已在目標路徑時不導航／auth 未就緒時不消費／resumed 時重新檢查。
- **widget 測試**：注入 fake gateway，驗證 app 啟動後會 push 到 `/care-today`，且返回堆疊有 parent（返回箭頭存在）。
- **既有測試不得退化**：`test/app_redirect_test.dart` 全綠（D4 的前提是不動那套邏輯）。
- **實機驗證（需使用者在 Android 上做，非自動化）**：清掉 PWA task → 送測試通知 → 點通知 → 應進到今日照護且有返回箭頭；app 在背景 → 點通知 → 應疊上今日照護且返回鍵回到原本頁面。

## 不做（YAGNI）

- 後端送 `url` 讓通知連到特定 slot —— 目前所有照護提醒都指向同一頁，等真的有多目的地再說。
- 改成 path URL strategy（`usePathUrlStrategy` + Pages SPA fallback）—— D1 已經讓目的地不依賴 URL，這個大改動失去理由，而且如果 WebAPK 是整個 URL 換成 `start_url`，改了也沒用。
- `postMessage` 即時通知既有 window —— `focus()` + `resumed` 生命週期已經覆蓋，多一條管道就多一種不同步。
