## 1. i18n

- [ ] 1.1 新增文案(en + zh-Hant + zh,各附 description)並 `flutter gen-l10n` 重產提交:
      卡片「管理」入口、空狀態設定 CTA(「還沒有照護提醒 · 設定」)、通知未開 banner
      (「通知未開啟,提醒不會送達」+「開啟通知」)。

## 2. pushOn getter

- [ ] 2.1 (red) `ReminderSettingsController` 單元測試:`pushOn` = true(status==enabled)/
      true(permission==granted 但 status!=enabled)/ false(idle+permission!=granted)。
- [ ] 2.2 (green) 加唯讀 getter `bool get pushOn => status == ReminderSettingsStatus.enabled ||
      _gateway.permissionStatus() == PushPermissionStatus.granted;`(不改 enable/test 邏輯)。

## 3. 總覽卡兩個入口

- [ ] 3.1 (red) `CareTodaySummaryCard` 測試:改「無排程→不顯示」為「無排程(loaded,slots 空)
      → 顯示 slim 設定 CTA,點觸發 onSetup」;新增「有排程→標題列管理入口,點觸發 onManage」;
      維持 loading/error/reauth → 不顯示。
- [ ] 3.2 (green) 卡片加 `onManage`/`onSetup` callback;no-schedule 分支改渲染 slim CTA;
      標題列加「管理」入口。
- [ ] 3.3 (green) `HealthScaffold._OverviewBody` 傳 `onManage`/`onSetup` =
      `context.push('/care-items')`;更新 `HealthScaffold` 測試(無排程→總覽首張為 care CTA)。

## 4. care-items 通知未開 banner

- [ ] 4.1 (red) `CareItemsScreen` 測試:注入 fake `ReminderSettingsController`,pushOn=false →
      banner 顯示、點觸發 push `/reminders`;pushOn=true → 無 banner;既有清單/CRUD 測試不破。
- [ ] 4.2 (green) `CareItemsScreen` 加 `reminderSettingsController` 參數,`initState` 呼叫
      `load()` + 監聽;清單頂部(mutation error 之下)`!pushOn` 時渲染 banner → `/reminders`。
- [ ] 4.3 (green) `app.dart` 的 `/care-items` route builder 注入既有 `reminderSettingsController`。

## 5. Gate

- [ ] 5.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。
