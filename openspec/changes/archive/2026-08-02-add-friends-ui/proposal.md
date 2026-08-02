## Why

好友後端已上(life-os-backend PR #64):邀請 token(SHA-256 存雜湊)、一次性 + 7 天過期、預覽/接受、好友列表、解除、撤銷,七條 endpoint。但前端一條都沒接——使用者發不出邀請,連結也沒有畫面可落地。本 change 補上前端,sub-project 4 閉環,並為 sub-project 5(群組分帳)鋪路。

使用者裁定:入口放**設定頁**一列(好友不只服務財務,不佔首頁與財務 nav 的格子);邀請連結形式 **`/invite?token=xxx`**(實際貼出去帶 hash:`<origin>/#/invite?token=xxx`,見 design D12)。

## What Changes

- 新 bounded context `lib/contexts/social/`(domain / application / infrastructure / presentation),照 `contexts/finance/` 佈局。
- `SocialRepository` port + `HttpSocialRepository`:對接 `/api/friends/*` 七條;**token 一律走 request body,不進 URL**;401 → `SocialReauthenticationRequired`;**404 依呼叫端分流**(邀請相關 → 連結無效,解除好友/撤銷邀請 → 各自的文案);400 依 body 的 `error` 欄映射成 typed error(過期 / 已被使用 / 已撤銷 / 不能加自己 / token 缺漏)。
- `/friends` 頁:好友列表(只顯示名稱)、解除好友(**指名對象的二次確認**)、我發出的未接受邀請(到期日 + 撤銷,不二次確認)、「邀請好友」產生連結並複製到剪貼簿。
- `/invite?token=…` 頁:先 `preview` 顯示「<名字> 邀請你成為好友」,由使用者按「接受」才 `accept`(一次性 token,不自動消耗);已是好友、過期、已被用、已撤銷各有可行動的說明。**自己的邀請只有按下接受後才會知道**——後端 preview 不做自我比對、回應也沒有 user id(design D10)。
- 設定頁新增私有 `_NavRow`(既有 `_OptionRow<T>` 是可選選項不是導航)+「好友」列 → `context.push('/friends')`。
- `app.dart` 加 `/friends`、`/invite` 兩條 route;**controller 由畫面的 `State` 持有(`initState` 建、`dispose` 釋放),不進 `main.dart` 單例、也不在 route builder 裡建**(design D9,避免登出換帳號後殘留前一個人的好友列表與明文邀請連結);`main.dart` 只注入無狀態的 repository 與 use case。
- ARB 三檔(en / zh_Hant / zh)新增文案;錯誤文案映射在 presentation,domain/infrastructure 只丟 typed error。

範圍外:好友暱稱/備註/頭像、搜尋加好友、原生分享單(用複製連結)、分帳與群組(sub-project 5/6)。

## Capabilities

### New Capabilities

- `friends-ui`:好友列表與解除、邀請連結產生與撤銷、邀請接受流程(含未登入先登入再重播 deep link)。

### Modified Capabilities

- `settings`:設定頁新增「好友」入口列(既有主題/語言/登出四節不變)。

## Impact

- 新增 `lib/contexts/social/**`、`test/contexts/social/**`。
- 修改 `lib/app.dart`(兩條 route)、`lib/main.dart`(DI)、`lib/contexts/settings/presentation/settings_screen.dart`(`_NavRow` + 一列)、`lib/l10n/app_{en,zh_Hant,zh}.arb`。
- 修改 `test/app_test.dart` 的 `pumpApp`(另被 `test/app_pending_deep_link_test.dart` 引用):補上帶預設 fake 的 social 依賴,影響 2 個測試檔。
- **不修改** `resolveAuthRedirect`:它既有的 pendingDeepLink 捕捉/重播已涵蓋 `/invite?token=…`(含 query),本 change 只加測試釘住這條路徑。
- 後端零改動。
