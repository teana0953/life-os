# Tasks: add-settings

## 1. ThemeController + 接線

- [ ] 1.1 `lib/shared/theme/theme_controller.dart`:`ChangeNotifier`,持 `ThemeMode`(預設 system),`setThemeMode` + 載入/儲存 `shared_preferences`;先寫測試(切換通知、持久化 mock prefs、記住、預設 system)
- [ ] 1.2 `lib/app.dart`:`themeMode: themeController.themeMode`(隨 controller 重建,對稱既有 locale);`lib/main.dart`:建 ThemeController(載入 prefs)注入;測試:themeMode 隨 controller 變

## 2. 設定字串(i18n)

- [ ] 2.1 `lib/l10n/app_en.arb` + `app_zh_Hant.arb`(+ `app_zh.arb` fallback base)新增設定頁字串:設定、主題、系統/亮/暗、語言、登出、home 設定 icon tooltip 等;`flutter gen-l10n` 產出通過型別檢查

## 3. SettingsScreen

- [ ] 3.1 `lib/contexts/settings/presentation/settings_screen.dart`:標題列 + 返回;三分區——主題(系統/亮/暗,顯示當前)、語言(系統/English/繁中,用 LocaleController)、登出(SignOut);走 `AppLocalizations`、不硬編碼顏色、套設計系統(卡片/圓角/亮暗)、responsive
- [ ] 3.2 widget 測試(注入 fake ThemeController/LocaleController/SignOut):三主題選項可選並呼叫 setThemeMode;三語言選項呼叫 LocaleController;登出呼叫 SignOut;當前選擇有標示;en/繁中 字串各驗

## 4. home 導覽 + 搬移

- [ ] 4.1 `home_screen.dart`:**loaded 正常狀態** header 加設定 icon(齒輪)→ `Navigator.push` SettingsScreen;僅移除 **loaded 狀態**的語言 chip 與標準登出(改在設定頁)。⚠️ **error 狀態的登出按鈕、needsReauth 的「重新登入」按鈕保留不動**(復原出口,對應 login-flow spec);login 語言 chip 保留。DI:`App`→`_AuthenticatedHome`→`HomeScreen`→SettingsScreen 傳入 ThemeController/LocaleController/SignOut
- [ ] 4.2 導覽/遷移測試:點 home(loaded)設定 icon → 進 SettingsScreen;既有 home 測試中「loaded 狀態語言 chip / 標準登出在 home」的斷言改為「在設定頁」;**error/needsReauth 的登出/重新登入測試維持綠不改**;更新 `pumpApp`/`pumpHomeScreen` harness 的新建構子參數

## 5. 收尾

- [ ] 5.1 repo `CLAUDE.md` 補「設定 / 主題」節(ThemeController 位置與慣例、設定頁如何加新項、themeMode 接法);`flutter analyze` 無 issue、`flutter test` 全綠、web build 成功
