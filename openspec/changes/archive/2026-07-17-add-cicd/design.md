# add-cicd(前端)— Flutter GitHub Actions CI/CD

## 目標

為 `life-os`(Flutter web)建立 GitHub Actions pipeline:PR/push 跑 CI(analyze + test + build web),
merge 到 main 後自動 CD(build web → 部署到 Cloudflare Pages)。對齊後端已通的 CI/CD 模式。

## 範圍

### 包含(life-os)

1. **CI workflow**(`.github/workflows/ci.yml`):
   - 觸發:`pull_request` + 非 main 分支 `push`;`concurrency` 防重複;`permissions: contents: read`。
   - job:checkout → `subosito/flutter-action`(pin Flutter 3.35.x)→ `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build web`(catch build 破壞)。
2. **CD workflow**(`.github/workflows/deploy.yml`):
   - 觸發:`push` 到 `main`;`concurrency` 序列化。
   - job:checkout → flutter-action → `flutter build web --dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}` → `cloudflare/wrangler-action` 跑 `pages deploy build/web --project-name=<pages>`(account 由 token 推斷,如後端拿掉 accountId)。
3. **README**:CI/CD 章節、所需 GitHub secret/variable、Pages 專案設定。

### 前置依賴(life-os-backend,小改動走後端 CD)

- **後端 CORS 加 Pages origin**:目前後端 CORS 只允許 localhost。Flutter web 部署到 Pages 後是新 origin,會被擋。做法:後端 CORS 改為**也允許由 env `ALLOWED_WEB_ORIGIN` 指定的 production origin**(Pages 網址),以 wrangler secret/var 設定。等 Pages 網址確定後設上。我會用一個後端小 change 處理。

### 不包含

Android/iOS 打包上架、Pages 自訂網域、預覽部署(preview per-PR)、e2e 瀏覽器測試。

## 所需 GitHub 設定(使用者於 GitHub UI,永不經過對話)

| 名稱 | 類型 | 用途 |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | secret | Pages 部署認證(含 Pages:Edit;account 由 token 推斷) |
| `API_BASE_URL` | variable | build web 時注入的後端網址(`https://life-os-backend.playground-92f.workers.dev`) |

> Cloudflare Pages 專案需先建立(dashboard 或首次 `wrangler pages deploy` 建),`--project-name` 對上。
> `CLOUDFLARE_API_TOKEN` 需**限定單一帳號**(不傳 accountId 靠 token 推斷帳號;token 若能看到多帳號,非互動模式會報「More than one account」)。

## 部署後登入的兩個前置(Pages 網址確定後,你來設)

Flutter web 部署到 Pages 後,登入要能通需要**兩處**都放行該 origin:
1. **後端 CORS**:設 `ALLOWED_WEB_ORIGIN` = Pages 網址(前置後端 change 已讓它可配置)。
2. **Firebase Authorized domains**:Firebase Console → Authentication → Settings → Authorized domains 加入 Pages 網域,否則 Firebase 登入會被擋。

(deploy 本身不受這兩者影響;只影響部署後的「登入」。)

## 架構決策

- **CI 也跑 `flutter build web`**:widget/unit 測試過不代表 web 能 build(composition/平台問題),build 一次當守門。
- **CD 用 wrangler-action `pages deploy`**:與後端同工具鏈;account 由 token 推斷(不傳 accountId,沿用後端教訓避免 10000)。
- **`API_BASE_URL` 用 GitHub variable(非 secret)**:後端網址非機密,build 時注入。
- **backend CORS 用 env 設 production origin**:GitHub 為前端設定來源,後端 origin 白名單可配置,避免硬編碼。

## 錯誤處理 / 邊界

- 缺 `CLOUDFLARE_API_TOKEN` → CD 在 deploy step 明確失敗。
- Pages 專案不存在 → deploy 失敗並提示需先建。
- 首次部署後才知 Pages 網址 → 之後設後端 `ALLOWED_WEB_ORIGIN` + 前端 `API_BASE_URL`(已知後端網址,前端這個可先設)。

## 測試 / 驗收

- **gate(本 change)**:`flutter analyze` + `flutter test`(維持全綠);workflow YAML 以 `actionlint` 檢查。
- **QA / 端到端(需使用者先設 GitHub secret + 建 Pages 專案)**:推測試分支 → CI 綠(analyze+test+build);merge → CD 綠(build + pages deploy);開 Pages 網址 → 應載入 app(登入需 Firebase 設定 + 後端 CORS 放行該 origin)。
- **驗收標準**:CI 在 PR 自動跑且擋紅;push main 後自動部署到 Cloudflare Pages。
