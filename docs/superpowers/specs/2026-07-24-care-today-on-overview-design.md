# 今日照護搬上總覽 — 設計文件

日期:2026-07-24
狀態:已批准方向(總覽頂部自適應摘要卡)

## 問題

「今日照護」checklist(`CareTodayScreen`)是每日、有時效的行動面
(吃藥／復健／放療保養),但目前它是 `HealthScaffold` 的 **更多(More)**
分頁裡的第一個 `ListTile`,和「提醒設定／照護提醒管理／匯入／設定」這些
低頻設定並列。

三個 UX 問題:

1. **資訊氣味錯位**:「更多」在心智模型是「雜項/設定抽屜」,把每日時效
   行動放這裡等於把鬧鐘塞進工具箱。
2. **2 次點擊 + 需先知道去更多找**:逾期用藥在打開 App 時可見度為零。
3. **預設落地頁(總覽)缺少最該行動的東西**:總覽只有回顧型卡片(體重
   目標、記錄日曆),真正「現在要做」的照護不在場。

## 設計原則

把今日照護放到第一眼會看到的地方(總覽,預設分頁),用**緊急度驅動**
呈現,並讓主要動作(標記完成/略過)就地或一鍵可達。

## 方案:總覽頂部「今日照護」自適應摘要卡

在 `HealthScaffold._OverviewBody` 的 `ListView` **最上方**(GoalCard
之上)新增 `CareTodaySummaryCard`,由既有的 `CareTodayController` 驅動。

### 卡片狀態(緊急度驅動)

控制器已提供現成衍生狀態,卡片是薄殼、不含新業務邏輯:
`focusSlot`(最早逾期,否則最早 pending,否則 null)、`groups`
(overdue/later/done)、`markDone`/`markSkipped`。

| 狀態 | 判斷 | 呈現 |
| --- | --- | --- |
| 有逾期 | `groups.overdue` 非空 或 `focusSlot.status == overdue` | 紅色 accent;顯示 `focusSlot`(標題、時間、劑量)+ 就地 `完成`/`略過`;底部「還有 N 項 · 全部 →」 |
| 只有待辦 | `focusSlot != null` 且非逾期 | 「接下來 · HH:mm」顯示 `focusSlot` + 就地 `完成`;底部「還有 N 項 · 全部 →」 |
| 全部完成 | 有排程但 `focusSlot == null` | 迷你 mascot + `careTodayCelebrationTitle`;點卡進完整清單 |
| 沒有排程 | `slots` 為空(loaded) | **整張卡不顯示**(對沒設定照護的人零雜訊) |
| 載入中/錯誤/reauth | 對應 `CareTodayLoadStatus` | 載入中不顯示卡(避免版面跳動);reauth/error 不阻斷總覽其他卡,靜默不顯示卡 |

- 標題列右側顯示進度 pill:`{done}/{total} 完成`(total = 有排程的 slot 數,
  done = done+skipped+missed 的數量;沿用既有計數,不新增文案語意)。
- 點整張卡 → `context.push('/care-today')` 進完整 checklist。
- 就地 `完成`/`略過`:呼叫 `careTodayController.markDone/markSkipped`,
  控制器自帶「安靜重載」(status 全程停在 loaded),卡片透過 `notifyListeners`
  自更新;不重載總覽其他卡。就地動作進行中,依 `markingAction(slot)` 只在
  該列顯示 spinner/停用。

### 資料載入

`HealthScaffold._load()` 已用 `Future.wait` 並行載入多個 controller。
新增 `widget.careTodayController.load(token)` 到該 `Future.wait`,並把
`careTodayController` 加入 `_overviewControllers`(監聽 → `setState`),
再傳入 `_OverviewBody`。DI 已在 `app.dart` 具備 `careTodayController`,
只需沿 `app.dart` → `HealthScaffold` → `_OverviewBody` 串接。

### 更多分頁

保留更多分頁的「今日照護」入口(`health-more-care-today`)不動——它與
總覽卡是「今日 vs 管理路徑」的互補入口,移除屬於超出範圍的清理。

## 推播深連結修正(同本次)

點推播通知目前落在 App 根 `/`,不是能處理的地方。`web/push_sw.js`:

- `push` handler → `showNotification(title, { body, data: { url: data.url || '/care-today' } })`。
- `notificationclick` → `clients.openWindow(event.notification.data?.url || '/care-today')`
  取代寫死 `/`。

後端未帶 `url` 時退化為今日照護 checklist(現階段推播皆照護提醒),向後相容、不動後端。
`/care-today` 頂部即最緊急 slot,是「處理位置」。跳到特定 slot 的更深連結需 payload 帶
slot id,留待後續。

## 不做(YAGNI / 範圍外)

- 不改底部導覽(不新增第 5 分頁)。
- 不加跨頁橫幅。
- 不動 `CareTodayScreen` 本身、不動後端、不動 `CareTodayController` 邏輯
  (只消費既有衍生狀態)。
- 不移除更多分頁的既有入口。

## 驗收標準(供 QA / 測試)

1. 有逾期 slot 時,總覽頂部出現紅色 accent 卡,顯示最早逾期 slot 與
   `完成`/`略過` 就地按鈕。
2. 無逾期但有待辦時,卡片顯示「接下來」+ 最早 pending slot。
3. 全部完成(有排程)時,卡片顯示慶祝態。
4. 無任何排程(loaded 且 slots 空)時,總覽**不出現**此卡,GoalCard
   仍為第一張卡。
5. 在卡上點 `完成` → 呼叫 `markDone`,卡片隨控制器安靜重載更新,不觸發
   總覽全頁 loading。
6. 點卡片主體 → 導到 `/care-today`。
7. 點推播通知 → 開啟 `/care-today`(而非 App 根),後端未帶 url 時亦然。

## 後續(另一支 change,不在本次)

「提醒設定(`/reminders`,Web Push 開關/測試)」與「照護提醒管理
(`/care-items`,排程 CRUD)」是同一個 config 面,適合合併:把提醒設定收成
照護提醒管理畫面頂部的「推播通知」section,更多分頁只剩單一「照護提醒」
入口。本次聚焦總覽行動面、不動這兩個畫面;合併緊接本次另開一支切小 change。

## 測試策略

- 卡片為薄 presentation widget:widget test 注入 fake `CareTodayController`
  (或用既有測試替身)覆蓋五種狀態 → 對應呈現;點 `完成` → 觸發
  `markDone`;點卡 → 觸發 push(以 router 觀察或 callback 驗證)。
- `HealthScaffold` 既有 widget test 補一條:總覽含 care 卡(有排程)/
  不含(無排程)。
- `deriveFocusSlot`/`deriveGroups` 已有單元測試,不重複。
