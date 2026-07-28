# Tasks

## 1. 純函式：狀態判斷 (TDD)

- [ ] Test first：`test/contexts/menstrual/domain/next_period_status_test.dart`
  - **0 筆紀錄 → `noRecords`**；**1 筆（`predictedNextStart == null`）→ `needsOneMore`**。兩者是不同文案：0 筆的人再記一次仍然沒有預測（後端要 ≥2 筆），對他說「再記錄一次就能預測」是做不到的承諾
  - 預測在未來 → `upcoming` + 天數；**跨月**（7/28 → 8/2 = 5 天）
  - 預測是今天 → `today`（**不是** `upcoming` 且天數 0）
  - 預測在過去 → `overdue` + 天數
  - 今天在某段週期內（已結束的）→ `ongoing` + 第 N 天；**起始日當天 = 第 1 天**
  - 某段沒有結束日、起始日 ≤ 今天 → `ongoing`
  - **`ongoing` 仍帶著預測日**（design D1）—— 斷言 status 同時有 ongoing 的天數與預測日期
  - **`ongoing` 且預測是 null**（唯一一筆紀錄就是進行中的那筆）→ 不 crash、預測日為 null。這是新使用者**第一次記錄當天**的狀態，一點都不罕見；照「ongoing 一定有預測」寫會對 null 做 `!`
  - **`ongoing` 優先於 `overdue`**
  - 週期的**結束日就是今天** → 仍 `ongoing`（閉區間）；**昨天結束** → 不是
  - **涵蓋今天的那段 vs 起始日更大但不涵蓋今天的那段 → 取涵蓋今天的**（`lastPeriod` 是起始日最大的那次，補記較早開始／較晚結束的週期時它不是涵蓋今天的那段；月曆用全部 periods 判斷，不一致的話兩個畫面會對同一天講相反的話）
  - **起始日在未來的紀錄不算 ongoing**（手滑記成未來日期）
  - **`clock` 帶時分秒**：`2026-07-28 15:30` + 預測日 `2026-07-29`（**預測日要建成本地午夜 `DateTime(2026,7,29)`，比照 `_parseDate`**；寫成 `DateTime.utc(...)` 會變成 32.5 小時差，兩種實作都得 1 天，這條就恆綠了） → **`upcoming` 1 天，不是 `today`**。紀錄日期是本地午夜、`clock()` 帶當下時間，沒有兩邊都剝成 UTC 午夜就會被那幾個小時吃掉一天 —— **這是每天下午都會發生的**。**不要**寫切 `TZ` 環境變數的測試：Dart 的本地時區在 process 啟動就定了，單一測試裡切不掉，而 UTC 與 Asia/Taipei 都沒有 DST，那種測試恆綠
- [ ] `lib/contexts/menstrual/domain/next_period_status.dart`：`computeNextPeriodStatus(overview, today)` 純函式，**掃 `overview.periods` 找涵蓋今天的那段**，不碰 `DateTime.now()`。**分支順序寫死、全程不用 `!`**（design D1 末段）

## 2. 卡片 (TDD)

- [ ] Test first：`test/contexts/menstrual/presentation/next_period_card_test.dart`
  - 每種狀態渲染對應文案（用 `loc.xxx` 比對，不寫死字串）
  - **`ongoing` 且無預測 → 次要那行整個不出現**（`findsNothing`）。上一輪要防的 `!` crash **最可能發生在這一層** —— 純函式只回 `DateTime?`，真正要格式化它的是卡片，所以純函式測試會綠、卡片照樣可以在新使用者第一次記錄當天炸掉
  - **點擊卡片會呼叫 `onOpen`**，**沒有預測時也會**（D6）
  - 首次載入（`loading` 且 `overview == null`）→ 轉圈
  - **重新載入（`loading` 但已有 overview）→ 保留內容**（#82 的教訓；`MenstrualController.load` 設 loading 但不清 overview，所以假 controller 擺得出這個狀態，這條真的能紅）
  - `error` → 卡內錯誤訊息（**重用既有的 `errorMenstrualLoadFailed`**）
  - 卡片**不呼叫** `load` —— 假 controller 斷言 load 次數為 0
- [ ] `lib/contexts/menstrual/presentation/next_period_card.dart`：`LedgeCard` + `InkWell`，比照 `GoalCard`。`clock` 注入（D3）

## 3. l10n

- [ ] 三個 ARB 加：`nextPeriodTitle`、`nextPeriodUpcoming`(date, days)、`nextPeriodToday`、`nextPeriodOverdue`(date, days)、`nextPeriodOngoing`(day)、`nextPeriodOngoingNext`(date)、`nextPeriodNoRecords`、`nextPeriodNeedsOneMore`。en 要有 `@` 描述。**錯誤文案不開新 key** —— 重用 `errorMenstrualLoadFailed`
- [ ] 日期用既有的 `mediumDateLabel`（生理期頁統計卡就是用它）
- [ ] 重產 `lib/l10n/generated/` 並 commit（tracked）

## 4. 接進總覽

- [ ] `_OverviewBody` 加 `NextPeriodCard`，**放在 `GoalCard` 之後、`HealthCalendarCard` 之前**（`GoalCard` 與 `HealthCalendarCard` 之間目前只有一個 `SizedBox(height: 16)`，插卡要補間距）（D7：月曆是一整格月曆＋三個環，放它後面等於手機上必在第一屏外，而這張卡的全部價值就是不用點進去就看得到）
- [ ] `onOpen: () => context.push('/health/menstrual')` —— **不是 `/menstrual`**。生理期頁是 `/health` 的巢狀子路由（`app.dart` 的 `path: ':name'`），記錄分頁自己就是 `/health/$name`；router 沒有 `errorBuilder`，導錯會掉進 go_router 內建的 not-found 畫面
- [ ] `_OverviewBody` 收 `MenstrualController`；`HealthScaffold` 傳下去
- [ ] `_overviewControllers` 與 `_overviewNeedsReauth` 加 menstrual。**理由是 401**：`_overviewNeedsReauth` 只在 scaffold 自己重建時重算，不加的話 menstrual 專屬的 401 要等別的 controller 動一下才會浮出重新登入的出口。（不是「卡片不會重建」—— 卡片自己 `addListener`，跟 `GoalCard` 一樣。）
- [ ] 測試：總覽上看得到卡片、點了會**真的到生理期頁**。**用 production 的 router，不要自建**（#88 那輪抓到的坑：自建 router 讓「真實 route 收到後怎麼用」零覆蓋）。`test/app_test.dart` 已有 `router.go('/health/water')` 的寫法可比照
- [ ] 既有的 `overview ordering` 兩條測試用 `getTopLeft(...).dy` 比較、不是 index，所以順序改動安全；但**新卡在預設 800×600 viewport 可能 offstage**，測試要比照同檔既有那條 `setSurfaceSize`

## 5. Gate

- [ ] `flutter analyze` 零 issue、`flutter test` 全綠。基準 **1177 passed / 1 skipped**

## 6. On-device verification (manual — 需使用者)

- [ ] 總覽上看得到卡片（在體重目標與月曆之間），點了會到生理期頁、返回回得來
- [ ] 目前狀態顯示正確（進行中／還有幾天／已晚幾天）
- [ ] 窄螢幕上讀得順
