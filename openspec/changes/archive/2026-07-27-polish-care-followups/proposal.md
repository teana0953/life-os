## Why

照護這條線連續五個 change(#78/#79/#80 → backend#52 → #91 → backend#53 → #93)累積了兩份
follow-up(`move-care-chart-to-trends`、`care-edit-done-time`),使用者要求**四組全做**:
無障礙＋技術債、heatmap 可讀性、空狀態與錯誤態、導覽堆疊。

**本 change 做 A/B/C/E 三組 + 技術債;D 組(導覽堆疊)拆成獨立 change** —— 它是唯一牽涉
GoRouter 堆疊語意的一組,而且原本的規則有錯(「在下方就 pop」在「不緊鄰下方」時會 pop
到錯的畫面,有 4 步可達的反例),還有兩個要自覺的副作用(`pushReplacement` 會吃掉
care-history 那一頁;深連結直接進 `/care-history` 時 pushReplacement 後沒有返回目標)。
理由詳見 design.md「拆出去的 D 組」。

這些都是 review/QA 提出但當時判為非阻斷的項目 —— 沒有一條是新功能,全部是把已經上線的
照護介面補到「該有的樣子」。

**已經不用做的一條**:⋮ 那個 `PopupMenuItem(enabled: false)` 的無障礙問題隨 #93 移除
註記項一起消失。
(**更正**:legend `partial` 的對比**沒有**被 #91 修掉 —— #91 統一的是 swatch 的顏色來源
(`_LegendDot` 改吃 `_dayStateColor`),門檻仍訂在 1.3:1。重調到 WCAG 3:1 會動到五個狀態
的視覺關係,列為不做,見 design.md。)

## What Changes

### A. 無障礙

- **heatmap 每格被念兩遍**:`Tooltip` 預設 `excludeFromSemantics: false`,會在**同一個
  merged node** 上再設一個 `SemanticsProperties.tooltip`(不是第二個節點),與外層的
  `Semantics(label:)` 內容重複。→ `Tooltip(excludeFromSemantics: true)`。
- **90 格沒有摘要**:90 天時產生 90 個可聚焦節點,螢幕閱讀器要一格一格聽完才知道全貌。
  → 在 grid **之前**加一個承載摘要的語意節點(標題 + 各狀態天數,用**已經算好的**
  `careDayStateCounts`),讓 SR 使用者先聽到全貌。
  **不是**把 grid 收成單一節點:`Semantics(explicitChildNodes: true)` 的語意正是
  「讓子節點各自保留」,收不掉;而 `excludeSemantics: true` 雖然收得掉,卻會拿走
  「每格可讀」—— 那是上一個 change 為了「色彩不是唯一訊號」才加的。詳見 design D1。
- **edit affordance 沒有語意**:今日照護已完成列與 `/care-history` 的 `_SlotTile` 的
  `Icons.edit_outlined` 都沒有 `semanticLabel`/`tooltip`,螢幕閱讀器只念出「藥名 · 時間」,
  不知道可編輯。→ 兩處都補。
- **兩處編輯 sheet 都沒有可達的關閉出路**(今日照護與 `/care-history`):
  `showModalBottomSheet` 沒帶 `showDragHandle: true`(repo 內 `exercise_screen` /
  `goal_card` 的同類 sheet 都有)。drag handle 是 48dp、包在 `Semantics(button, onTap 關閉)`
  裡的關閉目標。→ 兩處都補。

### B. heatmap 可讀性

- **欄數改固定 7**:現在用 `maxCrossAxisExtent: 26` 依寬度推導(360dp 下算出 10 欄),
  所以欄位與星期無對應,手機上要長按才知道哪一格是哪天。改成每列 7 天後,
  **同一欄必然是同一個星期幾**,再加一行依起始日推算的**星期表頭**就讀得出來。
  (**不補前導空格**、格數仍 = 天數 —— 期間起始是任意星期,所以這是「每列七天」
  而非日曆週,spec 措辭照這個寫,不宣稱 "a row is a week"。詳見 design D3。)
- **格子要有尺寸上限**:7 欄在 600dp 寬的卡片內會撐成約 **71.1dp**、90 天高約 **961dp**
  (現況 18 欄約 25.8dp、90 天約 141dp,**差約 6.8 倍**),而且因為外層是 ListView
  **不會 overflow、測試也不會紅**。→ 單格上限 **24dp**(90 天約 348dp,約 2.5 倍;
  高度變高是「7 欄」的固有代價,詳見 design D2 的取捨說明)。
- **加日期軸**:grid 下方一行起訖日期 caption;**今天那格**用與既有每格描邊區分得出來的
  描邊。

### C. 空狀態與錯誤態

- **紀錄頁空狀態每一級都給兩顆**:主要「看更長期間」+ 次要「前往照護管理」;
  90 天時只留後者,並把 body 文案換成「還沒有任何照護項目」(現在 90 天時文案仍是
  「這段期間沒有排程」,與唯一那顆按鈕語意脫節)。新使用者不必點兩次、跑兩次網路往返
  才看到唯一對他有用的行動。
- **照護達成卡的空狀態給行動**:「前往照護管理」。**卡片目前沒有**指向照護管理的
  callback(只有 `onOpenHistory`),要新增一個並從 `_TrendBody` 往下傳
  (`HealthScaffold` 自己已有 `onOpenCareItems`)。
- **錯誤文案帶入期間**:兩處 error 態現在都只顯示 `careErrorGeneric`,沒講**哪一段期間**
  失敗 —— 而保留期間選擇器的整個理由就是讓使用者知道可以換一個。兩處並統一用
  `colorScheme.error`(紀錄頁現在沒有任何 style 也沒有圖示)。
- **編輯失敗/丟棄時保留使用者選的時間並給重試**:現在 sheet 已 pop、選好的時間全丟,
  而同畫面的 inline 完成/略過是**有** `SnackBarAction(retry)` 的。被 gate 丟棄那條更不
  合理 —— 其實什麼都沒壞,卻顯示「發生問題,請再試一次」。
- **widen 按鈕在自己的重載進行中沒有停用**:快速雙擊會 7→30→90 一次跳兩級。

### D. 導覽堆疊 —— **拆成獨立 change,不在本 change**

見 design.md「拆出去的 D 組」。

### E. 技術債(不改外觀)

- `markError` 跨慣例污染:`_mark` 的 gate 在 `markError = null` **之前**觸發,而 `edit`
  失敗後留著 `markError` 不清 → 一個**從未被嘗試**的 inline 動作會彈出失敗 SnackBar。
- malformed 後端資料的新 crash 路徑:`_parseTimeOfDayString` / `parseDayString` 用
  `int.parse` 會拋,而它們現在在 sheet 建構期執行(`late _doneTime = _initialDoneTime(…)`)。
  **共四個同類路徑**(`_doneInstantOn` 裡那個**每次選完時間**都會再跑),而且
  `localDate` 不可解析時要**不送 `doneTime`** —— 代一個日期會把紀錄寫到錯誤的日子上,
  比崩潰更難發現。詳見 design D4。
- `test/app_test.dart` 的跨午夜 flake:**保留**那條整合測試(它是唯一跨模組的覆蓋 ——
  走完路由、驗 bump、驗卡片刷新且保有自己的期間),**另加**一條 pin clock 的隔離測試;
  那 1s/86400 的視窗**接受**(在不動 `app.dart` 的前提下修不掉)。
- `_scheduleLoad` 的過期註解(12→13 個 controller,且不變式已不涵蓋卡片自己的 `setSpan`)。
- `setSpan(String idToken, int days)` 的參數名遮蔽 controller 自己的 `days` 欄位。
- `health_scaffold_test` 401 測試的敘述與 fixture 不符(說渲染 heatmap,實際是空狀態)。
- `care_history_screen_test` 的 error 態測試沒斷言 **AppBar** 留存(重構的另一半)。
- `app_test.dart` 的 `_MutableCareHistoryRepository.editSlot` 用寫死模板重建 slot,
  不保留識別欄位 —— 加第二個 slot 就會靜默改寫。
- ARB `description` 過期(`careHistory*` 那批仍寫「in the care history chart mode」,
  而該畫面已刪除;`careHistoryEmpty*` 現在也被卡片的空狀態共用)。

## Impact

- Affected specs: `care-today-ui`、`care-history-ui`、`care-adherence-trend`(皆 MODIFIED)
- **落地順序**:E(無行為改變)→ B(單檔 heatmap)→ A(兩檔語意)→ C(狀態機與文案),
  每組結束都要 analyze + test 全綠。
- Affected code: `care_adherence_card.dart`、`care_history_screen.dart`、
  `care_today_screen.dart`、`care_today_controller.dart`、`care_history_controller.dart`、
  `health_scaffold.dart`、三個 ARB + 產物(**不動** `app.dart`,見 tasks 1.3)
- **不動**(維持既有判定):不抽 AppBar「紀錄」入口的共用 widget(仍 2 份);不動
  `TrendController`/`TrendCard`;heatmap 不做點格跳日;**趨勢分頁不做 route-addressable**
  (要把 tab index 變成 route/query param,是架構改動,超出 follow-up 範圍);
  跨午夜的 `_doneInstantOn` 語意(design 明確取捨);`parseInstant` 的 offset 驗證;
  「昨天漏的藥過午夜無法補登」(使用者在 issue #90 明確要求的行為)。
