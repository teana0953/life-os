# Tasks

## 1. Controller: 允許 meal 延後綁定 (TDD)
- [x] Test first (red)：
  - 開一個未指定 meal 的 session → 可以加入 tray、調整、移除（與已指定時相同）
  - 未綁定 meal 就送出 → **不呼叫後端**（`CreateMeal` 的 fake 完全沒被叫到）
  - 綁定 meal 後送出 → 用那個 meal 呼叫 `CreateMeal`，`day` 是傳進來的那一天
  - 既有的「已指定 meal」路徑逐字不變（既有測試不得退化）
- [x] `CreateMealController`：允許在沒有 meal 的情況下 `start`；送出前才綁定。**`meal` 目前是 `String` 且只在 `submit` 最後一行用到** —— 改動限縮在「什麼時候知道 meal」，不要動 tray 的資料流。

## 2. Screen: meal 可選 + 選餐 sheet (TDD)
- [x] Test first (red)：
  - `meal == null` → 標題是「食物字典」；`meal` 已指定 → 標題仍是「加入 {餐別}」（既有）
  - `meal == null` 且 tray 為空 → **沒有** tray、**沒有**提交控制項
  - 點一個食物 → tray 與提交控制項出現
  - 送出（`meal == null`）→ 開選餐 sheet；選了之後才呼叫 controller 送出，且帶著選到的餐別
  - 選餐 sheet 被關掉（沒選）→ **什麼都沒送出，tray 還在**
  - `meal` 已指定時送出 → **不問**，直接送（既有行為）
- [x] `FoodSearchScreen`：`meal` 改 `String?`；標題分岔；送出前若 `meal` 為 null 則開 bottom sheet。
- [x] **隱藏提交按鈕與手動輸入連結**（`meal == null` 且 tray 為空時）。注意現況**兩者都是無條件渲染** —— 提交按鈕在 `bottomNavigationBar`，tray 空時只是 disabled（文案「完成（0）」）；`manual-entry-link` 一直都在。**不可以只把按鈕改成 disabled 就當作做完** —— disabled 的按鈕仍在說「這裡是拿來記錄的」。既有測試沒有任何一條斷言空 tray 時提交按鈕存在，所以隱藏不會造成退化。
- [x] 選餐 sheet：三個標準餐 + 一個「點心」。點心名稱用 `nextSnackName(mealNames, loc.dietSnackBaseName)` 算 —— 它在 **`snack_naming.dart`**（不是 `meal_label.dart`）。`mealNames` 由呼叫端傳入（飲食頁已經有），`FoodSearchScreen` 要新增這個參數。
- [x] `mealNames` 是 **push 當下的快照**：若當日餐點資料還沒載完就進字典，算出的點心名可能併入既有群組。這與飲食頁既有的 `_openAddSnack` 同風險同來源，**本 change 不處理**，但實作時不要自作主張去改既有行為。

## 3. 入口與路由 (TDD)
- [x] Test first (red)：
  - 飲食頁 AppBar 有查詢按鈕，**帶 tooltip**
  - 點它 push 到字典路由，`extra` 帶的是**當下瀏覽的那一天**（測試要瀏覽到非今天的日期再點，否則這條會恆真）與該日的 mealNames。**注意共用 harness `test/support/l10n_test_app.dart` 的 stub router 看不到 `extra`**（它只渲染 matchedLocation），要驗 day/mealNames 得在測試裡自建一個會捕捉 `state.extra` 的 `GoRouter`
  - 開字典前上一個 session 的 tray 已被重置（先在某一餐加東西、返回、再開字典 → 沒有提交區）
  - 路由在 `extra` 缺席時 redirect 回 `/health/diet`（比照既有 food-search）
- [x] `DietDayScreen`：AppBar 加 `IconButton`（純圖示 —— 那裡已有帶文字的「目標」按鈕）。開啟時**比照 `_openFoodSearch` 的三步**（`diet_day_screen.dart`）：`createMealController.start(...)` 重置 tray、`dictionaryController.clearSearch()`、`await` push 結果為 `true` 時 `_reloadCurrentDay()`。**少了 `start` 的話，前一次放棄的 tray 會洩進字典 session，一進去就看到提交區** —— tasks 2 的「tray 空時隱藏」也就白做了。
- [x] `lib/app.dart`：新增 `/health/diet/dictionary` 路由，比照 food-search 的 `extra` 處理與 `_Redirect`。
- [x] **窄螢幕**：AppBar 同時有「目標」（帶文字）與查詢圖示，在 320／360 寬下不得溢出。這個 repo 已有「Diet surfaces fit narrow」的既有需求與 overflow 測試慣例（`setSurfaceSize` + `addTearDown` 還原）—— **補一條自動化測試**，不要只靠人工看。若溢出，優先把「目標」也收成純圖示，而不是把查詢挪走。

## 4. l10n
- [x] 新增字串到 `app_en.arb`（含 `description`）+ `app_zh_Hant.arb` + `app_zh.arb`：字典標題、查詢入口 tooltip、選餐 sheet 標題。重新產生 `lib/l10n/generated` 並提交（CLAUDE.md i18n 規則）。

## 5. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠。既有的 food-search 測試（從某一餐進入的完整流程）零退化。

## 6. On-device verification (manual — 需使用者，部署後)
- [ ] 從飲食頁點查詢圖示，確認看到最愛清單、沒有任何記錄相關 UI。
- [ ] 查一個食物看份量，然後直接返回 —— 確認什麼都沒被記錄。
- [ ] 查完點一個食物 → 送出 → 選餐 → 確認落在正確的餐與**正確的日期**（先把飲食頁切到昨天再測）。
- [ ] 窄螢幕上看 AppBar 的「目標」與查詢圖示會不會擠。
