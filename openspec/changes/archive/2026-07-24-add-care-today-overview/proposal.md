## Why

今日照護(Today checklist)是每日、有時效的行動面(吃藥/復健/放療保養),但目前只藏在
健康模組的 **更多(More)** 分頁裡,和低頻設定並列——打開 App 的預設落地頁(總覽)完全
看不到,逾期用藥可見度為零,需 2 次點擊且得先知道去更多找。把今日照護的摘要搬到總覽
(預設分頁)頂部,讓最該「現在做」的事第一眼可見、可就地完成。

## What Changes

- 新增 `CareTodaySummaryCard`(`lib/contexts/notifications/presentation/`):一張由既有
  `CareTodayController` 驅動的**薄殼**摘要卡,緊急度驅動變臉:
  - **有逾期** → 紅色 accent;顯示 `focusSlot`(最早逾期:標題/時間/劑量)+ 就地
    `完成`/`略過`;底部「還有 N 項 · 全部 →」。
  - **只有待辦** → 「接下來 · HH:mm」顯示最早 pending + 就地 `完成`;底部「還有 N 項 →」。
  - **全部完成**(有排程) → 迷你 mascot + 慶祝文案。
  - **無排程**(loaded 且 slots 空) → **不顯示**此卡。
  - **載入中 / error / reauth** → 靜默不顯示卡(不阻斷總覽其他卡)。
  - 標題列右側進度 pill `{done}/{total}`;點整卡 → `context.push('/care-today')`;
    就地動作走 `markDone`/`markSkipped`——這兩者需 `idToken`(定位參數)+ 由 slot 取
    `careScheduleId`/`localDate`/`timeOfDay`,故卡片建構子收 `idToken`(總覽已有,見
    `health_scaffold.dart:220`);控制器安靜重載,不觸發總覽全頁 loading。
  - **就地標記失敗**:控制器保留原 slots 並設 `markError`;卡片以 SnackBar(沿用
    `CareTodayScreen` 的失敗 + 重試文案)提示,避免「看似成功實則沒動」——不靜默吞掉。
- 修改 `HealthScaffold`(`lib/contexts/health/presentation/health_scaffold.dart`):
  - 建構子新增 `careTodayController`;`_load()` 的 `Future.wait` 加
    `careTodayController.load(token)`;把它加入 `_overviewControllers`(監聽→setState)。
  - `_OverviewBody` 收 `careTodayController`,在 `ListView` 最上方(GoalCard 之上)放
    `CareTodaySummaryCard`。
- 修改 `app.dart`:把既有 `widget.careTodayController` 傳入 `HealthScaffold`。
- 新增 i18n(en + zh-Hant + zh):進度 pill、「接下來」「還有 N 項」「全部」等;沿用既有
  `careTodayCelebrationTitle` 等鍵;regenerate localizations。
- 修正推播深連結(`web/push_sw.js`):點通知目前寫死開 App 根 `/`,不是能處理的地方。
  本 App 未呼叫 `usePathUrlStrategy()`,web 走 go_router **預設 hash 策略**,路由在
  `/#/...`——所以深連結目標必須是 `/#/care-today`(裸路徑 `/care-today` 無 hash fragment
  會落回首頁)。
  - `push` handler:`showNotification` 帶 `data: { url: data.url || '/#/care-today' }`。
  - `notificationclick`:`clients.openWindow(event.notification.data?.url || '/#/care-today')`
    取代寫死的 `/`。後端未帶 url 時退化為今日照護 checklist(現階段推播皆為照護提醒),
    向後相容、暫不動後端(後端日後若帶 url 亦須用 hash 形式)。跳到特定 slot 的更深連結
    留待後續(需 payload 帶 slot id)。

僅前端、僅總覽行動面 + 推播深連結。**不動** `CareTodayScreen`/`CareTodayController` 邏輯(只消費既有
`focusSlot`/`groups`/`markDone`/`markSkipped`)、**不動**後端、**不動**底部導覽、**不移除**
更多分頁的既有入口。提醒設定/照護提醒管理的合併是**另一支** change,不在本次。
Gate = `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `care-today-ui`: 除了更多分頁的入口與完整 checklist 外,健康模組的**總覽(預設分頁)**
  頂部新增一張緊急度驅動的今日照護摘要卡——第一眼看到最該做的照護、可就地標記完成/略過、
  可一鍵進完整清單;無排程時不顯示。另外,點推播通知會落在今日照護 checklist(能處理的
  位置),而非 App 根。
