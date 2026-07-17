# add-login-skeleton — Flutter 登入頁接骨架

## 目標

在 `life-os`(Flutter)建立最小登入流程,end-to-end 打通:
**Email/密碼 Firebase 登入 → 取得 ID token → 打後端 `GET /api/me` → 顯示 user profile**。
完成後即補上後端骨架遞延的「有效 token → user JSON」端到端驗證。

目標平台:**Flutter Web(Chrome)先行**;程式碼保持跨平台(之後可加 Android/iOS)。

## 範圍

### 包含(life-os)

1. **Flutter 專案骨架**:`flutter create`(web + 保留 mobile),`firebase_core` + `firebase_auth` + `http` 依賴;`life-os` 根目錄 `CLAUDE.md` 寫入架構慣例(對齊後端)。
2. **auth context**:`AuthRepository` port(`signIn`/`signOut`/`idToken`/`authStateChanges`)+ `FirebaseAuthRepository` driven adapter + `SignIn`/`SignOut` use case + fake(測試)。
3. **user context**:`ProfileRepository` port(`getProfile(idToken) → UserProfile`)+ `HttpProfileRepository` driven adapter(打 `GET {baseUrl}/api/me` 帶 `Authorization: Bearer`)+ `GetProfile` use case + `UserProfile` entity(對齊後端形狀)+ fake。baseUrl 由 `--dart-define=API_BASE_URL` 注入(預設線上 workers.dev)。
4. **presentation**:`LoginScreen` + `LoginController`(email/密碼 + 錯誤)、`HomeScreen` + `HomeController`(profile:email/id + 登出)。
5. **App 路由**(`app.dart`):依 `AuthRepository.authStateChanges` — 未登入 → LoginScreen;已登入 → GetProfile → HomeScreen。
6. **composition root**(`main.dart`):Firebase init + 手動注入 adapters 到 use case、use case 到 controller。

### 前置依賴(life-os-backend,另一小改動走後端 CI/CD)

- **CORS middleware**:後端加 `hono/cors`,允許 Flutter web 來源(dev 的 `localhost`/`127.0.0.1` + 未來 Pages 網域),放行 `Authorization` header 與預檢。**Web 不加 CORS 會被瀏覽器擋**。這是本 loop 的前置,我會在 `life-os-backend` 以小 change 先做掉(走它已通的 CD)。

### 不包含

註冊新帳號、Google/Apple 登入、密碼重設、token 自動刷新/persist 細節、狀態管理框架(用內建 `ChangeNotifier`/`StreamBuilder`,YAGNI)、Android/iOS 打包上架、Cloudflare Pages 部署(之後另起)。

## Firebase 設定檔策略(解 analyze/test 編譯依賴)

`main.dart` 會 import `lib/firebase_options.dart`;若該檔缺席,`flutter analyze` 與
`flutter test` 會編譯失敗、gate 過不了。因此:

- **`lib/firebase_options.dart` check in(不 gitignore)**。Firebase **web** config(apiKey、
  appId…)是**公開的 client 識別碼、非機密**(本就嵌在前端),commit 沒有洩漏問題。
- apply 階段先 commit 一份**可編譯的 placeholder**(佔位字串值),讓 analyze/test 通過;
  使用者之後用 `flutterfire configure` 覆蓋成自己專案的真值(仍 commit)。
- 移除 `flutter create` 預設的 `test/widget_test.dart`(它 import `main.dart`/`MyApp`,
  留著會讓 test 編譯失敗)。
- 測試**只注入 fake AuthService/ApiClient**,永不呼叫 `Firebase.initializeApp` 或真 http,
  所以 placeholder 值不影響 gate;只有真的 `flutter run` 需要真值。
- `google-services.json` / `GoogleService-Info.plist`(Android/iOS)仍 gitignore(web-first,暫不需要)。

## 使用者前置(你來,像 secrets 一樣不經過我)

1. **Firebase Web app 註冊 + 產 config**:在你的 Firebase 專案註冊一個 Web app,`flutterfire configure` 產生/覆蓋 `lib/firebase_options.dart`(公開值,commit 即可)。
2. **啟用 Email/Password 登入**:Firebase Console → Authentication → Sign-in method → 開啟 Email/Password。
3. **建一個測試用戶**:Firebase Console → Authentication → Users → 新增一個 email/密碼帳號,供 QA 登入測試。

## 架構:Clean Architecture + DDD(hexagonal 命名、context-first,對齊後端)

與 `life-os-backend/CLAUDE.md` 同一套慣例:上層按 bounded context 分,context 內分
`domain`(entity + port)/`application`(use case)/`infrastructure`(driven adapter)/
`presentation`(畫面 + controller)。依賴只朝內;presentation 透過 use case、use case 依賴
domain port;infrastructure 實作 port;`main.dart` 為 composition root 手動 DI。
戰術模式保持輕量(entity + port + 薄 use case;不做 value object/domain event,YAGNI)。

```
lib/
  main.dart                              # composition root:Firebase init + DI + runApp
  app.dart                               # MaterialApp + auth-state 路由
  shared/
    config.dart                          # API_BASE_URL(--dart-define)
  contexts/
    auth/
      domain/
        auth_repository.dart              # port:signIn/signOut/idToken/authStateChanges
      application/
        sign_in.dart                      # use case
        sign_out.dart                     # use case
      infrastructure/
        firebase_auth_repository.dart     # driven adapter(firebase_auth)
      presentation/
        login_controller.dart            # ChangeNotifier,呼叫 use case
        login_screen.dart
    user/
      domain/
        user_profile.dart                 # entity
        profile_repository.dart           # port:getProfile(idToken)
      application/
        get_profile.dart                  # use case
      infrastructure/
        http_profile_repository.dart      # driven adapter(http → /api/me)
      presentation/
        home_controller.dart
        home_screen.dart
test/
  ...(widget/unit 測試,注入 fake repository)
```

命名慣例(同後端):port 放 `domain/`、以能力命名(`AuthRepository`、`ProfileRepository`);
driven adapter = 技術前綴 + port 名(`FirebaseAuthRepository`、`HttpProfileRepository`)。
`UserProfile` 對齊後端 `/api/me` 形狀:`id`、`firebase_uid`、`email`(nullable)、
`display_name`(nullable)、`created_at`。

測試原則:presentation/use case 測試注入 fake repository,不碰真 firebase_auth/http,
永不呼叫 `Firebase.initializeApp`。

## 錯誤處理

- 登入失敗(帳密錯)→ LoginScreen 顯示友善錯誤(不洩內部)。
- `/api/me` 非 200 → HomeScreen 顯示錯誤 + 重試/登出。**401(token 過期/無效)→ 提供「重新登入」出口**(登出回登入頁),而非停在死錯誤。
- 網路例外 → 同上,不 crash。

## 測試策略(gate)

- **widget 測試**(注入 fake AuthService/ApiClient,不碰真 Firebase/網路):
  - 輸入正確帳密 → 呼叫 signIn → 抓到 profile → 顯示 email/id。
  - 帳密錯 → 顯示錯誤訊息、停在 LoginScreen。
  - 已登入 → 顯示 HomeScreen;按登出 → 回 LoginScreen。
- **unit 測試**:ApiClient 解析 `/api/me` JSON → UserProfile;非 200 → 拋可辨識錯誤。
- gate:`flutter analyze` + `flutter test`。

## QA / 端到端驗收(需你先完成上面前置)

- `flutter run -d chrome --dart-define=API_BASE_URL=https://life-os-backend.playground-92f.workers.dev`
- 用測試用戶登入 → 應看到從後端 `/api/me` 回來的 user profile(email/id),且 Neon `users` 表新增/對應該筆 → **補完「有效 token → user JSON」端到端**。
- 帳密錯 → 顯示錯誤、不進入。

## 驗收標準

1. `flutter analyze` 無 issue、`flutter test` 全綠。
2. 後端 CORS 就緒(前置 change 已 merge)。
3. Chrome 實跑:測試用戶登入 → 顯示後端回傳的 profile;登出回登入頁;帳密錯有錯誤訊息。
