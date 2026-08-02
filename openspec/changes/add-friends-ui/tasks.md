# Tasks

分層由內而外,每層有測試才往下一層。重要邏輯(錯誤碼映射、deep link 重播、版面守門)一定要有測試 cover。

## 1. domain

- [ ] 1.1 `lib/contexts/social/domain/friend.dart`:`Friend`(`userId`/`displayName`)+ `fromJson`
- [ ] 1.2 `friend_invite.dart`:`FriendInvite`(`id`/`expiresAt`/`createdAt`)+ `fromJson`
- [ ] 1.3 `invite_preview.dart`:`InvitePreview`(`inviterDisplayName`/`alreadyFriends`)、`AcceptInviteResult`(`friend`/`alreadyFriends`)
- [ ] 1.4 `social_exceptions.dart`:typed error——`SocialFetchFailure`、`SocialReauthenticationRequired`、`SocialNotFound`(remove/revoke 的 404)、`InviteNotFound`(preview/accept 的 404)、`InviteExpired`、`InviteAlreadyUsed`、`InviteRevoked`、`CannotFriendSelf`。**不帶使用者文案**(文案在 presentation 映射)
- [ ] 1.5 `social_repository.dart`:port——`listFriends`/`removeFriend`/`createInvite`/`listInvites`/`revokeInvite`/`previewInvite`/`acceptInvite`,每個吃 `idToken`
- [ ] 1.6 測試:entity 的 `fromJson`(含缺欄位/型別錯誤時丟 `SocialFetchFailure`)

## 2. application

- [ ] 2.1 `friend_use_cases.dart`:`ListFriends`、`RemoveFriend`
- [ ] 2.2 `invite_use_cases.dart`:`CreateInvite`、`ListInvites`、`RevokeInvite`、`PreviewInvite`、`AcceptInvite`
- [ ] 2.3 測試:fake repository 實作 port,驗每個 use case 轉呼叫正確、錯誤原樣往上丟

## 3. infrastructure

- [ ] 3.1 `http_social_repository.dart`:`_send` 可照 `HttpFinanceRepository`,但**錯誤映射不能照抄** `_throwForStatus`——那支只看 status code、從不讀 body。這裡要吃整個 `http.Response`、解析 body 的 `error` 欄,且 **body 為空或不是 JSON 時不得丟 decode error**(退回 `SocialFetchFailure`)
- [ ] 3.2 錯誤映射:401 → `SocialReauthenticationRequired`;**404 依呼叫端分流**(preview/accept → `InviteNotFound`,remove/revoke → `SocialNotFound`);400 依 body `error` 欄(`invite_expired`/`invite_already_used`/`invite_revoked`/`cannot_friend_self`;`bad_request` → `InviteNotFound`,對使用者等同連結無效);其餘含 500 → `SocialFetchFailure`
- [ ] 3.3 測試(mock `http.Client`):逐條驗 method + path + `Authorization` header;**preview/accept 的 token 在 body、URL 不含 token**(這條是 spec 明列的要求,不能只驗有送出);每個錯誤碼各一測,**含 remove 的 404 不得變成 `InviteNotFound`** 這條

## 4. presentation — 好友頁

- [ ] 4.1 `friends_controller.dart`:`ChangeNotifier`,狀態 loading/loaded/error/needsReauth;`load`、`removeFriend`、`createInvite`、`revokeInvite`;動作進行中的 per-item busy 標記(供 UI disable)。**由 `FriendsScreen` 的 `State` 在 `initState` 建、`dispose` 釋放,不進 `main.dart` 單例、也不在 route builder 裡建**(design D9);明文 token 只放在這個 controller 的欄位裡。每個寫入動作(建立邀請/撤銷/解除)完成後**要讓列表反映結果**——建立邀請後新邀請要出現在未接受邀請列表、撤銷後消失、解除後好友消失、解除失敗(404,對方已不是好友)也要重新載入。**建立邀請後只能重新 fetch 邀請列表**,不能改本地狀態:`POST /api/friends/invites` 只回 `{ token, expires_at }`、**沒有 `id`**,而撤銷需要 id
- [ ] 4.2 `friends_screen.dart`:好友列表(名稱 + 解除)、未接受邀請列表(到期日 + 撤銷)、「邀請好友」動作
- [ ] 4.3 邀請連結呈現:**`<origin>/#/invite?token=…`**(design D12:app 跑 hash URL 策略且 Pages 沒有 SPA fallback,少了 `/#` 對方收到的是 404)全文可見 + 複製鈕 + 複製成功 SnackBar;origin 由注入的 `String Function()` 取得,預設 `() => Uri.base.origin` 但**必須是延遲求值的 closure**——VM 上 `Uri.base` 是 `file://`,`.origin` 會 throw `StateError`
- [ ] 4.4 解除好友的二次確認 dialog,文案指名對象;撤銷邀請**不**確認
- [ ] 4.5 空狀態:「還沒有好友」+ 邀請動作;錯誤狀態 + 重試;401 → 既有 reauth 出口
- [ ] 4.6 好友頁 AppBar 的返回:`canPop()` 為真就 pop,為假(直接開 URL、或從 `/invite` 進來)就 `go('/')`,不留死路
- [ ] 4.7 測試(注入 fake repository,**每個測試都要注入固定 origin** 如 `() => 'https://example.test'`,否則一渲染連結就 `StateError`):列表、空狀態、錯誤+重試、401、確認/取消解除、撤銷、remove 失敗(404)的文案不是連結無效那句、**建立邀請後新邀請出現在未接受邀請列表**、離開再回來連結不再顯示、`canPop()` 為假時的返回落在首頁
- [ ] 4.8 剪貼簿測試要真的驗到內容:`Clipboard.setData` 走 `SystemChannels.platform`,**沒裝 mock handler 的話呼叫會靜靜成功、測試什麼都驗不到**。用 `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler` 攔 `SystemChannels.platform`,取出 `Clipboard.setData` 的 `text` 參數,斷言等於完整的 `<origin>/#/invite?token=…`;`addTearDown` 拆掉 handler
- [ ] 4.9 到期日顯示:`parseInstant(expiresAt)`(`day_format.dart`,壞字串回 null,**不要 `DateTime.parse`**——那支會 throw)→ 可注入的 `toLocalTime`(照 `care_today_screen.dart` / `today_screen.dart` 的 `toLocalTime` + `_defaultToLocal`)→ `dayString(...)` → `mediumDateLabelOrDash`。**中間的 `dayString` 不能省**:`mediumDateLabelOrDash` 吃的是 `YYYY-MM-DD` 字串,直接餵 ISO 字串會一律得到「—」;null instant 要自己判、顯示同樣的「—」;測試要**注入固定偏移的 `toLocal`**釘住 UTC 午夜前後顯示的是本地日期——只寫「預期值從同一條轉換算出來」的測試在任何時區都會自動成立,什麼都證明不了(design D11)

## 5. presentation — 邀請接受頁

- [ ] 5.1 `invite_controller.dart`:進頁只 `preview`;`accept` 由使用者動作觸發;狀態涵蓋 preview 中/可接受/已是好友/接受中/成功/各錯誤。**由 `InviteScreen` 的 `State` 在 `initState` 建、`dispose` 釋放**(design D9),所以換一個 token 進來必然重新 preview;token 缺漏或空白時**不發 preview 請求**,直接進「連結無效」狀態
- [ ] 5.2 `invite_screen.dart`:「<名字> 邀請你成為好友」+ 接受鈕;接受中 disable
- [ ] 5.3 成功 → `context.go('/friends')`(**不是 push**:已消耗的落地頁不該留在 in-app stack。注意這**擋不住**瀏覽器返回鍵回到 `/invite`——那走的是瀏覽器 history;兜住它的是後端會回 `already_friends`);已是好友 → 專屬文案 +「回到好友列表」(措辭與剛成功不同)
- [ ] 5.4 失敗各自的可行動文案(過期/已用/已撤銷/連結無效)+ 回好友列表;**自己的邀請只有按下接受後才會知道**(design D10:後端 preview 不做自我比對、回應也沒有 user id),那時顯示「這是你自己發出的邀請」
- [ ] 5.5 測試:preview 成功後**尚未**送出 accept、accept 成功、already_friends、各錯誤碼各一、**自己的邀請走「preview 成功 → accept 才報錯」這條路**、token 空白時不發請求

## 6. 接線與路由

- [ ] 6.1 `app.dart` 加 `/friends` 與 `/invite`(token 由 `state.uri.queryParameters['token']` 取);**`InviteScreen` 要帶 `key: ValueKey(token)`**——go_router 的 `pageKey` 只認 path pattern 不含 query,不給 key 的話換一條邀請連結會沿用同一個 `State`、顯示前一個邀請人並消耗前一張 token(design D13,靜默錯誤);builder 由注入的 use case **現建 controller**(design D9);畫面吃 `authRepository`(自己取 id token)**與 auth context 的 `SignOut`**(401 出口那顆鈕要登出,照 `HealthScaffold`),**不用 `app.dart` 的 `_idToken`**(那是上次 `authStateChanges` 的快照、不隨續期更新,長 session 會 401)
- [ ] 6.2 `main.dart` 手動 DI:只注入**無狀態**的 `HttpSocialRepository` + use cases,不建 controller
- [ ] 6.3 `settings_screen.dart` 新增私有 `_NavRow`(`ListTile` + 右側 chevron + test key)——既有的 `_OptionRow<T>` 模擬的是可選選項(`value`/`groupValue`/`onSelected` + 圓圈),不能拿來當導航列
- [ ] 6.4 設定頁加「好友」列(用 `_NavRow`)→ **`context.push('/friends')`**;全 repo `context.go(` 零次、`context.push(` 23 次,且 `go` 會換掉整個 stack 造成死路
- [ ] 6.5 `test/app_test.dart` 的 `pumpApp`(另被 `test/app_pending_deep_link_test.dart` 引用)補上帶預設 fake 的 social 依賴;`App` 新增的參數若給預設值則兩檔都不用動——**影響範圍是 2 個檔,不是 30 個**
- [ ] 6.6 測試:同一個 router 先後導到 `/invite?token=a` 與 `/invite?token=b`,第二次顯示的必須是第二個邀請人(釘住 D13 的 `ValueKey`)
- [ ] 6.7 測試:設定頁的「好友」列點下去會到好友頁——用既有的 `l10nRouterTestApp`(`test/support/l10n_test_app.dart`),它對沒對到的 push 會渲染 `Text(state.matchedLocation)`,所以斷言就是 `find.text('/friends')`
- [ ] 6.8 測試:`resolveAuthRedirect` 對 `/invite?token=abc` 的捕捉與重播,**query 不得遺失**(不改 `resolveAuthRedirect` 本身,只釘住行為——review 已確認既有實作正確)

## 7. i18n 與版面守門

- [ ] 7.1 三個 ARB 檔(`app_en` 含 `description`、`app_zh_Hant`、`app_zh`)新增全部文案;`flutter gen-l10n` 產生的檔一併 commit
- [ ] 7.2 版面守門:`/friends` 與 `/invite` 在 320dp / 360dp × 各支援 locale × textScale 1.0 / 2.0 零 layout error(用既有 `test/support/layout_guard.dart`);**這些測試同樣要注入固定 origin**,否則渲染連結時 `Uri.base.origin` 會 throw
- [ ] 7.3 長名字守門:好友名稱過長時換行或縮放,右側動作仍完整可見可點

## 8. 收尾

- [ ] 8.1 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test` 全綠
- [ ] 8.2 `TZ=UTC flutter test` 複驗(到期日顯示碰日期,本機 UTC+8 / CI UTC 兩種失敗模式都踩過)
