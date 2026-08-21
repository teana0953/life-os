## 1. 先把根因釘成紅燈（每一條都必須在動產品程式碼前先紅）

- [x] 1.1 在 `test/app_pending_deep_link_test.dart` 加「交接目的地是 app 認不得的路徑時停在首頁、
      不出現任何錯誤畫面」的測試；驗證：現況執行時紅在 `Page Not Found`（`find.text('Page Not Found')`
      找得到），而不是紅在別的斷言
- [x] 1.2 加一個 `getToday` **永不 settle** 的假 repository（`Completer().future`，不是立刻丟例外）
      到 `test/app_pending_deep_link_test.dart`，寫「從通知進入今日照護後，逾時內出現可重試的錯誤
      而不是持續 spinner」的測試（用 `tester.pump(duration)` 推進時間，不做真實等待）；
      驗證：現況紅在畫面仍是 `CircularProgressIndicator`
- [x] 1.3 接著 1.2 的情境，加「卡住後再來一次交接會再送出一次 `getToday`」的測試，斷言請求計數 ≥ 2；
      驗證：現況紅在計數 == 1
- [x] 1.4 加「連續 8 次交接（目的地交替）之後，一次返回就回到第一次點通知前的畫面」的測試；
      驗證：現況紅在需要 8 次 `pageBack`
- [x] 1.5 在 `web/push_sw.js` 的契約測試裡加「SW 原始碼不再含硬編的 `/care-today` 預設」的斷言；
      驗證：現況紅
- [x] 1.6 在 `test/shared/pwa/pending_deep_link_controller_test.dart` 加「`take()` 永不 settle 之後，
      下一次 `check()` 仍然會被處理」的測試；驗證：現況紅（`_checking` 永久鎖死）
- [x] 1.7 `flutter test` 全跑一次，確認 1.1–1.6 是**唯一**的紅燈，且每條紅在預期的斷言上
      （逐條打開失敗訊息看，不只看紅字數量）

## 2. 通知帶著自己的目的地（design D1）

- [x] 2.1 `web/push_sw.js` 的 `push` handler 改成只在 payload 真的帶得出目的地時才寫進
      `showNotification` 的 `data`；驗證：契約測試 1.5 轉綠
- [x] 2.2 加入 design D1 明確標示為過渡的照護相容分支（可辨識為照護提醒時映射到 `/care-today`），
      常數與 Dart 端同一份；驗證：契約測試同時釘住「有相容分支」與「沒有無條件預設」兩件事
- [x] 2.3 `notificationclick` 在讀不到目的地時**不寫 Cache**，只做 focus／openWindow；
      驗證：契約測試斷言這條分支存在，且 `notificationclick` 仍在兩條路徑上都會帶前景
- [x] 2.4 更新 `openspec/specs` 之外的相關註解（`push_sw.js` 內指向舊 D2/D9 的敘述），使其與新契約
      一致；驗證：`rg '/care-today' web/push_sw.js` 只剩相容分支那一處

## 3. 認不得的路徑不再是死路（design D2 + D3）

- [x] 3.1 在 `lib/app.dart` 為 `PendingDeepLinkController` 補一個「app 認不認得這個路徑」的注入
      callback，實作用 `_router.configuration.findMatch(...)`，不另抄白名單；驗證：測試 1.1 轉綠
- [x] 3.2 `PendingDeepLinkController` 在 `take()` 之後、導航之前套用該 callback；認不得就照常
      消費掉（讀後即刪）但不導航；驗證：controller 單測涵蓋「認不得的路徑被消費但不導航」
- [x] 3.3 為 `GoRouter` 補 `errorBuilder`：本地化訊息 + 回首頁的控制項，新增對應的 ARB 詞條
      （en/zh 都要）；驗證：新增 widget 測試把 router 帶到 unmatched location，斷言看到本地化文案
      且控制項按下去回到首頁
- [x] 3.4 確認 `errorBuilder` 的文案在兩種語系下都不是英文預設；驗證：i18n 測試（比照既有 i18n 守門）

## 4. 等待要有結局（design D5 + D6）

- [x] 4.1 `CareTodayController` 的 `load()`／`reloadQuietly()` 各套一個有界逾時（涵蓋取 id token
      那一段），`_fetching` 一律在 `finally` 釋放；驗證：controller 單測「永不 settle 的 getToday
      逾時後落到可重試的 error」
- [x] 4.2 把「被單飛旗標擋下就直接 return」改成後到者 `await` 目前那一輪的已解析 Future；
      驗證：controller 單測「第二個 `load()` 拿到與第一個相同的結果，而不是留在 `loading`」
- [x] 4.3 讓使用者發動的重試／通知重載在前一輪已逾時時開新的一輪；驗證：測試 1.3 轉綠
- [x] 4.4 `PendingDeepLinkController` 的 `_store.take()` 套有界逾時；驗證：測試 1.6 轉綠
- [x] 4.5 檢查 `CareTodayScreen` 在 4.1 的 error 狀態下確實顯示既有的重試控制項（不是空白）；
      驗證：widget 測試 1.2 轉綠且找得到重試按鈕

## 5. 不再疊層（design D4）

- [x] 5.1 `PendingDeepLinkController` 的去重從「只比對最上層」改成「目的地在堆疊中的任何一層就收回
      到那一層並重載」，導航 callback 相應擴充；驗證：測試 1.4 轉綠
- [x] 5.2 confirm 既有的「已在目的地就安靜重載」行為沒有退化；驗證：既有的
      `app_pending_deep_link_test.dart` 去重／重載測試維持綠

## 6. 前景觸發不綁單一訊號（design D7）

- [x] 6.1 在 `lib/shared/pwa/pending_deep_link_web.dart` 把 `document.visibilitychange`（轉為
      visible）與 `window.focus` 併入 `handoverSignals`，並在 `onCancel` 一併移除監聽；
      驗證：`flutter build web` 通過（此 adapter 依既有慣例不做 VM 單測），且註解說明為何不能只靠
      `postMessage`
- [x] 6.2 controller 單測補「任一信號都會觸發一次 check」；驗證：單測綠且拿掉信號訂閱會讓它紅

## 7. 突變驗證與收尾

- [x] 7.1 對 2/3/4/5 每一個修法各做一次突變（把修法改回舊行為），確認對應的守門真的紅，且紅在
      「使用者看得到的那條斷言」上；驗證：逐條記錄突變 → 失敗清單
- [x] 7.2 `TZ=UTC flutter test` 與本機時區各跑一次全套；驗證：兩次都 `All tests passed!`
      （不是「沒有紅字」）
- [x] 7.3 `flutter analyze` 乾淨；`rg 'TODO|FIXME'` 沒有本次新增的殘留
- [x] 7.4 更新 `openspec/specs` 之外的相關文件：`web/push_sw.js` 檔頭契約說明與
      `lib/shared/pwa/pending_deep_link.dart` 的介面 doc；驗證：兩邊描述的欄位與新契約一致
- [ ] 7.5 實機驗證清單（Android PWA，需使用者操作）：冷啟動／背景／前景各一次照護提醒；
      一則非照護通知不再落到今日照護；連點多則通知後一次返回回到原處；離線／慢網路下今日照護
      逾時後出現可重試錯誤而不是永久 spinner
- [ ] 7.6 後續項（不在本 change 內，開 issue 追蹤）：後端開始送 `path` 之後刪除 design D1 的過渡
      相容分支與其契約斷言
