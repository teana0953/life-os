# add-settings — 設定頁 + 主題切換

## 目標

新增一個**設定頁**,集中管理:**主題(系統/亮/暗)**、**語言(系統/English/繁體中文)**、**登出**。
主題目前寫死 `ThemeMode.system`,改成可由使用者選並記住。語言切換從 home 的 chip 移進設定頁(整合)。

建在 i18n 之上(已 merge 進 main):沿用 LocaleController 模式與本地化。

## 主要元件

### ThemeController(新,對稱 LocaleController)
- `lib/shared/theme/theme_controller.dart`:`ChangeNotifier`,持有 `ThemeMode`(system/light/dark,預設 system),`setThemeMode`、載入/儲存到 `shared_preferences`。
- `lib/app.dart`:`themeMode: themeController.themeMode`(隨 controller 重建,與現有 locale 一樣包 AnimatedBuilder);`main.dart` 建 ThemeController(載入 prefs)注入。

### SettingsScreen(新)
- `lib/contexts/settings/presentation/settings_screen.dart`(context-first;presentation only,orchestrate 既有 shared 控制器 + auth 登出)。
- 內容分區(本地化):
  - **主題**:系統 / 亮 / 暗(三選一,radio/segmented,顯示當前選擇)。
  - **語言**:系統 / English / 繁體中文(沿用 LocaleController;呈現與主題一致)。
  - **登出**:呼叫 SignOut。
- 有標題列 + 返回;套用設計系統(Chiikawa 可愛風、卡片/圓角、亮暗)。

### 導覽 / 入口調整
- **home**:header 加一個**設定 icon**(齒輪)→ `Navigator.push` 到 SettingsScreen;home 原本的語言 chip 與登出移進設定頁(home 保持乾淨)。
- **login**:**保留**語言 chip(登入前選語言;設定頁是登入後才進得去)。

## 本地化
新增 ARB key(en + 繁中):設定、主題、系統、亮、暗、語言、登出 等標題/選項字串;home 的設定 icon tooltip。

## 架構(遵循 CLAUDE.md)
- ThemeController 放 `lib/shared/theme/`(跨 context 技術件,對稱 i18n 的 LocaleController)。
- SettingsScreen 為 presentation,注入 ThemeController/LocaleController + SignOut use case;不硬編碼顏色/字串。
- 主題/語言選擇即時生效(controller notify → MaterialApp 重建)。

## 測試策略(gate)
- **ThemeController 測試**:setThemeMode 通知、持久化(mock prefs)、記住選擇、預設 system。
- **App 接線測試**:themeMode 隨 controller 變(pump 後 MaterialApp.themeMode 反映)。
- **SettingsScreen widget 測試**(注入 fake controllers/SignOut):三個主題選項可選並呼叫 ThemeController;三個語言選項呼叫 LocaleController;登出呼叫 SignOut;當前選擇有標示;字串走 AppLocalizations(en/繁中 各驗)。
- **home 導覽測試**:點設定 icon → 進 SettingsScreen(pump route);home 不再直接有語言 chip/登出(改在設定頁)。
- **既有測試遷移**:home 測試中對「語言 chip / 登出按鈕在 home」的斷言,改為「在設定頁」;app/home 相關保留行為。
- gate:`flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`。

## 範圍
### 包含
ThemeController + 持久化、SettingsScreen(主題/語言/登出)、home 設定入口 + 導覽、語言 chip 從 home 移入設定、新 ARB 字串、測試(新增 + 遷移)、CLAUDE.md 補設定/主題慣例。
### 不包含
其他設定項(帳號、通知…未來模組)、login 的設定頁(login 只留語言 chip)、主題自訂色(只切 system/light/dark)。

## 驗收標準
1. `flutter analyze` 無 issue、`flutter test` 全綠、web build 成功。
2. home 有設定入口 → 進設定頁;可切主題(系統/亮/暗)即時生效並重開記住;可切語言;可登出。
3. 設定頁本地化(en/繁中)、套用可愛風設計、亮暗正常、responsive 無溢出。
