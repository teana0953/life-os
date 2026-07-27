# 照護 follow-up 收尾(A/B/C/E 組)— 設計

日期:2026-07-27
兩軸:`flow_profile = full`、`needs_uiux = true`。
(v2:依 proposal-review 修正四個技術上站不住的決策,並把 D 組拆成獨立 change。)

## 範圍

使用者要求四組全做。**D 組(導覽堆疊)拆成獨立 change** —— 它是唯一牽涉 GoRouter
堆疊語意的一組,風險性質與其他三組完全不同,而且原本的規則有錯(見下方「拆出去的 D 組」)。
本 change 做 **A(無障礙)/ B(heatmap 可讀性)/ C(空狀態與錯誤態)/ E(技術債)**。

## Decisions

### D1. 無障礙容器:保留每格 label,摘要放在**前面**(不收子節點)

**選項**:(a) 容器只提供摘要、每格保留自己的 label;(b) `excludeSemantics: true` 真的收成
一個節點,單日資訊只剩長按 tooltip。

**選擇 (a)**。**理由**:原本寫的
`Semantics(container: true, explicitChildNodes: true, label: …)` **達不到**「單一節點」——
`explicitChildNodes` 的語意正是「讓子節點各自保留 SemanticsNode」。`TrendCard` 那段之所以
看起來像單一節點,是因為它包的是 **fl_chart 的 Stack,本身不產生任何語意**;搬到每格都有
`Semantics(label:)` 的 GridView 上,結果是 1 個容器 + 仍然 90 個子節點,**反而多一次**。

真要收成一個節點就得 `excludeSemantics: true`,但那會拿掉「每格可讀」——
那是上一個 change 為了「色彩不是唯一訊號」才加的,不能為了滑動次數把它換掉。

**做法**:在 grid **之前**放一個承載摘要的 `Semantics` 節點(標題 + 各狀態天數),
讓 SR 使用者先聽到全貌再決定要不要逐格走。spec 措辭同步從「不必逐格走過」改成
「**先**聽到一行摘要」。

### D2. heatmap:固定 7 欄,但**格子要有尺寸上限**

**問題**:直接換 `SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7)` 會失控。
算式(`LedgeCard` 是 `Container(padding: 20, border: 2)`,**border 會加進 padding**):
`_TrendBody` maxWidth 600 → ListView padding 20×2 → 卡片 (20+2)×2 → heatmap 可用寬
**516dp**;7 欄、spacing 3、預設 `childAspectRatio: 1.0` → 每格 **(516−18)/7 ≈ 71.1dp**,
90 天 13 列 → **約 961dp 高**。
現況 `maxCrossAxisExtent: 26` 是 `ceil(516/29) = 18` 欄、每格 **(516−17×3)/18 ≈ 25.8dp**,
90 天 5 列 → **約 141dp**。也就是**差約 6.8 倍**。
外層是 ListView 所以不會 overflow、測試也不會紅,但趨勢分頁第二屏會變成一整片巨大方塊。

**決定**:7 欄 + **單格上限 24dp**,超過時 grid **靠左對齊**(不拉伸)。
做法:`LayoutBuilder` 算 `min(24, (maxWidth − spacing×6) / 7)`,grid 包在
`Align(alignment: Alignment.centerLeft)` + `SizedBox(width: 格寬×7 + spacing×6)` 裡。

**高度的取捨(明說)**:7 欄必然是 13 列(90 天),所以**高度變高是這個選擇的固有代價** ——
capped 到 24dp 後 90 天 = 13×24 + 12×3 = **348dp**(現況約 141dp,約 2.5 倍)。
「7 欄可讀星期」與「緊湊」在數學上互斥(要回到 141dp 得把格子縮到約 8dp,那就看不見了)。
使用者選了「heatmap 可讀性」這一組,所以接受這個代價;24dp 是在「手機上看得清楚」與
「不要吃掉大半個螢幕」之間取的值(32dp 會是 452dp,3.2 倍,判定過高)。
**注意 360dp 手機也會吃到上限**:(360−40−44−18)/7 ≈ 36.9 > 24,所以兩種尺寸都會靠左對齊。
heatmap 不做點格互動(不做點格跳日),所以 48dp 的觸控目標下限不適用。

tasks 的 red 測試要**同時鎖住「7 欄」與「單格 ≤ 24dp」**,否則寬螢幕的退化沒有守門員。
**注意測試環境**:`care_adherence_card_test.dart` 的 `_pumpCard` 設 surface 800×1600
且**沒有** 600dp 的 `ConstrainedBox`,所以卡片實寬 800(內寬 756,未 cap 時每格約 105dp)
—— 斷言要照這個環境寫,不要照 600dp 的算式寫。

### D3. heatmap:不補前導空格,改加**星期表頭**

**問題**:原本 spec 寫「a row is a week」,但期間是 `dayRangeEndingOn` 算出的**任意起始
星期**的連續 N 天,而 tasks 又訂「格數仍 = 期間天數」。沒有前導補格,每列只是「連續 7 天」,
不是日曆週 —— 使用者仍讀不出星期幾,而那正是 follow-up 要修的可定位性。

**選項**:(a) 補前導空格對齊週首 + 星期表頭(格數不再等於天數);(b) 保留連續 7 天。

**選擇 (b) + 加星期表頭**。**理由**:每列剛好 7 天,所以**同一欄必然是同一個星期幾**
(只是不從週一/週日起算)。加一行依起始日推算的星期縮寫表頭,就能讀出星期幾,
而且格數仍 = 天數(不必處理補格的空洞語意)。spec 措辭改成
「每列七天、**同一欄固定同一星期幾**」,不宣稱 "a row is a week"。

**資料來源**:`CareAdherenceCard` **沒有** clock,也拿不到 `dayRangeEndingOn` 的 from/to
(那是 `CareHistoryController._fetchCurrentSpan` 內部算的),所以星期表頭與起訖 caption
都只能用 **`sortedDays.first.date` / `.last.date`**。這成立的前提是後端 `days` 是
**dense** 陣列(每個日期都有一筆,無排程時 `items: []`)—— 那是既有契約,程式碼裡已有註解;
若哪天變 sparse,欄位與表頭會**靜默錯位**。

### D4. malformed `localDate`:**不送 `doneTime`**,而不是代一個日期

**問題**:原本只寫「fallback 而非 throw」,沒說**送什麼**。`localDate` 無法解析時,
`_doneInstantOn` 沒有任何合理的日期可用 —— 隨便代一個等於把 `done_time` 寫到**錯誤的
日子**上,比崩潰更難發現。

**決定**:`localDate` 不可解析時,編輯 sheet 的**完成時間列停用並顯示「—」**,
送出時**不帶 `doneTime`**(讓後端維持原值,backend#53 的「未指定 = 不要動」正好是對的語意)。
`timeOfDay` 不可解析則只影響 picker 的初始值,退回一個固定預設即可。

**同類路徑要一起修 —— 共六處**(`grep parseDayString lib/`,吃後端資料的全部):
1. `care_today_screen.dart` `_doneInstantOn` 裡的(**每次選完時間**都會再跑一次)
2. `care_today_screen.dart` `_EditSheet.build` 的 `mediumDateLabel(parseDayString(...))`
3. `care_today_screen.dart` 的 `mediumDateLabel(parseDayString(controller.date))`
   (`controller.date` 來自後端)
4. `care_history_screen.dart` 開 sheet 前
5. `care_history_screen.dart` `_DayCard` 表頭
6. **`care_adherence_card.dart` 的 `mediumDateLabel(parseDayString(day.date))`** ——
   吃的正是與 5 同一份後端 `CareHistoryDay.date`,malformed 時整個趨勢分頁的 heatmap 會炸;
   B 組本來就要改這個檔。

## 拆出去的 D 組(導覽堆疊)—— 另開 change

原本的規則「目的地已在自己下方就 `pop()`」**有錯**,有 4 步可達的反例:
`/health` → push `/care-today` → push `/care-history` → ⋮ 照護管理(不在下方)→
`pushReplacement` → `[/health, care-today, care-items]` → 紀錄鍵 push `/care-history` →
此時 ⋮ 選「今日照護」,`/care-today` **確實在下方**(index 1)→ 依字面規則 `pop()` →
實際落在 `care-items`,不是使用者以為的今日照護。

正確規則是「**緊鄰**自己下方才 `pop()`」,而且還有兩個要自覺的副作用:
`pushReplacement` 會吃掉 care-history 那一頁;從推播/網址**深連結**直接進 `/care-history`
時堆疊只有一頁,`pushReplacement` 後就沒有任何返回目標(現況的 `push` 至少留得住)。
`RouteMatchList.matches` 對**巢狀**路由是一段多筆、不是一頁一筆,判斷要比對 location。

這些足以自成一個 change,不混進這批。

## 不動(維持既有判定 + 本次明確不收)

- 不抽 AppBar「紀錄」入口的共用 widget(仍 2 份);不動 `TrendController`/`TrendCard`;
  heatmap 不做點格跳日;跨午夜的 `_doneInstantOn` 語意;`parseInstant` 的 offset 驗證;
  「昨天漏的藥過午夜無法補登」(issue #90 明確要求的行為)。
- **趨勢分頁不做 route-addressable**(要把 tab index 變成 route/query param,是架構改動)。
- **heatmap 配色不重調到 WCAG 3:1**:#91 統一了 swatch 來源(`_LegendDot` 改吃
  `_dayStateColor`),但**對比本身沒解決** —— 門檻仍訂在 1.3:1(light 主題 partial 對卡面
  2.617、最差配對 1.380)。重調整條 ramp 會動到五個狀態的視覺關係,值得單獨評估。
- **兩張卡的期間選擇器外觀相同**(視覺層級,屬第五組,使用者未選)。
- 以下明確不收,留待後續:`care_adherence_card` 缺 `didUpdateWidget`(目前不可達);
  `_openEditSheet` 第一道 gate 的靜默 return(列已停用,實務不可達);
  `intl NumberFormat` 與裸 `'—'`(搬移前就存在);選「略過」時停用的時間列仍顯示具體時間;
  sheet 標頭時間與完成時間列打架;`marking` 停用範圍比 spec 寬;`_DayCard.isToday`
  跨午夜不刷新;reauth 出口與「saved 不彈 SnackBar」的覆蓋缺口;`isScrollControlled`
  沒被單獨鎖住。
- **`_idToken` 空字串**(`care_history_screen.dart` 在 `initState` 的 `_load()` 解析前):
  **本次收進 C 組**(它屬「錯誤態」——會送出無 bearer 的 GET → 假的 401 reauth,
  而 widen 與常駐選擇器增加了兩個觸發面)。

## 落地順序(每組結束都要 analyze + test 全綠,才是一個 checkpoint)

**E(無行為改變,最小風險)→ B(單檔 heatmap)→ A(兩檔語意)→ C(狀態機與文案)**。
