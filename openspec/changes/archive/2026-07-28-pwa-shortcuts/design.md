# PWA 捷徑(issue #96)— 設計

日期:2026-07-28
兩軸:`flow_profile = full`(新增使用者可見入口 + app 端行為)、`needs_uiux = true`
(捷徑命名、自動新增的互動)。

## Decisions

### D1. 血糖/血壓用 **query param**,不新增路由

`/health/vitals?add=glucose` / `?add=bp`。`:name` 那條路由已經涵蓋 `/health/vitals`,
只是 `_trackerFor` 目前沒接 query。新增路由(`/health/vitals/glucose`)會讓 `:name`
的通則破例,而 query 正是「同一個畫面的一個修飾」這種語意。

### D2. 自動新增的時機是「**首次載入完成**」,不是「首次 build」

**proposal-review 抓到的關鍵錯誤**:原本寫「首次 build 後執行一次」——**那筆會被洗掉**。
`VitalsScreen` **不自載**(`tracker_day_nav.dart` 的註解明寫 "The screen doesn't
self-load on mount (the scaffold pre-loaded today)"),資料由 `HealthScaffold._load`
非同步載入。冷啟動走捷徑時 `/health` 與 `/health/vitals` 同一幀建起,首次 build 時
`controller.day == null`、status 還是 loading、畫面其實是 spinner;此時新增的那筆,
會在 load 完成時被 `VitalsController._applyRecord` **整個覆蓋**掉。

**定案**:觸發條件是**「status 到達 `loaded` 且 `day != null`」**,而且**要在兩個地方
各評估一次**:

- **mount 時**(`initState` / `didChangeDependencies`):看到**已經** loaded 就直接消費。
- **`_onControllerChanged` listener**:只負責「掛載時還在 loading」那條路徑。

**只掛 listener 是不夠的**(第 2 輪 review 抓到):listener 只在 controller **之後**
notify 時才跑,而 `HealthScaffold` 只在 `initState` 跑一次 `_scheduleLoad` ——
所以只要 `VitalsScreen` 掛載時 controller 已是 loaded,就**永遠不會再有通知,自動新增
完全不發生**。而且這**不是邊角**:PWA 已開著時再點捷徑,URL 只差 fragment →
瀏覽器不重載文件、走 hashchange → go_router 站內導航,`/health` 這層 page 相同、
`HealthScaffold` 的 State 被保留、資料早就載完。連點兩次捷徑、或先「食物字典」
再「記錄血糖」也都是這條路徑。

`error` / `needsReauth` 時不新增。

**⚠️ 旗標必須在呼叫新增之「前」設**:`addGlucoseReading` / `addBpReading` 在方法內
**同步**呼叫 `notifyListeners()`,會同步重入 `_onControllerChanged`。若旗標在 add
回傳後才設,條件仍成立 → **無限遞迴、堆疊爆掉**(不只是多新增一筆)。

**只做一次**:`State` 裡的「已消費」旗標(不是 widget 參數)。`build` 會因 setState /
旋轉 / 鍵盤而跑很多次,沒有旗標使用者會得到一堆空白紀錄。
**重新整理(web)**會重建整個 app、URL 仍帶 `?add=glucose` → 會再新增一筆;
這是可接受的:重新整理等於重新從捷徑進入,語意一致。

### D2a. 聚焦到**哪個**欄位(needs_uiux)

`vitals_screen.dart` **全檔沒有任何 `FocusNode`** —— 欄位是私有的 `_RowNumberField` /
`_RowTextField`,內部自持 `TextEditingController`。所以要新增 `focusNode` 參數或
條件式 `autofocus`,**不是現成的**。

聚焦目標(**血糖不是第一個欄位**):
| section | 聚焦的 key | 理由 |
|---|---|---|
| `bp` | `vitals-bp-systolic-$index` | 第一個欄位,就是要打的數字 |
| `glucose` | `vitals-glucose-value-$index` | **不是** `vitals-glucose-label-$index` —— 那是自由文字的名稱欄,而捷徑的意圖是記一個數字 |

血糖區塊在 `ListView` 中段,所以新列還要**捲進可視範圍**。

### D2b. 食物字典的 route 目前**擋掉 URL 驅動的到達**

`lib/app.dart` 的 `dictionary` route 要求 `state.extra` 是
`({String day, List<String> mealNames})`,否則 `return const _Redirect(to: '/health/diet')`。
PWA 捷徑是純 URL 驅動、**沒有 extra** → 會落在記錄飲食,**四個捷徑有兩個進同一畫面**。
既有測試 `test/app_test.dart` 的
「a URL-driven food dictionary route with no extra redirects back to the diet day」
明確斷言這個行為,修好一定打紅它。

**⚠️ 但「從 `healthTodayController` 取」在冷啟動時取到的是空 list**(第 2 輪 review 抓到):
`HealthScaffold._load` 是非同步的(先 await idToken 再 `Future.wait`),而 dictionary
這條巢狀子路由與 `/health` **同一幀**建起,此時 `todayController` 還沒載完 →
`mealNames` 是 `const <String>[]`。更糟的是 **`FoodSearchScreen.mealNames` 是建構時的
快照**(該檔註解明寫 "a snapshot taken by the caller at push time"),而 route builder
**不會**因為 todayController 之後 notify 而重建 —— 那個空 list 會**永久**留在該畫面實例上。

後果落在捷徑的主路徑上:從字典加食物時 `_askForMeal` 用 `nextSnackName(mealNames, ...)`
命名點心,空 list → 一律回傳「點心」,當天若已有「點心／點心2」就會**撞名**
(而那個函式存在的理由正是避免這件事)。

**定案**:dictionary route 在無 extra 時,包一層 **wrapper widget**:
- **等 `todayController` 載完才建** `FoodSearchScreen`(loading 時顯示既有的載入狀態),
  這樣 `mealNames` 一定是正確的、而且只建一次。
- wrapper 的 `initState` 順便補做 **in-app 進場時會做、URL 驅動不會做的兩件事**:
  `createMealController.start(null)` 與 `dictionaryController.clearSearch()`
  (`diet_day_screen.dart` 的 `_openDictionary` 有做,註解說明是為了避免「被放棄的
  per-meal tray 洩漏進字典、讓字典開起來帶記錄控制項」)。冷啟動時 controller 是全新的
  還好,但 **app 已開著時點字典捷徑**(fragment-only 導航、同一份 controller)就會把
  上一個未完成的 tray／目標餐別帶進字典。
  **注意**:`start()` 內含 `notifyListeners()`,**不能在 route builder 裡直接呼叫**
  (build 期間 notify 會炸),必須放在 wrapper 的 `initState`。

**不是**「零 app 端改動」。

### D3. 捷徑名稱用**繁體中文**

manifest **不走 ARB**,而且 W3C manifest 沒有多語言欄位(要多語系得各語言一份 manifest
搭配 `lang`,對四個捷徑而言是過度工程)。使用者的實際語言是繁中,issue 也是中文寫的,
所以直接用繁中。既有 manifest 的 `lang` 是 `en`、`description` 也是英文 —— 那是
Flutter 樣板留下的,不在本 change 範圍。

`short_name` 要短(Android launcher 只顯示約 10 個字元):
| 捷徑 | `name` | `short_name` | `url` |
|---|---|---|---|
| 食物字典 | 食物字典 | 查食物 | `/#/health/diet/dictionary` |
| 記錄飲食 | 記錄飲食 | 記飲食 | `/#/health/diet` |
| 記錄血糖 | 記錄血糖 | 記血糖 | `/#/health/vitals?add=glucose` |
| 記錄血壓 | 記錄血壓 | 記血壓 | `/#/health/vitals?add=bp` |

**`short_name` 一律「動詞+名詞」三字**(uiux review):單看「飲食」分不出是記錄還是查詢,
而四個捷徑沒有自訂圖示、長按選單上圖示完全相同,語意平行才好一眼分辨。

**url 帶 `/#/`**:app 用 go_router 的預設 hash 策略(#89 已論證改 path strategy 對
WebAPK 沒用,不改)。

**hash 之後的 query 解析已確認成立**(proposal-review 查證,不是假設):
Flutter 的 `HashUrlStrategy.getPath()` 回傳 `#` 之後的**整段**字串、**含 query**;
go_router 16.3.0 直接把它當 `Uri` 解析成 `state.uri`,所以
`state.uri.queryParameters['add']` 拿得到。`lib/` 內也沒有任何 `usePathUrlStrategy`
呼叫,確實是預設 hash。**所以不需要「編進 path」的退路。**

### D4. 不做自訂捷徑圖示

manifest 的 `shortcuts[].icons` 是可選的;沒給就用 app icon。四個捷徑各畫一張 96×96
圖示是設計工作,不是這個 issue 要的東西(YAGNI)。

**❌ 這條被實機推翻(交付後,#105 修)**:`icons` 確實是可選的,但**沒給的話 Android
launcher 顯示的是空白灰方塊,不會 fallback 到 app icon**。四個捷徑並排三個空方塊,
只有文字可讀。已補四張 192×192(app 自己的 token 畫的不透明圓片 —— 選單是深色的,
透明字符會消失;整張內縮 12%,因為 launcher 可能裁成圓形)。

**❌ 另一個被實機推翻的假設**:原本寫「Android 最多顯示 4 個捷徑,再加也看不到」。
實際上 **Chrome 會自己插一列「網站設定」**,所以 WebAPK 的長按選單**只顯示前 3 個**。
第四個(記血壓)完全不出現。已把 manifest 順序改成
**記血糖 → 記飲食 → 查食物 → 記血壓**(使用者選的),血壓退到看不見的第四位 ——
它與血糖共用 vitals 畫面,進去往下捲就有。**順序因此是有意義的**,guard 測試已釘住前三個。

## WebAPK 會不會丟掉 shortcut 的 URL —— **使用者已驗證可行**

原本這是本 change 最大的未知(#89 證明 SW `openWindow` 給的 fragment 在 WebAPK 冷啟動
會遺失)。**使用者回報這個做法已經驗證過可行** —— shortcut 的 url 是 manifest 自己宣告、
由 launcher 以顯式 intent data 帶入,與 #89 那種由外部觸發的機制不同。

所以**不再把它當作前置關卡**,實機驗證留作交付後的最終確認(tasks 6)。
若實際上仍失敗,退路不是改 URL 形式(#89 已證明 fragment / path 都救不了),
而是接受平台限制並記錄。

## D5. 自動新增要在**三**處評估,不是兩處

第 3 輪 review 讀 go_router 16.3.0 原始碼發現:`pageKey` 是
`ValueKey(newMatchedPath)`,而 `newMatchedPath` 是**路由樣板**(`/health/:name`)——
**不含 query、也不含具體的 name**。

後果:`/health/vitals?add=glucose` → `/health/vitals?add=bp` 兩次導航產生**同 key 同型別**
的 `MaterialPage`,Navigator 判定 `canUpdate` → Route 被**更新**而非重建 →
`_VitalsScreenState` **不會再跑 `initState`**,而 State 裡的旗標仍是 `true` →
**第二個捷徑完全不新增**。這條路徑很實際:PWA 已開著、人正停在血糖畫面時點血壓捷徑。
它也會打爆 tasks 的 guard 測試(依序 go 四個 URL),而且紅的原因與 manifest 無關。

**定案**:第三處評估放 **`didUpdateWidget`** —— `oldWidget.autoAddSection !=
widget.autoAddSection` 時**重置旗標並「立即執行同一段評估」**
(loaded && day != null → 設旗標 → 新增 → 排 post-frame 聚焦)。

**⚠️ 只重置旗標是不夠的**(第 4 輪 review 抓到):此時 controller 已是 loaded、
**不會再 notify**,listener 永遠不會跑、`initState` 也不再跑 —— 只重置等於什麼都沒做,
`?add=glucose` → `?add=bp` 仍然完全不新增。

**同一個 section 重複抵達刻意不再新增**(連點兩次同一個捷徑):新舊值相同 → 不重置 →
不新增。這是為了避免空白列堆積,與驗收標準的「只發生一次」一致。
(D2 提到的「連點兩次捷徑」只是用來論證 listener 不會觸發,不是要求重複新增。)

(另兩個可行解:旗標改成記「已消費的 section 值」;或在 `_trackerFor` 給 `VitalsScreen`
加 `key: ValueKey('vitals-$add')` 強制重建。選 `didUpdateWidget` 是因為它不動 router、
也不改旗標語意。Flutter 3.35.4 的 Navigator 確認會在 Route 更新時呼叫它。)

## D6. 捲動機制要明確,而且 surface size 的說法要一致

第 3 輪 review 指出原本的敘述**自相矛盾**:一邊說捲動測試要用矮螢幕,一邊又說
「中段的血糖區塊在預設 800×600 下不會被 build」—— 若真的不 build,那
「條件式 `autofocus`」是作用在一個**不存在的 widget** 上,既不會聚焦也不會觸發捲動。

**定案**:
- 捲動**不靠** `autofocus` 的副作用,而是明確做:新增後 `WidgetsBinding.instance
  .addPostFrameCallback` → 對新列的 `GlobalKey` 呼叫 `Scrollable.ensureVisible`。
  **`GlobalKey` 放哪**:`_glucoseRow` / `_bpRow` 是 `_VitalsScreenState` 自己建的,
  回傳前包一層 `KeyedSubtree(key: _autoAddRowKey)` 即可 ——
  **不必**動私有的 `_ReadingListSection` 或它的 `rowBuilder` 簽章。
  **post-frame 要先擋**:`if (!mounted || key.currentContext == null) return;` ——
  從 listener 路徑新增時,若 notify 落在某一幀的 build 階段,新列要下一幀才建出來,
  當幀的 post-frame 取不到 context,`ensureVisible` 會拋。
- 聚焦同樣在那個 post-frame 回呼裡對該列的 `FocusNode` `requestFocus`。
- **測試一律用高螢幕**(`setSurfaceSize(Size(800, 1600))` + `addTearDown` 還原,
  比照既有的 vitals 測試)—— 讓區塊確實被 build。**不寫「捲進可視範圍」的斷言**
  (在高螢幕下驗不到東西);改成斷言 `ensureVisible` 的前提成立:新列存在、
  且它的 `FocusNode.hasFocus` 為 true。捲動本身是 Flutter 的行為,不重複測框架。

## D7. 字典 wrapper 的其餘三個決定

- **`error` / `needsReauth`**:`todayController` 有這兩態(load 失敗就會落在那裡)。
  wrapper **不可**只處理 loading/loaded —— 否則冷啟動時 meals 請求一失敗,字典捷徑會
  **永遠停在轉圈**。沿用 diet day 既有的錯誤 / 「請重新登入」出口。
- **`day` 與 mealNames 必須同一天**:`day` 用 `_today`,但 `todayController` 會被 diet
  畫面的日期切換重載成**被瀏覽的過去日**。app 已開著、使用者正在看昨天時點字典捷徑
  (同一份 controller)→ day=今天、mealNames=昨天 → `nextSnackName` 依昨天的名單命名
  今天的點心,又是撞名。
  **⚠️ 「不符就等重載」是錯的**(第 4 輪 review 抓到):`TodayController.load` 的呼叫點
  只有 `HealthScaffold._load` 與 diet 畫面的日期切換 —— **沒有人會觸發那次重載**,
  wrapper 會永遠轉圈,比現在的 redirect 還糟。
  **定案**:wrapper 在 `initState` / `didUpdateWidget` 發現 `dayMealsLog?.day != _today`
  時**自己呼叫** `todayController.load(_idToken, _today)`,並用旗標避免與進行中的 load 重入。
- **從字典返回要重載飲食日**:in-app 的 `_openDictionary` 是 `await context.push<bool>`,
  拿到 `true` 才 `_reloadCurrentDay()`;捷徑走 `go` 建整個 stack,`FoodSearchScreen`
  pop 出來的 `true` **沒有人接** → 從字典捷徑加完食物、返回 `/health/diet` 會看到
  **沒有那筆的舊資料**。而這正是捷徑的主路徑。
  **機制定案:用 `dispose()`**,不是 `PopScope`。取捨:`dispose` 會在任何拆除時觸發
  (`go` 換頁、登出、hot restart 都算)→ **可能多打一次 `load`**,那是無害的重載;
  而 `PopScope.onPopInvokedWithResult` 只在真的 pop 時觸發,**guard 測試用 `go` 換頁
  就測不到**。選 `dispose` 是為了「行為簡單且測得到」。
  **⚠️ 重載的是「借走前那一天」,不是無條件的今天**(QA 抓到):上一點讓 wrapper 把
  **共用的** `todayController` 從「使用者正在瀏覽的過去日」切成今天,但下方的
  `DietDayScreen` 有自己的 `_viewedDate`/`_day`,**只在它自己的日期切換時重載** ——
  沒有人會把它同步回來。無條件 `load(_today)` 的結果是**昨天的標題配今天的清單**,
  而且 `_openFoodSearch` 傳的 `day` 還是昨天 → **使用者對著「今天」的餐別新增,食物被
  記到昨天**。定案:wrapper 在**真正接管的那一刻**(`_ensureDayLoaded` 決定要切換時)
  記下 `dayMealsLog?.day`,`dispose` 載回那一天。
  **已知殘留(follow-up)**:那次還原是 async,load 在飛的期間畫面仍短暫不一致。要根治
  得讓 `DietDayScreen` 依 controller 的 day 重新同步自己的 `_viewedDate`/`_day`,
  那會改到既有畫面、且讓 diet day 的日期被別人牽著走,不在本 change 範圍。

## Review 留下的 follow-up(本 change 不做,理由附上)

- **`hasUnsavedChanges` 對「全空白」的列謊報髒狀態**(`vitals_controller.dart`):
  `save` 會用 `_isEmptyBp`/`_isEmptyGlucose` 把空白列濾掉,但 `hasUnsavedChanges` 是
  element-wise 比對 → 捷徑自動新增後,使用者一個字都沒打,「儲存」就亮起;真按下去那列
  被靜默濾掉、從畫面消失。**不在本 change 修**,因為它同樣改變**手動**按新增的既有行為
  (那可能是刻意的),不是本 change 引入的。
- **「記錄飲食」捷徑在 app 已開著且停在過去日時是無效的**:`/health/diet` 的 pageKey
  相同,`go` 不重建 page,`_DietDayScreenState` 的 `_viewedDate/_day` 只在 initState
  重置 → 使用者按了捷徑仍停在昨天。與 D7 末段「`DietDayScreen` 自我同步」是同一個根因,
  一起處理才划算。
- **自動新增 + 自動聚焦對螢幕閱讀器沒有任何預告**:全專案 0 個 `SemanticsService.announce`。
  焦點被丟進一個空編輯框,只聽得到「血糖值 編輯方塊」。需要新增 ARB 字串。
- **字典捷徑不顯示它記到哪一天**:`FoodSearchScreen` 的 AppBar 只有「食物字典」。從
  app 內進來記的是「正在瀏覽的那一天」,從捷徑進來記的是「今天」,使用者無從得知。
- **`dayMealsLog.day` 與 `DietDayScreen._day` 在「失敗的日期切換」後會永久差一天**
  (第 3 輪 review):`_setViewedDate` 先改 `_viewedDate/_day` 再 await load,load 失敗時
  `TodayController` 只改 status、不動 `dayMealsLog`。此後 `_returnDay` 取的
  `dayMealsLog.day` 就不等於畫面上的日期,還回去也還錯。**這與上面 D7 末段那條殘留是
  同一個根因**(`DietDayScreen` 不會自我同步),但那條只是還原 load 在飛的短暫空窗,
  這條是永久不一致。最小防禦是讓 `TodayScreen` 在 `dayMealsLog.day != widget.day` 時
  顯示載入中(字典 wrapper 自己就是這樣做的);根治仍是讓 `DietDayScreen` 自我同步。
- **`error` 態會擋住「資料其實已經在手上」的字典**(第 2 輪 review):`build` 的
  `case TodayStatus.error` 排在 `log.day == widget.day` 判斷之前,所以在今天的飲食日
  做了一個失敗的 mutation(`_mutate` 只改 status、不動 `dayMealsLog`)之後點字典捷徑,
  會看到「載入失敗」而不是字典 —— 雖然要用的餐別名單完整無缺。**不在本 change 改**,
  因為那是「錯誤狀態該不該讓使用者看見」的產品決策,不是單純的 bug。
- **`_autoAddKind`/`_autoAddIndex` 消費後沒有失效機制**:切換日期或移除前面的列會讓
  索引指向另一筆既有 reading。目前後果僅止於視覺/焦點怪異(不會重複新增),屬純防禦。

## 不做

- 改 URL strategy(#89 已論證)、動 `start_url`、動既有路由結構。
- 自訂捷徑圖示。
- manifest 多語系。
- 其他 tracker(水/運動/排便/生理期)的捷徑 —— issue 只要這四個;
  Android 最多顯示 4 個捷徑,再加也看不到。

## 驗收標準

1. `manifest.json` 有四個 shortcuts,名稱與 url 如 D3 的表。
2. `/health/vitals?add=glucose` 開啟時**自動新增一筆血糖**並聚焦**該捷徑對應的欄位**
   (見 D2a —— 血糖是**數值**欄,不是名稱欄);`?add=bp` 對血壓同理;
   **沒有 query 時完全不新增**(既有行為不變)。
   **controller 已載入完成才抵達**(PWA 已開著時點捷徑)**也要新增** —— 見 D2。
3. 自動新增**只發生一次** —— 之後的 setState / 重建不再新增;
   **連點兩次同一個捷徑也不再新增**(避免空白列堆積)。
3a. **在畫面上從一個 vitals 捷徑切到另一個**(`?add=glucose` → `?add=bp`)
   **要新增血壓**,且血糖那筆不重複新增(D5)。
4. `/health/diet` 直達(零 app 端改動)。
5. 血糖的新列聚焦在**數值**欄(不是名稱欄);血壓聚焦在 systolic。
   (**捲進可視範圍**由實機確認,不寫成自動化斷言 —— 見 D6。)
6. `/health/diet/dictionary` **URL 驅動也到得了**(不再 redirect 回飲食日),
   且 `mealNames` 是**載入後**的正確值(不是冷啟動當下的空 list)。
6a. 字典 wrapper 在 `todayController` **載入失敗**時有錯誤／重新登入出口(**不是永遠轉圈**)。
6b. app 停在**過去日**時點字典捷徑,仍取到**今天**的 mealNames(wrapper 自己觸發重載)。
6c. 從字典捷徑加完食物返回 `/health/diet`,**看得到剛加的那筆**(wrapper 在 dispose 重載)。
7. **實機**(見 tasks 5,**兩步**):先驗「記錄飲食」(URL 形式到不到得了)、
   再驗「記錄血糖」(**hash 之後的 query** 有沒有被吃掉)。兩條都過才算成立。
