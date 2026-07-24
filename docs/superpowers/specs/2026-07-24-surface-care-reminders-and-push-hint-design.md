# 照護提醒管理好抵達 + 通知未開提示 — 設計文件

日期:2026-07-24
狀態:已批准方向(不合併提醒設定;總覽兩個入口 + care-items 通知未開 banner)

## 問題

延續 #78(今日照護搬上總覽):

1. **照護提醒管理(`/care-items`,設定吃藥/復健排程)還在更多分頁太深**——設定入口與
   總覽的日常行動脫節;新使用者(還沒排程)因 #78「無排程→不顯示卡」在總覽上什麼都看不到,
   最該淺的「去設定照護」路徑反而最深。
2. **提醒設定與照護提醒管理沒有連結**——使用者可能設了一堆照護提醒,卻沒開推播通知,
   於是提醒永遠不會送達,而管理畫面對此毫無提示。

使用者定案:**提醒設定維持在更多當獨立 tile(不合併)**;改為在照護提醒管理裡,當通知
沒開時給出提示。

## 範圍

### A. 總覽兩個入口(照護提醒管理太深)

- **今日照護總覽卡標題列**(#78 的 `CareTodaySummaryCard`)加一個「管理」入口(齒輪或文字鈕)
  → `context.push('/care-items')`。有排程時,管理 1 tap 可達。
- **無排程時**:卡片不再全隱藏(改掉 #78 的 no-schedule → SizedBox.shrink),改顯示一條
  **slim「還沒有照護提醒 · 設定 →」CTA** → `/care-items`。新使用者在總覽第一眼即有設定入口。
  - 其他非 loaded 狀態(loading/error/reauth)仍不顯示卡(維持 #78)。

### B. 照護提醒管理的「通知未開」提示

- `CareItemsScreen` 取得 `ReminderSettingsController`(**只為讀推播狀態**,不嵌入完整設定卡)。
- 在清單頂部(mutation error 之下、分類清單之上),若**推播未開**,顯示一條提示 banner:
  「通知未開啟,提醒不會送達 · 開啟通知」→ 點 `context.push('/reminders')`。
- **「推播已開」判定**(關鍵):`ReminderSettingsController.load()` 的 `status` 在上次 session
  已訂閱時仍回 `idle`(它只在同 session `enable()` 成功後為 `enabled`),故不可只看 `status`。
  在 controller 加唯讀 getter:
  `bool get pushOn => status == ReminderSettingsStatus.enabled ||
   _gateway.permissionStatus() == PushPermissionStatus.granted;`
  (讀既有 gateway 的 `permissionStatus()`,不改 enable/test 邏輯。)banner 條件 = `!pushOn`。
- care-items `initState` 呼叫 `reminderSettingsController.load()` 解析狀態後讀 `pushOn`;
  監聽 controller → banner 隨狀態更新。單一 banner 文案涵蓋 denied/default/unsupported
  等情形(細節導引留給 `/reminders` 畫面,已具備 blocked-state 說明)。

## 不做(YAGNI / 範圍外)

- **不合併**提醒設定畫面/route/tile——`ReminderSettingsScreen`、`/reminders`、更多分頁
  「提醒設定」tile 全部保留不動。
- 不動後端、不動推播 enable/test 邏輯(只加一個唯讀 getter 讀既有 gateway 狀態)。
- 不動底部導覽;不移除更多分頁的「照護提醒」tile(留作 fallback)。

## 驗收標準

1. 總覽今日照護卡(有排程)標題列有「管理」入口,點 → `/care-items`。
2. 無排程(loaded 且 slots 空)時,總覽顯示 slim 設定 CTA(非隱藏、非 GoalCard 頂替),
   點 → `/care-items`。
3. loading/error/reauth 仍不顯示 care 卡(維持 #78)。
4. `/care-items` 頂部:推播未開(pushOn=false)→ 顯示「通知未開啟」banner,點 → `/reminders`。
5. 推播已開(status==enabled 或 permission==granted)→ 不顯示 banner。
6. 提醒設定 tile / `/reminders` route / `ReminderSettingsScreen` 維持存在可用。

## 測試策略

- `CareTodaySummaryCard`:更新 no-schedule 測試(原本斷言不顯示 → 改斷言顯示 slim CTA 且
  點觸發 push `/care-items`);新增「管理」入口點觸發 push 的測試。既有五態其餘不變。
- `HealthScaffold` 測試:無排程 → 總覽第一張是 care CTA(而非直接 GoalCard);對應調整。
- `CareItemsScreen`:注入 fake `ReminderSettingsController`,pushOn=false → banner 顯示且
  點觸發 push `/reminders`;pushOn=true → 無 banner。care-items 既有清單/CRUD 測試不受影響。
- `ReminderSettingsController` `pushOn` getter:單元測試三種來源(enabled / permission granted
  / 皆非)。
