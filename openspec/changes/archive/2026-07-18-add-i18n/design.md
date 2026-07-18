# add-i18n — 多國語系(English + 繁體中文)

## 目標

把 `life-os`(Flutter web)的 UI 字串國際化:支援 **English + 繁體中文(zh-Hant)**,
**跟隨系統語言 + 程式內可手動切換(記住選擇)**,fallback/預設 **English**。

## 方案

用 Flutter 官方 `gen_l10n`(標準做法,非第三方套件):
- 依賴:`flutter_localizations`(SDK)、`intl`;`pubspec.yaml` 的 flutter 段開 `generate: true`。
- `l10n.yaml` 設定;ARB 檔:`lib/l10n/app_en.arb`(template,含所有 key + 英文)、`lib/l10n/app_zh_Hant.arb`(繁中翻譯)。
- 產生的 `AppLocalizations` 由 build/test 自動生成(不進 git)。

## 語言選擇 + 切換

- `LocaleController`(`ChangeNotifier`,放 `lib/shared/i18n/`):持有選定 locale(`null` = 跟隨系統);切換時通知 + **持久化**。
- 持久化用 `shared_preferences`(記住使用者選的語言,重開仍在)。
- `MaterialApp`:`localizationsDelegates`(AppLocalizations + 三個 global delegates)、`supportedLocales: [en, zh-Hant]`、`locale: controller.locale`(null 時交給系統)、`localeResolutionCallback` fallback 到 `en`。
- **切換入口**:登入頁與 home 各放一個輕量語言切換(icon/選單,en ⇄ 繁中);選擇存 controller + prefs。

## 字串範圍(全部抽到 ARB)

- **登入**:Welcome back、Sign in to…、Email、Password、Sign in、Signing in…、Trouble signing in / Get help、錯誤訊息。
- **Home**:問候(時段:早/午/晚——用 intl 依 locale)、Your spaces、模組名示意(Health/Finance/…)、Signed in、Sign out、profile 相關、載入失敗/需重新登入 錯誤態。
- **錯誤文案(重要重構,對齊 Clean Arch)**:目前 `friendlyAuthErrorMessage`(infra)與 `ProfileFetchFailure` 的英文 copy 寫在 infra/domain 層。i18n 後 **UI copy 不該住在 infra**——改成:infra/application 丟**型別化/帶 code 的錯誤**(如 `ReauthenticationRequired`、`ProfileFetchFailure`、auth 錯誤帶 enum code),**presentation 層依型別/code 對應 `AppLocalizations` 字串**。這讓 domain/infra 保持無 UI 文案。

## 架構(遵循 CLAUDE.md)

- i18n 基礎件放 `lib/shared/i18n/`(LocaleController)+ `lib/l10n/`(ARB)——跨 context 技術件。
- presentation 用 `AppLocalizations.of(context)!` 取字串,**不寫死英文**;錯誤型別 → 在 presentation 對應本地化訊息。
- 不動 auth/api 業務邏輯(只把 copy 從 infra 移到 presentation 的 i18n)。

## 測試策略(gate)

- **既有 widget 測試遷移**:目前多以 `find.text('Welcome back')` 等英文字串定位。改為:pump 時包 `AppLocalizations` delegates + 固定測試 locale(en),用該 locale 的本地化字串斷言(或改用 key 定位);保留行為斷言。
- **新增 i18n 測試**:
  - 切到 zh-Hant → 畫面出現繁中字串;切回 en → 英文。
  - 不支援的 locale → fallback en。
  - LocaleController 切換 + 持久化(mock prefs)記住選擇。
  - 錯誤型別 → 對應本地化訊息(en/繁中各驗一個)。
- gate:`flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`(gen-l10n 由 test/build 自動觸發)。

## 範圍

### 包含
i18n 基礎(gen_l10n、ARB en/繁中、delegates、supportedLocales)、LocaleController + 持久化、登入/home 切換入口、抽出現有字串、錯誤 copy 重構到 presentation、既有測試遷移 + 新 i18n 測試、CLAUDE.md 補 i18n 慣例。

### 不包含
未來模組(不存在)的翻譯、RTL(en/繁中皆 LTR)、複雜 ICU 複數規則(除時段問候外從簡)、日文/簡中(之後加 locale 即可,架構已支援)。

## 實作注意(proposal review 收斂)

- **Controller 錯誤 API 改型別化**:controller(ChangeNotifier)沒有 BuildContext、拿不到 AppLocalizations,所以**不能持有已本地化的 String**。改成 controller 持有**錯誤種類**(enum,如 `LoginError { invalidCredentials, network, unknown }`、home 的 `ProfileError { fetchFailed, reauthRequired }`),**由 screen 在 build 時**用 `AppLocalizations` 把 enum 映射成本地化文字。`friendlyAuthErrorMessage`(infra,回英文字串)重構成回傳/丟出**帶 code 的 `AuthFailure`**,presentation 對 code 做本地化。
- **測試遷移範圍(明列)**:
  - `firebase_auth_error_messages_test.dart`:目前斷言英文回傳,重構成 code/enum 後改斷言 code 對應(或移除、改在 presentation 驗本地化)。
  - `http_profile_repository_test.dart`:斷言 `ProfileFetchFailure` **訊息不外洩內部細節**——這是**真實安全性質**,重構後(即使訊息改由 presentation 本地化)infra 端**仍不得帶原始例外文字**,此測試等價保留。
  - login/app/home 測試中以字串建構 `AuthFailure`/`ProfileFetchFailure` 的 fake:改成用新的型別/code 建構。
  - `find.text('英文')` 的 widget 測試:pump 時包 `AppLocalizations.localizationsDelegates` + 固定 `locale: Locale('en')`,用 `AppLocalizations` 的字串斷言(或改 key 定位)。
- **gen_l10n 產出模式**:用 `synthetic-package: false`(synthetic 模式已棄用)——產出的 `AppLocalizations` 進 source(指定 `output-dir`,**進 git**、import 路徑為該 source),非 synthetic import。design 前述「不進 git」據此修正。
- **zh-Hant locale 寫法**:`supportedLocales` 與比對用 `Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')`,**不要** `Locale('zh','Hant')`('Hant' 會被當 countryCode 導致永遠 fallback en)。ARB 檔名 `app_zh_Hant.arb` 正確。
- **時段問候**:引入 `DateTime.now()` 會使 home 測試時間相依而 flaky。做法:把「時鐘」設計成可注入(或問候文字改非時段相依),測試固定時間或只驗語言。

## 驗收標準
1. `flutter analyze` 無 issue、`flutter test` 全綠(含遷移 + 新 i18n 測試)、web build 成功。
2. 系統為繁中 → app 顯示繁中;為其他 → 英文;程式內切換即時生效並重開後記住。
3. 登入/home 無寫死英文字串(錯誤訊息也本地化)。
