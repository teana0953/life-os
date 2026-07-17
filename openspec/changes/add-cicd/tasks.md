# Tasks: add-cicd (frontend)

## 1. Gate 工具

- [x] 1.1 加入 `actionlint` 到 gate:`scripts/lint-actions.sh`(下載官方 binary 到 gitignored 目錄跑,同後端做法)+ `Makefile`/README 記錄;確認本地可跑並抓得到壞 workflow(red→green 驗一次)

## 2. CI workflow

- [x] 2.1 `.github/workflows/ci.yml`:觸發 `pull_request` + 非 main `push`;`concurrency`(group 依 ref、cancel-in-progress)、`permissions: contents: read`;job = checkout → `subosito/flutter-action`(Flutter 3.35.x)→ `flutter pub get` → `flutter analyze` → `flutter test` → `flutter build web`(對應 ci-cd「Continuous integration」)

## 3. CD workflow

- [x] 3.1 `.github/workflows/deploy.yml`:觸發 `push` 到 `main`;`concurrency` 序列化 `deploy-main`;`permissions: contents: read`;checkout → flutter-action → `flutter pub get`
- [x] 3.2 build 步驟:`flutter build web --dart-define=API_BASE_URL=${{ vars.API_BASE_URL }}`;build 失敗即中止後續(對應「Build failure aborts deploy」)
- [x] 3.3 deploy 步驟:`cloudflare/wrangler-action`,`apiToken` 取自 secret(**不傳 accountId**,account 由 token 推斷),command `pages deploy build/web --project-name=<pages 專案名>`(對應「Deploy to Pages」「Account inferred from token」)

## 4. 文件

- [x] 4.1 README 補 CI/CD 章節:pipeline 行為、所需 `CLOUDFLARE_API_TOKEN` secret(Pages:Edit、**限單一帳號**)+ `API_BASE_URL` variable、Cloudflare Pages 專案需先建;**部署後登入的兩個前置**:設後端 `ALLOWED_WEB_ORIGIN`(CORS)+ Firebase Authorized domains 加 Pages 網域

## 5. 靜態驗證

- [x] 5.1 對兩個 workflow 跑 `actionlint` 通過;確認 `flutter analyze`、`flutter test` 維持全綠(gate 全綠)
