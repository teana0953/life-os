## Context

今日照護 checklist(`CareTodayScreen` + `CareTodayController`)已上線(#77),但唯一入口
藏在健康模組更多分頁。本次把它的行動摘要搬到總覽(預設分頁),並修正推播點擊落點。
完整設計理由見 `docs/superpowers/specs/2026-07-24-care-today-on-overview-design.md`。

## Decisions

- **薄殼摘要卡,不新增業務邏輯**:`CareTodaySummaryCard` 只消費既有 `CareTodayController`
  的 `focusSlot`/`groups`/`markingAction`/`markDone`/`markSkipped`。緊急度分支(逾期/待辦/
  全完成/無排程/載入中)全由既有衍生狀態決定。無排程與非 loaded 狀態回傳「不顯示」,避免
  版面跳動並對沒設定照護的人零雜訊。
- **就地動作走控制器安靜重載**:總覽點「完成」不觸發全頁 loading(控制器 `marking` 機制),
  卡片經 `notifyListeners` 自更新;不重載總覽其他 controller。
- **載入接進既有並行**:`HealthScaffold._load()` 的 `Future.wait` 加一筆
  `careTodayController.load(token)`,並把它加入 `_overviewControllers` 監聽鏈。
- **推播深連結預設 `/care-today`**:`web/push_sw.js` 讀 `notification.data.url`,後端未帶時
  退化為今日照護 checklist。向後相容、暫不動後端;跳到特定 slot 需 payload 帶 slot id,後續。

## Out of scope

不動 `CareTodayScreen`/`CareTodayController` 邏輯、不動後端、不動底部導覽、不移除更多分頁
既有入口。提醒設定 + 照護提醒管理的合併是另一支 change。
