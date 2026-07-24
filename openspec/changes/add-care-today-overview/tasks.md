## 1. i18n

- [ ] 1.1 在 `app_en.arb` / `app_zh_Hant.arb` / `app_zh.arb` 新增總覽摘要卡文案(進度
      `{done}/{total}`、「接下來」、「還有 {n} 項」、「全部」、逾期標籤等),每鍵附
      `description`;`flutter gen-l10n` 重新產生 `lib/l10n/generated/*` 並提交。

## 2. 總覽摘要卡

- [ ] 2.1 (red) 寫 `CareTodaySummaryCard` widget test:注入 fake `CareTodayController`,
      覆蓋逾期/只有待辦/全部完成/無排程/載入中五種狀態的對應呈現;點就地「完成」→ 觸發
      `markDone`;點卡主體 → 觸發 push `/care-today`。
- [ ] 2.2 (green) 實作 `lib/contexts/notifications/presentation/care_today_summary_card.dart`
      ——薄殼,只消費 `focusSlot`/`groups`/`markingAction`/`markDone`/`markSkipped`,顏色/
      形狀全走 theme;無排程與載入中/error/reauth 回傳空(不顯示)。
- [ ] 2.3 (refactor) 抽出共用的 slot 呈現片段(時間/劑量列),與 `CareTodayScreen` 視覺一致。

## 3. 接進總覽

- [ ] 3.1 (red) 補 `HealthScaffold` widget test:有排程 → 總覽第一張是 care 摘要卡;無排程
      → 第一張是 GoalCard。
- [ ] 3.2 (green) `HealthScaffold` 建構子加 `careTodayController`;`_load()` 的 `Future.wait`
      加 `careTodayController.load(token)`;加入 `_overviewControllers`;`_OverviewBody` 收
      controller 並在 `ListView` 最上方放 `CareTodaySummaryCard`。
- [ ] 3.3 (green) `app.dart` 把 `widget.careTodayController` 傳入 `HealthScaffold`。

## 4. 推播深連結

- [ ] 4.1 `web/push_sw.js`:`push` handler 的 `showNotification` 帶
      `data: { url: data.url || '/care-today' }`;`notificationclick` 改開
      `event.notification.data?.url || '/care-today'` 取代寫死的 `/`。

## 5. Gate

- [ ] 5.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。
