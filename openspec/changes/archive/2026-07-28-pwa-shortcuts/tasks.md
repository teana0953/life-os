> **hash 之後的 query 解析已確認成立**(review 查證 Flutter SDK 的 `HashUrlStrategy.getPath()`
> 回傳含 query 的整段 + go_router 16.3.0 當 `Uri` 解析),所以**沒有**「編進 path」的退路。
> **WebAPK 保留 shortcut URL 也已由使用者實機驗證過**,所以實機驗證(第 5 節)是交付後的
> 最終確認,不是前置關卡。
>
> **落地順序刻意是 1 → 2 → 3 → 4**:先 manifest(最便宜)、再字典可達(獨立)、
> 再 VitalsScreen(最貴,且 4 的 router 接線依賴它的參數存在)。

## 1. manifest

- [x] 1.1 `web/manifest.json` 加四個 shortcuts,照 design D3 的表(繁中 name/short_name)。
      **不加自訂圖示**(D4)。

## 2. 食物字典的 route 要能被 URL 驅動

- [x] 2.1 (red) `test/app_test.dart`:**改寫**既有那條
      「a URL-driven food dictionary route with no extra redirects back to the diet day」
      —— 預期相反了:URL 驅動到 `/health/diet/dictionary` **應該開字典**
      (`food-search-field` findsOneWidget)。同一步再加三條:
      - `todayController` 還在載入時抵達 → 等載完才建畫面,`mealNames` 是**載入後**的值;
      - `todayController` 是 **error / needsReauth** → 顯示錯誤/重新登入出口,
        **不是永遠轉圈**(D7);
      - **停在過去日**時抵達(`dayMealsLog.day != _today`)→ wrapper **自己觸發重載**,
        最終取到**今天**的 mealNames(**不是**卡在 loading —— 沒有別人會觸發那次重載);
      - **從字典返回**飲食日 → 看得到剛加的那筆(wrapper 在 `dispose` 重載);
      - **app 已開著**時點字典捷徑 → 不會把上一個未完成的 tray／目標餐別帶進字典(D7)。
- [x] 2.2 (green) `lib/app.dart` 的 `dictionary` route:無 `extra` 時包一層 **wrapper widget**
      (design D2b/D7):
      - **等 `todayController` 載完才建** `FoodSearchScreen`(`FoodSearchScreen.mealNames`
        是**建構時快照**、route builder 不會因之後的 notify 而重建,冷啟動直接取會拿到
        空 list 並**永久**留著 → 加食物時 `nextSnackName` 一律回「點心」而**撞名**);
      - **檢查 `dayMealsLog?.day == _today`**,不符就**自己呼叫
        `todayController.load(_idToken, _today)`**(用旗標避免與進行中的 load 重入)——
        **不能只是「等重載」**,沒有別人會觸發它;
      - **error / needsReauth 要有出口**,不可只有 loading/loaded;
      - `initState` 補做 `createMealController.start(null)` + `dictionaryController.clearSearch()`
        (**`start()` 內含 `notifyListeners()`,不能在 route builder 裡呼叫** —— build 期間
        notify 會炸);
      - **在 `dispose()` 觸發一次 `todayController` 重載**(in-app 是 `await push<bool>`
        拿 `true` 才 reload,`go` 沒人接 → 從字典加完食物返回會看到舊資料,而那是捷徑的
        主路徑)。**用 `dispose` 不用 `PopScope`**:後者在 guard 測試的 `go` 換頁下不觸發
        (見 D7 的取捨)。
      - `food-search`(帶 meal 的那條)**不動**。

## 3. VitalsScreen:載入完成後新增一筆並聚焦(**最貴的一段,排在 router 接線之前**)

- [x] 3.1 (red) `test/contexts/vitals/presentation/vitals_screen_test.dart`
      (**一律 `setSurfaceSize(Size(800, 1600))` + `addTearDown` 還原**,比照既有 vitals 測試):
      - `autoAddSection: 'glucose'` → **load 完成後**血糖清單多一筆空白;
      - **★ 順序**:先 loading、之後 load 完成 → 那筆**仍在**(在 loading 時新增會被
        `_applyRecord` 覆蓋掉);
      - **★ 已 loaded 才抵達也要新增**(PWA 已開著時點捷徑,只掛 listener 永遠不觸發);
      - **★ 換 section**:`?add=glucose` → `?add=bp` 兩次導航(**同一個 State**,因為
        go_router 的 pageKey 是路由樣板、不含 query)→ 第二次**要新增血壓**、
        且血糖那筆**不重複**(D5:`didUpdateWidget` 重置旗標**並立即再評估一次** ——
        只重置等於什麼都沒做,因為此時 controller 已 loaded、不會再 notify);
      - **連點同一個捷徑**(新舊 section 相同)→ **不再新增**(避免空白列堆積);
      - **★ 不會重入**:`addXxxReading` 內含同步 `notifyListeners()`,旗標若在 add 之後
        才設會**無限遞迴**;斷言新增後筆數**恰為 1**;
      - `autoAddSection: 'bp'` → 血壓同理;**不給** → 完全不新增(既有行為不變);
      - **未知的 section 值** → 不新增、不拋;
      - **聚焦**:glucose → `vitals-glucose-value-$index`(**不是** label 欄)、
        bp → `vitals-bp-systolic-$index`。**斷言 `FocusNode.hasFocus`**,
        **不要**斷言「捲進可視範圍」(高螢幕下驗不到東西,見 D6)。
- [x] 3.2 (green) `VitalsScreen` 加可選 `autoAddSection`。條件是「status 到達 `loaded`
      且 `day != null`」,**三處各評估一次**(D2 + D5):**mount**(已 loaded 就直接消費)、
      **`_onControllerChanged`**(掛載時還在 loading 那條)、**`didUpdateWidget`**
      (`autoAddSection` 變了就重置旗標)。`error`/`needsReauth` 不新增。
      **旗標必須在呼叫 `addXxxReading` 之「前」設**。
      **`didUpdateWidget` 那一處要「重置旗標 + 立即再評估一次」**,不能只重置。
      新增後在 `addPostFrameCallback` 裡對該列的 `FocusNode` `requestFocus` +
      `Scrollable.ensureVisible`(D6);**回呼開頭先擋**
      `if (!mounted || key.currentContext == null) return;`。
      新列的 `GlobalKey` 用 **`KeyedSubtree`** 包在 `_glucoseRow`/`_bpRow` 的回傳值外層 ——
      **不必**動私有的 `_ReadingListSection` 或它的 `rowBuilder` 簽章。
      欄位要新增 `focusNode` 參數(**全檔目前沒有任何 `FocusNode`**)。

## 4. router 把 query 接上去(**依賴 3.2 的參數已存在**)

- [x] 4.1 (red) `test/app_test.dart`:導航到 `/health/vitals?add=glucose` → 血糖多一筆。
      (**誠實標註**:這是行為測試,不是 hash 策略的證明 —— widget test 裡沒有 web 的
      URL strategy;hash 那一半由 SDK 原始碼佐證,見檔頭。)
- [x] 4.2 (green) `:name` route builder 把 `state.uri.queryParameters` 傳給 `_trackerFor`,
      再傳給 `VitalsScreen`。波及面已確認只有兩處:`_trackerFor` 的唯一呼叫點、
      `VitalsScreen` 的唯一建構點。
- [x] 4.3 (red/green) manifest guard —— **不要只做字串比對**(擋不住第 2 節那種
      「路由存在、但因為缺 extra 而 redirect 走」的失效模式)。讀 `web/manifest.json`
      (`File(...).readAsStringSync()`,既有先例 `test/shared/pwa/push_sw_handover_contract_test.dart`),
      對每個 shortcut 的 url **去掉 `/#` 前綴**,用既有的 `pumpApp` + `GoRouter.of(...).go(...)`
      實際導航,斷言**真的停在預期畫面**。血糖/血壓那兩次**還要各加一條筆數斷言**
      (glucose +1、bp +1)—— 只斷言「停在 VitalsScreen」的話,兩者都停在同一個畫面,
      **抓不到 D5**。
      **`setSurfaceSize(Size(800, 1600))`**;四條共用同一個 `pumpApp`
      (那正好會走到 3.2 的「已 loaded 才抵達」與 D5 的「換 section」兩條路徑)。
      **注意取 router 的方式**:既有測試用 `find.byKey(Key('health-tile'))` 的 element
      取 `GoRouter`,但第一次導航後那個 tile 就不在樹上了 —— **先取一次 `GoRouter` 實例
      重複使用**(整個 `pumpApp` 生命週期是同一個)。

## 5. gate

- [x] 5.1 `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠,
      **且 `TZ=UTC flutter test` 也全綠**。

## 6. 實機確認(**使用者做**,交付後的最終確認)

- [ ] 6.1 **先重新安裝 PWA**(移除再裝)—— WebAPK 的 shortcuts 是**安裝/更新時烘進 APK**
      的,Chrome 約**一天**才檢查一次 manifest 更新。只重新整理或重開 app,長按 icon
      **不會**出現新捷徑;沒做這步,「捷徑沒出現」很容易被誤判成平台限制。
- [ ] 6.2 四個捷徑各點一次:字典/飲食到得了目的地;血糖/血壓**各自**自動新增對應的一筆,
      **而且那一筆自己出現在畫面上、不用手動捲**(捲動只在這裡確認,見 D6)。
