# Tasks: add-login-skeleton

## 1. 專案骨架

- [ ] 1.1 `flutter create`(web + mobile 平台)於 `life-os`;`pubspec.yaml` 加 `firebase_core`、`firebase_auth`、`http`;確認 `flutter pub get`、`flutter analyze` 乾淨
- [ ] 1.2 建立目錄結構(`lib/auth`、`lib/api`、`lib/ui`、`test/`);`API_BASE_URL` 以 `--dart-define` 讀取(預設線上 workers.dev)

## 2. Ports 與 model(TDD)

- [ ] 2.1 `AuthService` 抽象(port):`signIn(email,pw)`、`signOut()`、`idToken()`、`authStateChanges`;定義好簽章
- [ ] 2.2 `ApiClient` 抽象(port)+ `UserProfile` model(id、email、displayName);先寫測試
- [ ] 2.3 `HttpApiClient` 實作:打 `GET {baseUrl}/api/me` 帶 `Authorization: Bearer`;200 解析成 UserProfile、非 200 拋可辨識錯誤(unit 測試注入 mock http,對應 spec「Profile 載入/失敗」)

## 3. UI(TDD widget 測試,注入 fake)

- [ ] 3.1 `LoginScreen`:email/密碼欄 + 登入鈕 + 錯誤訊息;widget 測試——正確帳密 → 呼叫 signIn → 進 home;帳密錯 → 顯示錯誤、停在登入頁(對應 spec「Email/password sign-in」)
- [ ] 3.2 `HomeScreen`:顯示 profile(email/id)+ 登出鈕;widget 測試——顯示注入的 profile;`/api/me` 失敗 → 錯誤狀態 + 可登出(對應 spec「Profile 顯示/失敗」)
- [ ] 3.3 auth-state 路由(`app.dart`):依 `authStateChanges` — 未登入 → LoginScreen、已登入 → 抓 profile → HomeScreen;widget 測試涵蓋兩起始狀態與登出回登入頁(對應 spec「Sign-out」「Auth-state routing」)

## 4. Firebase 實作與組裝

- [ ] 4.1 `FirebaseAuthService` 實作 `AuthService`(包 firebase_auth;錯誤轉友善訊息、不洩內部)
- [ ] 4.2 `main.dart` composition root:`Firebase.initializeApp`、注入 FirebaseAuthService + HttpApiClient、runApp;`firebase_options.dart` 缺席時給清楚說明(gitignored,由使用者 flutterfire configure 產生)

## 5. Gate 與收尾

- [ ] 5.1 `flutter analyze` 無 issue、`flutter test` 全綠
- [ ] 5.2 README:專案簡介、使用者前置(flutterfire configure、啟用 Email/Password、建測試用戶)、`flutter run -d chrome --dart-define=API_BASE_URL=...` 跑法
