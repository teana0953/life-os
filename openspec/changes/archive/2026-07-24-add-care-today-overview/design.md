## Context

今日照護 checklist(`CareTodayScreen` + `CareTodayController`)已上線(#77),但唯一入口
藏在健康模組更多分頁。本次把它的行動摘要搬到總覽(預設分頁),並修正推播點擊落點。
完整設計理由見 `docs/superpowers/specs/2026-07-24-care-today-on-overview-design.md`。

## Decisions

- **薄殼摘要卡,不新增業務邏輯**:`CareTodaySummaryCard` 只消費既有 `CareTodayController`
  的 `focusSlot`/`groups`/`markingAction`/`markDone`/`markSkipped`/`markError`。緊急度分支
  (逾期/待辦/全完成/無排程/載入中)全由既有衍生狀態決定。無排程與非 loaded 狀態回傳
  「不顯示」,避免版面跳動並對沒設定照護的人零雜訊。
- **卡片收 `idToken`**:`markDone`/`markSkipped` 需 `idToken`(定位參數)+ 由 slot 取
  `careScheduleId`/`localDate`/`timeOfDay`。總覽已有 `idToken`(`health_scaffold.dart:220`
  傳入 `_OverviewBody`),沿此串入卡片建構子。
- **就地動作走控制器安靜重載**:總覽點「完成」不觸發全頁 loading(控制器 `marking` 機制),
  卡片經 `notifyListeners` 自更新;不重載總覽其他 controller。失敗時控制器保留原 slots 並設
  `markError`,卡片以 SnackBar(沿用 checklist 的失敗 + 重試文案)提示,不靜默。
- **載入接進既有並行**:`HealthScaffold._load()` 的 `Future.wait` 加一筆
  `careTodayController.load(token)`,並把它加入 `_overviewControllers` 監聽鏈。
- **推播深連結預設 `/#/care-today`**:App 未用 `usePathUrlStrategy()`,web 走 go_router
  預設 hash 策略,路由在 `/#/...`,故深連結須用 hash 形式(裸 `/care-today` 無 fragment 會
  落回首頁)。`web/push_sw.js` 讀 `notification.data.url`,後端未帶時退化為 `/#/care-today`。
  向後相容、暫不動後端;跳到特定 slot 需 payload 帶 slot id,後續。

## Out of scope

不動 `CareTodayScreen`/`CareTodayController` 邏輯、不動後端、不動底部導覽、不移除更多分頁
既有入口。提醒設定 + 照護提醒管理的合併是另一支 change。
