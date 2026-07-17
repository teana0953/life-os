# Tasks: add-i18n

## 1. i18n 基礎

- [ ] 1.1 依賴:`pubspec.yaml` 加 `flutter_localizations`(sdk)、`intl`、`shared_preferences`;flutter 段開 `generate: true`;新增 `l10n.yaml`(template `app_en.arb`、output `AppLocalizations`)
- [ ] 1.2 `lib/l10n/app_en.arb`(所有 key + 英文,含描述/placeholder;含問候時段、登入/home/錯誤字串)+ `lib/l10n/app_zh_Hant.arb`(繁中翻譯);`flutter gen-l10n`/build 能產出 `AppLocalizations`,型別檢查通過

## 2. LocaleController + 持久化

- [ ] 2.1 `lib/shared/i18n/locale_controller.dart`:`ChangeNotifier`,持有 `Locale?`(null=跟隨系統),`setLocale`/`clear`、載入/儲存到 `shared_preferences`;先寫測試(切換通知、持久化 mock prefs、記住選擇)

## 3. App 接線

- [ ] 3.1 `lib/app.dart`:`localizationsDelegates`(AppLocalizations + global delegates)、`supportedLocales: [en, zh-Hant]`、`locale: controller.locale`、`localeResolutionCallback` fallback en;隨 controller 重建。`lib/main.dart`:建 LocaleController(載入 prefs)注入
- [ ] 3.2 測試:不支援 locale → fallback en;繁中 locale → 繁中字串;切換即時生效(pump 後字串變)

## 4. 字串抽出 + 錯誤重構

- [ ] 4.1 登入畫面:所有字串改 `AppLocalizations.of(context)!.*`;auth 錯誤改由**型別/code**(重構 `friendlyAuthErrorMessage` 成回傳 code/enum 或型別化 `AuthFailure`),presentation 對應本地化訊息;既有 login 測試遷移(固定測試 locale + 本地化字串或 key 定位)保留行為斷言
- [ ] 4.2 home 畫面:所有字串改本地化(含時段問候用 intl 依 locale);`ProfileFetchFailure`/`ReauthenticationRequired` 的 UI copy 移出 infra,presentation 依型別對應本地化訊息;既有 home/app 測試遷移

## 5. i18n 測試 + 收尾

- [ ] 5.1 i18n 行為測試:en/繁中 各驗登入+home 關鍵字串;錯誤型別 → en/繁中 本地化訊息各驗一;語言切換入口(登入/home)點選後語言變並經 controller
- [ ] 5.2 repo `CLAUDE.md` 補「i18n」節(gen_l10n、ARB 位置、加新語言步驟、錯誤 copy 走 presentation 的慣例、不得寫死字串);`flutter analyze` 無 issue、`flutter test` 全綠、web build 成功
