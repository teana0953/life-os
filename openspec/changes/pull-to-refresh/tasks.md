# Tasks

## 1. 各追蹤 controller 的 `lastLoadedAt`（TDD）

- [ ] Test first：water/vitals/bowel/exercise 四個 controller 各補測試 ——
      `load()` 成功後 `lastLoadedAt == 注入 clock 的值`；needsReauth/error 分支**不寫**
      （維持前值 / 保持 null）。用可注入 clock 驗
- [ ] 四個 controller 各加 `DateTime? lastLoadedAt` + 選填建構子參數
      `DateTime Function() clock = DateTime.now`（比照 home greeting clock、
      reminders 節流 clock 的既有慣例）
- [ ] `load()` 成功分支寫 `lastLoadedAt = _clock()`；needsReauth/error 分支不碰

## 2. `HealthScaffold`：`_scheduleLoad()` 回 Future + `_lastOverviewLoadAt`（TDD）

- [ ] Test first（health_scaffold_test.dart）：
      - `_scheduleLoad()` 回的 Future 在該輪載完時 resolve
      - **載入中再觸發**：兩次呼叫回的 future 都要等到最終那輪（合併去重下只 complete 一次），
        不得併發第二次 `_load`
      - token fetch 丟例外時 future 仍 resolve（否則下拉 spinner 永遠卡住）
      - `_lastOverviewLoadAt` 成功後 = 注入 clock 值；`_load` 丟例外時不更新
- [ ] `_scheduleLoad()` 由 `void` 改回 `Future<void>`：持 `Completer<void>? _refreshCompleter`，
      **整個 in-flight 期間重用同一個**（不是每輪建新的）：進來時 null 才建、否則回既有 future；
      `whenComplete` 裡有 pending → 續跑但**不碰 completer**；沒 pending → `complete()` 一次後
      設回 null。**沿用既有 `_loading`/`_reloadPending`**，不另立第二套。
      既有 `initState`/`_onRevisionChanged` 呼叫點丟棄回傳值即可（`unawaited`）。
      **測試釘**：載入中再觸發，兩次回同一個 future、只 complete 一次、不永久卡（每輪建新
      completer 會讓手勢 future 永不 resolve 或被 complete 兩次）
- [ ] 新增 `DateTime? _lastOverviewLoadAt`。**看 controller status 判成功，不看 `Future.wait`**：
      `_load()` 之後，overview/trend 六個 controller 中**至少一個是 `.loaded`** 才寫
      `widget.clock()`；全部失敗（含斷網四卡全紅）不寫、保留舊值。
      **這條的測試最關鍵**：模擬「token fetch 成功、四卡 controller 全 error」→
      `_lastOverviewLoadAt` **不更新**（`Future.wait` 會 resolve 但時間戳不能跳）。
      只驗「成功時更新」對這個 bug 照樣會過
- [ ] `HealthScaffold` 已有可注入 `clock`（build 用它算 greeting/day）——確認沿用同一個，
      不要新增第二個 clock 來源

## 3. 總覽 + 趨勢：RefreshIndicator + 時間戳（TDD）

- [ ] `_OverviewBody`（health_scaffold.dart:388 的 ListView）包一層
      `RefreshIndicator(onRefresh: () => <回傳 Future 的重載路徑>)`。
      onRefresh 要拿到 `_HealthScaffoldState._scheduleLoad` 的 future ——
      透過 callback 參數傳進 `_OverviewBody`（`Future<void> Function() onRefresh`），
      不要讓 StatelessWidget 自己持狀態
- [ ] **每個被 RefreshIndicator 包住的 scrollable 都要 `physics: const AlwaysScrollableScrollPhysics()`**
      —— 不限 `ListView`。總覽/趨勢/water/bowel/exercise 是 `ListView`；
      **vitals 是 `SingleChildScrollView`**（vitals_screen.dart:305，刻意，有註解），
      同樣要加。否則內容短於視窗時下拉靜默失效（趨勢兩張卡、追蹤畫面當天沒資料、
      vitals 當天沒 reading 都會踩到）。測試看不出來，實機才炸 —— 逐一確認
- [ ] `_TrendBody` 的 ListView 同樣包 `RefreshIndicator`，共用同一個 `onRefresh` callback
      （總覽/趨勢都走 `_load()`）
- [ ] `_lastOverviewLoadAt` 透過參數傳進 `_OverviewBody` 與 `_TrendBody`，
      各自頂端放 `LastLoadedLabel`
- [ ] widget 測試：兩個分頁各有 `RefreshIndicator`、下拉觸發重載、時間戳顯示注入 clock 的
      時分字串、`null` 時不顯示

## 4. `LastLoadedLabel` 共用 widget（TDD）

- [ ] Test first：`test/shared/widgets/last_loaded_label_test.dart` ——
      `null` → `SizedBox.shrink()`（不顯示）；有值 → 顯示「上次更新 <HH:mm>」
- [ ] `lib/shared/widgets/last_loaded_label.dart`：吃 `DateTime?`，
      時分用 `TimeOfDay.fromDateTime(dt).format(context)`（跟隨系統 12/24 制），
      弱化色（`textTheme.bodySmall` + `onSurfaceVariant`），純文字（螢幕閱讀器可讀）
- [ ] l10n：三個 ARB 檔（app_en.arb 含 `@` 描述、app_zh.arb、app_zh_Hant.arb）
      加一個帶 `{time}` placeholder 的 key（例：`lastUpdatedAt` → 「上次更新 {time}」/
      「Updated {time}」）+ vitals 未存確認的三個 key（標題／訊息／捨棄鈕，
      例：`refreshDiscardTitle`/`refreshDiscardMessage`/`discard`）。
      `flutter gen-l10n`，生成檔一起 commit

## 5. `TrackerDayScreen` mixin：reloadDay 回 Future + 下拉 + 時間戳（TDD）

- [ ] `reloadDay(String day)` 由 `void` 改成 `Future<void>`（tracker_day_nav.dart:21 的
      抽象方法簽章）；`setDay`/`openDefaultCalendar` 內的呼叫不需 await（維持現行行為，
      但可以拿到 future 若之後要用）
- [ ] 四個實作（water/vitals/bowel/exercise screen 的 `reloadDay`）改成回 Future ——
      本來就是 `controller.load(idToken, day)`（回 Future），加 `return`／改箭頭函式
- [ ] mixin 加包裝方法
      `Widget refreshable({required Widget child, Future<void> Function()? onRefresh})` →
      `RefreshIndicator(onRefresh: onRefresh ?? () => reloadDay(viewedDay), child: child)`。
      **統一在 mixin 做一次**；water/bowel/exercise 三畫面直接用預設，把 `ListView`
      （帶 `AlwaysScrollableScrollPhysics`）包進去
- [ ] **vitals 傳自己的 `onRefresh`**：`hasUnsavedChanges` 為 true 時先跳確認
      （「有未儲存的變更，重新整理會捨棄」走 ARB），確認才 `reloadDay(viewedDay)`，
      否則不重載、手勢直接收；沒有未存變更就照常。**確認閘放在 vitals 畫面，不塞進共用 mixin**
      —— 其餘三畫面沒有 draft-覆寫問題，不該被污染
- [ ] 四個畫面在 `dayNavHeader` 之下、內容之上放 `LastLoadedLabel(controller.lastLoadedAt)`
- [ ] widget 測試：三個無 draft 畫面下拉會呼叫 `reloadDay(viewedDay)`；
      **vitals 有未存變更時下拉跳確認、取消則不重載**；四個時間戳顯示 controller 的
      `lastLoadedAt`；`reloadDay` 回 Future（單元）

## 6. 收尾

- [ ] `flutter analyze` 零 issue
- [ ] `flutter test` 全綠，且看到 `All tests passed!`（沒有紅字不等於通過）
- [ ] `bash scripts/lint-actions.sh`
