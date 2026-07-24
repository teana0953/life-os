## 1. i18n

- [x] 1.1 在 `app_en.arb` / `app_zh_Hant.arb` / `app_zh.arb` 新增總覽摘要卡文案(進度
      `{done}/{total}`、「接下來」、「還有 {n} 項」、「全部」、逾期標籤等),每鍵附
      `description`;`flutter gen-l10n` 重新產生 `lib/l10n/generated/*` 並提交。

## 2. 總覽摘要卡

- [x] 2.1 (red) 寫 `CareTodaySummaryCard` widget test:注入 fake `CareTodayController`,
      覆蓋逾期/只有待辦/全部完成/無排程/載入中五種狀態的對應呈現;點就地「完成」→ 觸發
      `markDone`(帶 idToken + slot ids);點卡主體 → 觸發 push `/care-today`;就地標記失敗
      (`markError`)→ 顯示 SnackBar、summary 不變。
- [x] 2.2 (green) 實作 `lib/contexts/notifications/presentation/care_today_summary_card.dart`
      ——薄殼,建構子收 `idToken`,只消費 `focusSlot`/`groups`/`markingAction`/`markError`/
      `markDone`/`markSkipped`,顏色/形狀全走 theme;無排程與載入中/error/reauth 回傳空
      (不顯示);`markError`(非 auth)→ SnackBar 沿用 checklist 失敗+重試文案。
- [x] 2.3 (refactor) 抽出共用的 slot 呈現片段(時間/劑量列),與 `CareTodayScreen` 視覺一致。
      `CareTodayScreen` 的呈現片段是私有(`_`)類別,不對外匯出,且本次明確不動
      `CareTodayScreen` 檔案——改為在 `care_today_summary_card.dart` 內鏡射同樣的文字/顏色
      組法(`"$timeOfDay · $label"`、逾期用 `colorScheme.error`、劑量列、Done/Skip
      `OverflowBar`、`_ButtonSpinner`),讓兩者視覺一致而不共享私有實作。

## 3. 接進總覽

- [x] 3.1 (red) 補 `HealthScaffold` widget test:有排程 → 總覽第一張是 care 摘要卡;無排程
      → 第一張是 GoalCard。
- [x] 3.2 (green) `HealthScaffold` 建構子加 `careTodayController`;`_load()` 的 `Future.wait`
      加 `careTodayController.load(token)`;加入 `_overviewControllers`;`_OverviewBody` 收
      controller 並在 `ListView` 最上方放 `CareTodaySummaryCard`。
- [x] 3.3 (green) `app.dart` 把 `widget.careTodayController` 傳入 `HealthScaffold`。

## 4. 推播深連結

- [x] 4.1 `web/push_sw.js`:`push` handler 的 `showNotification` 帶
      `data: { url: data.url || '/#/care-today' }`;`notificationclick` 改開
      `event.notification.data?.url || '/#/care-today'` 取代寫死的 `/`(hash 形式,因 App
      走 go_router 預設 hash 策略)。

## 5. Gate

- [x] 5.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。
