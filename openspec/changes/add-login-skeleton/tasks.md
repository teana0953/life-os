# Tasks: add-login-skeleton

## 1. 專案骨架

- [ ] 1.1 `flutter create`(web + mobile 平台)於 `life-os`;`pubspec.yaml` 加 `firebase_core`、`firebase_auth`、`http`;確認 `flutter pub get`、`flutter analyze` 乾淨
- [ ] 1.2 建立 context-first 結構(`lib/contexts/auth/{domain,application,infrastructure,presentation}`、`lib/contexts/user/{...}`、`lib/shared/`);`shared/config.dart` 以 `--dart-define=API_BASE_URL` 讀取(預設線上 workers.dev)
- [ ] 1.3 commit 可編譯的 placeholder `lib/firebase_options.dart`(佔位值,不 gitignore),讓 analyze/test 通過;**移除 `flutter create` 預設的 `test/widget_test.dart`**(它 import main.dart 會編譯失敗)
- [ ] 1.4 `life-os/CLAUDE.md`:架構慣例(Clean Arch + DDD、hexagonal 命名、context-first、依賴朝內、新 context 樣板、port 在 domain / driven adapter = 技術前綴+port 名),對齊後端

## 2. user context — domain/application(TDD,純 Dart 單元測試)

- [ ] 2.1 `UserProfile` entity(`id`、`firebase_uid`、`email` nullable、`display_name` nullable、`created_at`)+ `fromJson` 對齊後端形狀;先寫測試
- [ ] 2.2 `ProfileRepository` port(`getProfile(idToken) → UserProfile`)+ `GetProfile` use case;注入 fake repository 測試

## 3. auth context — domain/application(TDD)

- [ ] 3.1 `AuthRepository` port(`signIn(email,pw)`、`signOut()`、`idToken()`、`authStateChanges`)+ `SignIn`/`SignOut` use case;注入 fake repository 測試(成功、帳密錯→可辨識錯誤)

## 4. Infrastructure(driven adapters)

- [ ] 4.1 `HttpProfileRepository` 實作 `ProfileRepository`:打 `GET {baseUrl}/api/me` 帶 `Authorization: Bearer`;200 解析 UserProfile、**401 拋「需重新登入」錯誤**、其他非 200 拋一般錯誤(unit 測試注入 mock http client)
- [ ] 4.2 `FirebaseAuthRepository` 實作 `AuthRepository`(包 firebase_auth;錯誤轉友善訊息、不洩內部)

## 5. Presentation(TDD widget 測試,注入 fake)

- [ ] 5.1 `LoginScreen` + `LoginController`:email/密碼欄 + 登入鈕 + 錯誤訊息;widget 測試——正確帳密 → SignIn → 進 home;帳密錯 → 顯示錯誤、停在登入頁(對應 spec「Email/password sign-in」)
- [ ] 5.2 `HomeScreen` + `HomeController`:顯示 profile(email/id)+ 登出鈕;widget 測試——顯示注入的 profile;`/api/me` 失敗 → 錯誤狀態 + 可登出;401 → 重新登入出口(對應 spec「Profile 顯示/失敗」)
- [ ] 5.3 `app.dart` auth-state 路由:依 `authStateChanges` — 未登入 → LoginScreen、已登入 → GetProfile → HomeScreen;widget 測試涵蓋兩起始狀態與登出回登入頁(對應 spec「Sign-out」「Auth-state routing」)

## 6. 組裝與收尾

- [ ] 6.1 `main.dart` composition root:`Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`、手動注入 adapters→use case→controller、runApp
- [ ] 6.2 `flutter analyze` 無 issue、`flutter test` 全綠(gate)
- [ ] 6.3 README:專案簡介、使用者前置(flutterfire configure、啟用 Email/Password、建測試用戶)、`flutter run -d chrome --dart-define=API_BASE_URL=...` 跑法
