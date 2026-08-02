# 好友(sub-project 4,前端)— 設計

後端已在 `life-os-backend` main(PR #64,`/api/friends/*` 七條 endpoint 全綠)。本 change 只做前端:讓使用者能發邀請連結、對方點連結成為好友、看見與解除好友。分帳(sub-project 5/6)建在這之上,但**不在本 change 範圍**。

## 使用者已裁定

- **入口在設定頁**:設定頁加「好友」列 → 獨立 `/friends` 頁。好友不只服務財務(未來群組分帳、可能還有其他共享),放設定跟語言/主題/登出同層,不佔首頁與財務 nav 的格子。
- **邀請連結是 `/invite?token=xxx`**:token 在 query。使用者手上的連結本來就帶 token(那是他的憑證);後端只要求**打 API 時**改放 request body,連結本身不受限。會進瀏覽器歷史紀錄,但一次性 + 7 天過期已在後端擋住重放。
  **實際貼出去的網址是 `<origin>/#/invite?token=xxx`**(見 D12):這個 app 用 Flutter 的 hash URL 策略,go_router 內部位置仍是 `/invite`。

## 後端契約(已凍結,前端只是對接)

```
GET    /api/friends                   → { friends: [{ user_id, display_name }] }
DELETE /api/friends/:friendUserId     → { deleted: true } | 404
POST   /api/friends/invites           → { token, expires_at }        ← 明文 token 只在這裡出現一次
GET    /api/friends/invites           → { invites: [{ id, expires_at, created_at }] }
DELETE /api/friends/invites/:id       → { revoked: true } | 404
POST   /api/friends/invites/preview   body { token } → { inviter_display_name, already_friends }
POST   /api/friends/invites/accept    body { token } → { friend: {...}, already_friends }
```

錯誤碼(前端要能分辨,不能全部糊成一句「失敗」):

| HTTP | `error` | 前端語意 |
|---|---|---|
| 401 | — | 需要重新登入(既有 `needsReauth` 慣例) |
| 404 | `not_found` | **看呼叫的是哪條**:preview/accept → 連結無效;revoke → 該邀請已不在;remove → 對方已不是好友 |
| 400 | `invite_expired` | 邀請已過期 |
| 400 | `invite_already_used` | 邀請已被使用 |
| 400 | `invite_revoked` | 邀請已被撤銷 |
| 400 | `cannot_friend_self` | 不能加自己 —— **只有 accept 會回,preview 不會**(見 D10) |
| 400 | `bad_request` | token 缺漏/空白(例如 `/invite?token=`),對使用者等同「連結無效」 |
| 500 | `internal` | 一般失敗 |

**404 不能一刀切**(proposal review 抓到):`DELETE /api/friends/:friendUserId` 與 `DELETE /api/friends/invites/:id` 失敗時同樣回 404 `not_found`,若統一映射成 `InviteNotFound`,解除好友失敗會顯示「連結無效,請確認是否複製完整」——牛頭不對馬嘴。映射由**呼叫端**決定:invite 相關的 404 → `InviteNotFound`,remove/revoke 的 404 → `SocialNotFound`(各自的文案)。

## 架構

新 bounded context `lib/contexts/social/`,照 `contexts/finance/` 的四層佈局:

- `domain/`:`friend.dart`(`userId`/`displayName`)、`friend_invite.dart`(`id`/`expiresAt`/`createdAt`)、`invite_preview.dart`(`inviterDisplayName`/`alreadyFriends`)、`social_repository.dart`(port)、`social_exceptions.dart`(typed errors,**不含文案**)。
- `application/`:薄 use case。照 `networth_use_cases.dart` 的先例合成兩檔——`friend_use_cases.dart`(list/remove)、`invite_use_cases.dart`(create/list/revoke/preview/accept),不是七個單檔。
- `infrastructure/`:`http_social_repository.dart`。**不能照抄** `HttpFinanceRepository` 的 `_throwForStatus`——那支只看 status code、從不讀 body,而這裡四種 400 要靠 body 的 `error` 欄分辨。這裡的版本吃整個 `http.Response`,先試著把 body 當 JSON 解析,**解析失敗或 body 為空時不得丟 decode error**,退回一般失敗。
- `presentation/`:`friends_controller.dart` + `friends_screen.dart`、`invite_controller.dart` + `invite_screen.dart`。

DI 在 `main.dart` 手動接;`/friends` 與 `/invite` 兩條 `GoRoute` 加在 `app.dart`(builder 只吃注入的 use case、不帶 `extra`,web 重新整理該 URL 可重建——既有註解已把這條訂成規矩;controller 由畫面自持,見 D9)。

**id token 由畫面自己取,不用 `app.dart` 的 `_idToken`。** 後者是上一次 `authStateChanges` 的快照、不隨 token 續期更新,長時間開著的 session 會 401。照 `FinanceScaffold` 的先例:畫面吃 `authRepository`,每次請求前 `await authRepository.idToken()`。

## 決策要點

**D1 邀請連結的 origin 由注入取得,不寫死。** 連結要組成絕對網址才能貼給別人。web 上是 `Uri.base.origin`,但在 `flutter test` 的 VM 上 `Uri.base` 是 `file://` URI,`.origin` **會 throw `StateError`**——不是「測試綁在 VM 的 Uri.base」而已,是直接炸。所以:
- 連結是在**好友頁**組出來的(邀請頁只負責接受),注入對象是 `FriendsScreen`/`FriendsController`,**不是** `InviteController`。
- 參數是 `String Function() origin`,預設 `defaultInviteOrigin` 這個**延遲求值的 closure**——只建畫面不渲染連結時永遠不會被呼叫,所以單純 pump 畫面不會炸。closure 裡再依平台分岔:web 用 `Uri.base.origin`(當下真正的 origin),非 web 用設定值 `appWebOrigin`(`shared/config.dart`,可用 `--dart-define=APP_WEB_ORIGIN=` 覆寫)——正式環境沒有任何地方注入 origin,預設若直接讀 `Uri.base.origin`,原生 build 一渲染連結就 `StateError`。
- **每個 widget 測試都必須注入固定值**(如 `() => 'https://example.test'`),包含 320/360dp 版面守門,否則一渲染連結就是 `StateError`。

**D2 先預覽再接受,不自動接受。** 點連結進來只呼叫 `preview`,畫面顯示「<名字> 邀請你成為好友」+ 明確的「接受」鈕。理由:token 一次性,自動接受會在使用者還沒看清是誰、甚至誤點別人轉貼的連結時就把邀請消耗掉;預覽本身不消耗(後端只讀)。

**D3 已是好友:誠實說,不假裝成功。** `already_friends=true` 時(preview 或 accept 都可能回)顯示「你們已經是好友」,主要動作改成「回到好友列表」。後端 accept 在這情況是 idempotent、不消耗第二張邀請,前端不需要特別處理,但**訊息不能跟「剛剛成功加為好友」長一樣**——那會讓使用者以為邀請被用掉了。

**D4 分享用複製到剪貼簿,不引入 share_plus。** `Clipboard.setData` 是 Flutter 內建、web 可用,一個依賴都不加。連結全文同時以可選取的文字顯示,剪貼簿在某些瀏覽器情境被擋時仍有退路。Web Share API 的原生分享單留待日後有需求再評估——記為有意識的取捨,不是漏掉。

**D5 明文 token 只存在於記憶體,而且靠 controller 的生命週期保證。** `POST /api/friends/invites` 回的 token 只用來組連結顯示,不寫 `shared_preferences`、不進任何 log、不放進錯誤訊息。「頁面離開即消失」是 D9 的畫面自持 controller 在保證的——這句是設計約束,不是能靠操作 UI 驗出來的 spec 要求,所以留在這裡,spec 那邊改寫成可驗的行為(離開再回到好友頁時不再顯示上次的連結)。

**D6 未登入點連結靠既有機制,不新寫。** `app.dart` 的 `resolveAuthRedirect` 在 auth 還在 `loading` 時會把**完整 URI(含 query)**捕捉進 `pendingDeepLink`,登入或註冊完成後、人還停在 auth gate 上時重播。`/invite?token=…` 符合它的捕捉條件(不是 `/`、不是 transient、不是 gate)。本 change 只需**加測試釘住這條路徑**(含 query 不被丟掉),不改 `resolveAuthRedirect` 本身。

**D7 解除好友要二次確認。** 這是破壞性且對方也看得到的動作,用既有的確認 dialog 慣例;文案要指名對象(「解除與 <名字> 的好友關係?」),不是泛泛的「確定嗎?」。

**D8(已推翻)撤銷邀請也要二次確認。** 原本寫的是「不需二次確認:邀請還沒被接受、撤銷不影響任何既有關係,重發成本近乎零」。UI/UX review 指出這條算錯了成本的落點:**成本不落在按鈕的人身上,而落在對方**——對方手上那條連結會無聲失效,按下「接受」只會看到「這個邀請已被撤銷」,而發送方永遠不會知道。加上未接受的邀請列表原本只顯示到期日,同一天建立的兩張邀請長得一模一樣,撤錯了也分不出來。因此改成:列表每列同時顯示**建立時間(含 HH:mm)**與到期日以便辨識,撤銷前跳確認 dialog 並說明「已傳出去的連結會失效」。現在 D7/D8 一致:兩個對第三人可見的破壞性動作都要確認。

**D9 兩個 controller 由畫面的 `State` 持有,不當 app 生命期單例、也不在 route builder 裡建。**(proposal review 第四條 + 第二輪修正)`main.dart` 只注入**無狀態**的 `SocialRepository` 與 use case;`GoRoute` 的 builder 只把 use case 傳下去;`FriendsController`/`InviteController` 由 `StatefulWidget` 的 `State` 在 `initState` 建、`dispose` 釋放,隨畫面生滅。

**為什麼不在 builder 裡建**:go_router 在每次 Router rebuild 時都會重跑 `GoRoute.builder`,而 `app.dart` 的 `MaterialApp.router` 會因為語言或主題切換而 rebuild——在 builder 裡建 controller 等於「使用者切一次語言,剛產生的明文邀請連結就消失、進行中的 preview/accept 被重設,而且舊 controller 永遠不會 dispose」。repo 既有的 `_UrlDictionaryScreen` 就是用 `State` 持有易失物件的先例,照它做。理由不是風格偏好:`app.dart` 的 `_resetControllersOnSignOut` 只重設列在裡面的三個 controller,任何新加的單例都要記得補進去,漏了就是**登出換帳號後前一個人的好友列表與明文邀請連結還在**——這專案已經反覆長出這類「單例狀態殘留」。per-route 建構讓這個問題不存在,順帶解掉兩件事:同一個 `/invite` 頁換不同 token 進來會重新 preview(controller 是新的),以及 accept 成功後好友頁是新建的、必然重新載入。

**D10 「自己開自己的邀請」只在按下接受後才會知道。**(proposal review 抓到的第一條)後端 `preview-invite.ts` 完全沒有自我比對,回應也只有 `{ inviter_display_name, already_friends }`、沒有 user id,所以前端**判不出來**、後端也不會在 preview 回 `cannot_friend_self`。實際行為:開自己的連結會**預覽成功**、顯示自己的名字、給一顆接受鈕;按下去才拿到 400 `cannot_friend_self`,這時顯示「這是你自己發出的邀請」。這是有意接受的取捨(改後端不在本 change 範圍),不是漏掉——設計與 spec 都照這個真實行為寫。

**D11 到期日照 repo 既有的日期工具走,不自己 parse。** `expires_at` 是 UTC ISO 字串。用 `day_format.dart` 既有的 `parseInstant`(內部是 `tryParse`,壞字串回 null 而不是 throw)+ `mediumDateLabelOrDash`(null 時降級成「—」),**不要用 `DateTime.parse`**——那支會 throw,一個壞欄位就炸掉整頁。轉本地時區用既有的**可注入 `toLocal`**(`care_today_screen.dart`/`today_screen.dart` 的先例),測試才驗得到跨時區行為:光靠 8.2 的 `TZ=UTC` 複驗,「預期值從同一條轉換算出來」的測試在兩種時區下都會自動成立、什麼都證明不了。至少要有一個測試**注入固定偏移的 `toLocal`**,釘住 UTC 午夜前後的到期日顯示的是本地日期。

**D12 邀請連結必須帶 `/#/`。** 這個 app 沒有呼叫 `usePathUrlStrategy`(repo 全域搜不到,也沒依賴 `flutter_web_plugins`),跑的是 Flutter 預設的 **hash** URL 策略——`web/manifest.json` 的捷徑全部是 `/#/health/...` 就是證據。而且部署是 `wrangler pages deploy build/web`,`web/` 底下沒有 `_redirects` 也沒有 `404.html`,**沒有 SPA fallback**:`GET /invite?token=…` 在 Cloudflare Pages 上是實實在在的 404,收到連結的人連 app 都載不到。所以組出來的連結是 `<origin>/#/invite?token=<token>`;go_router 內部的 route 位置仍然是 `/invite`,兩者不衝突。

**D13 `/invite` 換 token 進來必須真的重來一次。** go_router 的 `pageKey` 是 `ValueKey(matchedPath)`——**只認 path pattern,不含 query**。同一個 `/invite` 換成 `?token=B`,Page key 沒變、widget 型別沒變,Flutter 會沿用同一個 `State`,連同裡面那個還握著 token A 預覽結果的 `InviteController`:使用者開第二條邀請連結,畫面顯示的是第一個人,按下接受消耗的是第一張 token。**這是靜默的錯誤資料,不會有任何例外。** 修法:route builder 給 `InviteScreen` 一個 `key: ValueKey(token)`,強制換 token 就換 `State`(`_UrlDictionaryScreen` 走的是另一條路——`didUpdateWidget`,兩種都行,選前者因為 controller 的重建邏輯全在 `initState` 一處)。這條**要有測試**:同一個 router 先後導到兩個不同 token,第二次顯示的必須是第二個邀請人。

## UI/UX 設計

### 使用者路徑

**主路徑 A — 發邀請**:設定 →「好友」→ 好友頁 →「邀請好友」→ 產生連結 → 複製 → 用任何通訊軟體貼給對方。頁面同時列出我還沒被接受的邀請,每張顯示到期日與「撤銷」。

**主路徑 B — 接受邀請**:對方在手機開連結 → (未登入 → 登入/註冊 → 自動回到這條連結) → 看到「<名字> 邀請你成為好友」→ 按「接受」→ 成為好友 → 進到好友頁,列表已含對方。

**例外路徑**:連結無效/過期/已被用/已撤銷 → 各自的訊息 + 「回到好友列表」;已經是好友 → D3;自己開自己的連結 → 預覽會成功(D10),按下接受才顯示「這是你自己發出的邀請」。

### 介面與一致性

- 好友頁沿用既有 `Scaffold` + 卡片語彙。
- 設定頁的「好友」列放進既有 `_SettingsSection`(它收任意 children),但**列本身要新寫**:既有的 `_OptionRow<T>` 模擬的是「可選選項」(吃 `value`/`groupValue`/`onSelected`,畫實心/空心圓),不是導航。新增一個私有 `_NavRow`(`ListTile` + 右側 chevron + test key)。
- 導航用 **`context.push('/friends')`**。全 repo `context.go(` 零次、`context.push(` 23 次;設定頁本身是被 push 的,登出收尾還靠 `canPop()`。`go` 會換掉整個 stack,而 `/friends` 是頂層 route(底部 nav 在 `HealthScaffold`/`FinanceScaffold` 裡,沒有 ShellRoute)——用 `go` 會讓使用者落在一個沒有返回、也沒有 nav 的死路。`/invite` 是外部連結進來的落地頁,冷啟動時 stack 裡只有它一頁,往回沒有東西可回——所以接受成功後改用 `go('/friends')`,把已經消耗掉的落地頁換掉,不留在 in-app stack 裡。**注意這不能保證瀏覽器返回鍵不會回到 `/invite`**:瀏覽器走的是自己的 history,`go` 與 `push` 都改變不了那一筆。真正兜住這件事的是後端——同一個人再開一次已接受的連結會拿到 `already_friends`,顯示的是「你們已經是好友」而不是錯誤。
- **`/friends` 要能回得去。** 從設定 push 進來時有返回鍵;從 `/invite` `go` 進來、或使用者直接在 web 重新整理 `/friends` 時 `canPop()` 是 false,標準 AppBar 不畫返回鍵 → 又是一個死路。所以好友頁的 AppBar leading 自己判斷:`canPop()` 為真就返回,為假就 `go('/')` 回首頁。
- 好友列、邀請列的「名稱 + 右側動作」用既有共用元件 `LabelValueRow` 的同一套排版直覺;金額不涉入,但**兩邊都要有下限**的教訓照用——名稱長時換行,不把右側動作擠掉。
- 所有文案走 `AppLocalizations`,三個 ARB 檔(en / zh_Hant / zh)同步;錯誤文案在 presentation 映射,domain/infrastructure 只丟 typed error。

### 狀態設計

| 狀態 | 好友頁 | 邀請頁 |
|---|---|---|
| loading | 置中 spinner | 置中 spinner |
| 空 | 「還沒有好友」+ 說明可以怎麼加(直接給「邀請好友」動作),不是空白頁 | — |
| 錯誤 | 訊息 + 「重試」 | 依錯誤碼給對應說明 + 「回到好友列表」 |
| 401 | 既有 `needsReauth` 出口(「重新登入」)——**那顆鈕會登出**,所以畫面除了 `authRepository` 還要注入 auth context 的 `SignOut`(照 `HealthScaffold`;`main.dart` 已經建了一個給 `App`) | 同左 |
| 動作進行中 | 該列動作鈕 disabled,避免重複送出 | 「接受」鈕 disabled |

### 可及性/理解性

- 每個錯誤都要**可行動**:過期 → 「請對方重新產生一個連結」;已被用 → 「這個邀請已經被使用過了」;無效 → 「連結無效,請確認是否複製完整」。不出現「發生錯誤(400)」這種只有工程師看得懂的句子。
- 複製成功要有回饋(SnackBar),否則使用者不知道有沒有複製到。
- 破壞性動作(解除好友)的確認 dialog 指名對象。
- 版面守門:`/friends` 與 `/invite` 兩頁都要有 320/360dp × en/zh × textScale 1.0/2.0 的零 layout exception 測試。這個專案先前整批窄螢幕溢出都是因為 widget 測試跑在預設 800×600 才漏掉的,新頁面不重蹈。

## 測試策略

- **domain/application**:fake repository 實作 port,測 use case 與錯誤傳遞。
- **infrastructure**:mock `http.Client`,逐條驗 request(method/path/**token 在 body 不在 URL**/Authorization header)與六種錯誤碼映射。
- **presentation**:注入 fake repository 的 widget test——空狀態、錯誤狀態、複製、撤銷、解除確認、preview/accept 三種結果(成功 / 已是好友 / 各錯誤碼)。
- **routing**:`resolveAuthRedirect` 對 `/invite?token=…` 的捕捉與重播(D6),query 不得遺失。
- **版面**:上述 320/360dp 守門。
- 重要邏輯一定要有測試 cover(專案既定政策);不強制先寫測試,但錯誤碼映射與 deep link 重播兩塊必須有。

## 不做(明確排除)

- 不做好友暱稱/備註、不做頭像、不做搜尋加好友(後端只認邀請連結)。
- 不做原生分享單(D4)。
- 不做邀請數量上限的前端提示(後端刻意無上限)。
- 分帳、群組、settle up 全部留給 sub-project 5/6。
