## Why

延續 #78:今日照護已上總覽,但**照護提醒管理(`/care-items`,設定吃藥/復健排程)還在更多
分頁太深**,設定入口與總覽的日常行動脫節;#78「無排程→不顯示卡」讓還沒排程的新使用者在
總覽上什麼都看不到,最該淺的「去設定照護」路徑反而最深。此外,使用者可能設了照護提醒卻沒開
推播通知,**提醒永遠不會送達,而管理畫面對此毫無提示**。

使用者定案:提醒設定維持在更多當獨立入口(**不合併**);改為(A)把照護提醒管理從總覽一鍵化 +
補新使用者空狀態入口,(B)照護提醒管理在通知沒開時給提示。

## What Changes

- **A. 總覽兩個入口**(改 #78 的 `CareTodaySummaryCard`):
  - 卡片標題列加「管理」入口 → `context.push('/care-items')`。
  - **無排程時**:不再回傳空(SizedBox.shrink),改顯示 slim「還沒有照護提醒 · 設定 →」CTA →
    `/care-items`。其他非 loaded 狀態(loading/error/reauth)仍不顯示卡(維持 #78)。
  - `HealthScaffold` 已注入 `careTodayController`,無需新增依賴;卡片新增
    `onManage`/`onSetup` callback 由 `_OverviewBody` 給(`context.push('/care-items')`)。
- **B. 照護提醒管理「通知未開」提示**:
  - `ReminderSettingsController` 加唯讀 getter
    `bool get pushOn => status == ReminderSettingsStatus.enabled ||
     _gateway.permissionStatus() == PushPermissionStatus.granted;`
    (讀既有 gateway,不改 enable/test 邏輯——`status` 在上次 session 已訂閱時仍為 idle,
    故須併看 permission。)
  - `CareItemsScreen` 新增 `reminderSettingsController` 參數(**只讀狀態**);`initState`
    呼叫其 `load()`、監聽變化;清單頂部(mutation error 之下)在 `!pushOn` 時顯示 banner
    「通知未開啟,提醒不會送達 · 開啟通知」→ `context.push('/reminders')`。
  - `app.dart` 的 `/care-items` route builder 注入既有 `reminderSettingsController`。
- 新增 i18n(en + zh-Hant + zh):管理入口、空狀態設定 CTA、通知未開 banner;regenerate。

**不動**:提醒設定畫面/`/reminders` route/更多分頁「提醒設定」tile 全保留;後端;推播
enable/test 邏輯;底部導覽;更多分頁「照護提醒」tile(留作 fallback)。
Gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `care-today-ui`: 總覽今日照護摘要卡新增「管理」入口(→ 照護提醒管理);無排程時改顯示
  slim 設定 CTA(而非隱藏),讓還沒排程的使用者也能從總覽一鍵去設定。
- `care-reminders-ui`: 照護提醒管理畫面在推播通知未開啟時,頂部顯示提示(提醒不會送達 ·
  開啟通知 → 提醒設定),避免使用者設了提醒卻收不到。
