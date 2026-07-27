> 落地順序刻意是 **E → B → A → C**(風險由低到高,每節結束都要 `flutter analyze` +
> `flutter test` 全綠,才算一個 checkpoint)。**D 組(導覽堆疊)已拆成獨立 change**。
> 新 ARB key 一律**三檔齊改**(`app_en.arb` + description → `app_zh_Hant.arb` →
> `app_zh.arb`)再 `flutter gen-l10n`,產物要提交。

## 1. E 組:技術債(無行為改變優先)

- [x] 1.1 (red) `care_today_controller_test.dart`:被 re-entrancy gate 丟棄的 `_mark`
      **不會**沿用上一次的 `markError`(現在 gate 在 `markError = null` **之前**觸發,
      所以一個從未被嘗試的動作會彈出上次的失敗)。
- [x] 1.2 (green) `_mark` 的 gate 移到清除 `markError` 之後(或在 gate 分支明確清掉)。
      **不改** `markDone`/`markSkipped` 的對外簽章。
      **已知取捨(design 記錄)**:修完後「被 gate 丟棄的 inline 完成/略過」變成完全靜默,
      與本 change 在 edit 路徑上的「不得靜默」相反 —— 可接受,因為 `marking` 期間所有列
      都已停用、UI 上不可達;這條測試是 controller 層的。
- [x] 1.3 (refactor) 純整理,**無行為改變**:
      - `test/app_test.dart` 的跨午夜 flake:**保留那條整合測試**(它不只驗跨午夜 ——
        還走完 health tile → 更多 → care-items → care-history 的路由、驗
        `dataRevision.revision == 1`、pageBack 兩次回趨勢分頁、確認卡片吃到修正後的資料
        且保有自己的 30 天期間,是**唯一**的跨模組覆蓋,不能換掉)。
        **另加**一條 pin clock 的 `CareHistoryScreen` 隔離測試涵蓋 `editable` 判定。
        那條整合測試的 1s/86400 視窗**接受**(在「不動 `app.dart`」的前提下修不掉:
        `isToday` 用的是未注入的 `DateTime.now`;`app.dart` 另有兩處同類未注入時鐘,
        只為這一條開口子會讓慣例更亂)。
      - `health_scaffold.dart` 的 `_scheduleLoad` 註解(12 → 13 個 controller,且該註解
        描述的合流不變式已不涵蓋卡片自己的 `setSpan` 驅動)。
      - `care_history_controller.dart` 的 `setSpan(String idToken, int days)` 參數改名
        (現在遮蔽 controller 自己的 `days` 欄位)。
      - `health_scaffold_test.dart` 401 測試的敘述與 fixture 對齊(敘述說渲染 heatmap,
        但 fixture 是空 slots → 實際是空狀態),並把 1 天 fixture 換成有代表性的。
      - `care_history_screen_test.dart` 的 error 態測試補斷言 **AppBar**(標題 +
        `care-history-menu`)留存 —— 那是同一次重構的另一半。
      - `app_test.dart` 的 `_MutableCareHistoryRepository.editSlot` 改成**保留**被編輯
        slot 的識別欄位(比照 `care_history_screen_test.dart` 的 `_withStatus`);
        現在用寫死模板,加第二個 slot 就會靜默改寫。
      - 過期的 ARB `description`:`careHistoryAdherenceRateLabel` /
        `careHistoryDaysWithDoseLabel` / `careHistoryMissedCountLabel` /
        `careHistoryLegend*` 仍寫「in the care history chart mode」(該畫面已刪除);
        `careHistoryEmptyTitle` / `careHistoryEmptyBody` 說「on the care history screen」
        但現在也被卡片的空狀態共用。

## 2. B 組:heatmap 可讀性(單檔 `care_adherence_card.dart`)

- [x] 2.1 (red) `care_adherence_card_test.dart`:heatmap **每列恰好 7 格**;
      **單格邊長 ≤ 24dp**(見 design D2:未 cap 時 7 欄在 600dp 卡片內約 71.1dp、
      90 天高約 961dp);grid **靠左對齊**不拉伸;格數仍 = 期間天數;
      **有星期表頭**(七欄各自的星期縮寫);grid 下方有**起訖日期** caption;
      **今天那格**與其他格可區分。
      **測試環境注意**:`_pumpCard` 的 surface 是 800×1600 且**沒有** 600dp 的
      `ConstrainedBox`,卡片實寬 800(內寬 756,未 cap 時每格約 105dp)—— 斷言照這個環境寫。
      **星期表頭與 caption 的資料來源只能是 `sortedDays.first/last.date`**
      (卡片沒有 clock,也拿不到 `dayRangeEndingOn` 的 from/to;前提是後端 `days` 為 dense)。
      **同一步**更新既有對 grid delegate / 欄數的斷言。
- [x] 2.2 (green) 換 `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7)`;
      用 `LayoutBuilder` 算 `min(24, (maxWidth - spacing*6) / 7)`,把 grid 包進
      `Align(centerLeft)` + `SizedBox(width: 格寬*7 + spacing*6)`;加星期表頭與起訖 caption;
      今天格用**與既有每格描邊區分得出來**的描邊(顏色或寬度,別讓兩者混淆)。
      新 ARB key(起訖日期 caption)在這一步加齊。

## 3. A 組:無障礙

- [x] 3.1 (red) `care_adherence_card_test.dart`,**兩條斷言都要寫成有鑑別力的形式**:
      (a) **每格只被念一次**:`Tooltip` 設的是**同一個 merged node 上的
      `SemanticsProperties.tooltip`**(不是第二個節點 —— proposal/design 的措辭已修正),
      所以 red 要斷言 `tester.getSemantics(cell).tooltip` 為空、而 `.label` 仍是原文。
      **既有的** `find.byTooltip` + `find.bySemanticsLabel` 那條在 `excludeFromSemantics:
      true` 之後**兩條都還是綠的**,不會是這個 red。
      (b) **摘要在 grid 之前**:只 `find.bySemanticsLabel(摘要)` 不論放前放後都會綠 ——
      要斷言**順序**,例如
      `tester.getTopLeft(summary).dy < tester.getTopLeft(find.byKey(Key('care-adherence-heatmap'))).dy`。
      每格仍保有自己的 label。**注意** `explicitChildNodes` **不會**收掉子節點(design D1),
      別寫成「單一節點」的斷言 —— 那個測試寫不出來。
- [x] 3.2 (green) `Tooltip(excludeFromSemantics: true, ...)`;在 grid **前面**加摘要節點。
      新 ARB key(摘要句)在這一步加齊。
- [x] 3.3 (red) `care_today_screen_test.dart` + `care_history_screen_test.dart`:
      兩處 edit affordance 有可讀的語意標籤;**兩處**編輯 sheet 都有可達的關閉控制項
      (今日照護與 `/care-history` 的 sheet **都**缺 `showDragHandle`)。
- [x] 3.4 (green) 兩處 edit icon 補 `semanticLabel`,用**新的動作詞 key**(「編輯」,
      不是 sheet 標題那種名詞);**兩處** `showModalBottomSheet` 都加
      `showDragHandle: true`(比照 `exercise_screen.dart` / `goal_card.dart`)。
      新 ARB key 在這一步加齊。

## 4. C 組:空狀態與錯誤態

- [x] 4.1 (red) `care_history_screen_test.dart`:空狀態在 **7/30 天**同時有「看更長期間」
      (主要)與「前往照護管理」(次要)**兩顆**;**90 天**只有後者,且文案是「還沒有任何
      照護項目」;widen 按鈕在**自己的重載進行中**停用(快速雙擊不跳兩級);
      **且文案/按鈕組合依「已結算」的期間決定** —— `setSpan` 是先寫 `spanDays` 再 await,
      所以整個網路往返期間不能就翻成 90 天的說法(那時結果還沒回來,說法可能是假的)。
      **同一步**更新既有斷言:`care_history_screen_test.dart` 現在斷言 7 天空狀態時
      `care-history-empty-manage-button` **findsNothing** —— 新的「7/30 兩顆」會讓它必紅。
- [x] 4.2 (green) `_EmptyState` **已經有** `onWiden` / `onOpenCareItems` 參數 ——
      真正新的只有三項:**兩顆同時顯示**(7/30 天)、**widen 在自己的重載中停用**、
      **文案依已結算的期間**(需要外露 `care_history_controller.dart` 的 `_daysSpanDays`,
      或在 reloading 期間凍結上一組)。新 ARB key 在這一步加齊。
- [x] 4.3 (red) `care_adherence_card_test.dart`:卡片空狀態有「前往照護管理」。
      **注意**:卡片**沒有**指向照護管理的 callback(只有 `onOpenHistory`),`_EmptyState`
      連 callback 參數都沒有 —— 要**新增**一個並從 `health_scaffold.dart` 的 `_TrendBody`
      往下傳(`HealthScaffold` 自己已有 `widget.onOpenCareItems`,但 `_TrendBody` 沒收)。
      別接到 `onOpenHistory`,那會直接違反這條 scenario。同時驗:卡片與紀錄頁的**錯誤文案都帶入期間天數**,
      且紀錄頁的錯誤字用 `colorScheme.error`(與卡片一致)。
- [x] 4.4 (green) 兩處實作。錯誤文案用**帶數字 placeholder** 的新 key
      (例 `careErrorForPeriod(days)`)—— **不要**把已在地化的 `trendRange7/30/90`
      按鈕文案塞進另一個句子(中英語序與量詞都不同,是典型的 i18n 脆弱點)。
- [x] 4.5 (red) `care_today_screen_test.dart`:編輯**失敗**時 SnackBar 有 retry,
      且**重按 retry 用原本選的狀態與時間重送**(不必重選);**被 gate 丟棄**時文案是
      「未套用」而非「發生問題」,同樣有 retry;**失敗時清單仍在**(既有保證,別弄丟)。
      **同一步**更新既有那條「被 gate 丟棄時顯示 `careErrorGeneric`」的斷言。
- [x] 4.6 (green) `_openEditSheet` 把使用者選定的 `(status, doneTime)` 留在手上,
      retry 直接重送同一組值(retry 要重新走 gate);丟棄與失敗用**不同**的 ARB key。
- [x] 4.7 (red) `care_history_screen_test.dart`:token 尚未解析時,點期間選擇器/widen
      **不會**送出請求(現在 `_idToken` 是 `''`,會送出無 bearer 的 GET → 假的 401 reauth;
      controller 是 main.dart 單例,第二次進入畫面時 `firstLoadSettled` 已為 true,
      所以選擇器與 widen 會立刻可見)。
- [x] 4.8 (green) token 未就緒時停用那些控制項(或延後到 `_load()` 解析完)。
- [x] 4.9 (red/green) malformed 解析(design D4):`localDate` 不可解析時 → 完成時間列
      **停用並顯示「—」**,送出**不帶 `doneTime`**(**不要**代一個日期 —— 那會把
      `done_time` 寫到錯誤的日子,比崩潰更難發現);`timeOfDay` 不可解析 → 只影響 picker
      初始值,退回固定預設。**六個同類路徑一起修**(見 design D4 的清單):
      `_doneInstantOn` 裡的(**每次選完時間**都會再跑)、`_EditSheet.build` 的、
      `care_today_screen.dart` 的 `parseDayString(controller.date)`、
      `care_history_screen.dart` 開 sheet 前、`_DayCard` 表頭、
      **`care_adherence_card.dart` 的 `parseDayString(day.date)`**(malformed 時整個
      趨勢分頁的 heatmap 會炸;B 組本來就要改這個檔)。

## 5. gate

- [x] 5.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠,
      **且 `TZ=UTC flutter test` 也全綠**(CI 是 UTC runner;本機 UTC+8 會遮掉時區相依的
      失敗 —— #93 就是這樣紅在 CI 上的)。`lib/l10n/generated/` 產物已提交。
