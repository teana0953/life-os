## Why

issue life-os#96「[PWA shortcuts] 支援 PWA 捷徑」:長按 app icon 就能直接進入
**食物字典 / 記錄血糖 / 記錄飲食 / 記錄血壓**,不必每次都從首頁點三四層進去。

這四個是使用者最高頻的入口,而目前最短路徑分別是:
食物字典 = 首頁 → 健康 → 記錄 → 飲食 → 字典(4 層);
血糖/血壓 = 首頁 → 健康 → 記錄 → 數值 → 捲到該區塊 → 新增(5 層 + 捲動)。

## What Changes

- **`web/manifest.json` 新增 `shortcuts`**(四個),每個帶 `name` / `short_name` / `url`。
- **血糖與血壓在同一個 `VitalsScreen` 裡**,所以兩個捷徑若都只開 `/health/vitals`
  會**完全一樣**。定案(使用者選擇):**直接新增一筆並聚焦輸入** —— 點捷徑的意圖就是
  要記一筆,這是最短路徑。
  - 用 query param 表達:`/health/vitals?add=glucose` 與 `?add=bp`。
    **不新增路由**,`:name` 那條已經涵蓋。
  - `VitalsScreen` 收一個新的可選參數(`autoAddSection`),在**載入完成**時
    (**不是**首次 build —— 見 design D2:畫面不自載,在 loading 時新增的那筆會被
    隨後完成的 load **整個覆蓋**)執行一次「新增」並聚焦。**只做一次**。
  - **要在 mount / listener / `didUpdateWidget` 三處各評估一次**:只掛 listener 的話,
    「PWA 已開著時點捷徑」(走 hashchange、資料早就載完)會**完全不觸發**;
    而 go_router 的 pageKey 是**路由樣板、不含 query**,所以
    `?add=glucose` → `?add=bp` 是**同一個 State**、`initState` 不會再跑,
    沒有 `didUpdateWidget` 那一處,**第二個捷徑完全不新增**(design D5)。
  - **旗標必須在呼叫新增之「前」設** —— 新增內含同步 `notifyListeners()`,
    否則會重入成**無限遞迴**。
  - 聚焦目標:血壓 → systolic;**血糖 → 數值欄,不是第一個的自由文字名稱欄**
    (design D2a)。全檔目前**沒有任何 `FocusNode`**,所以這不是現成的。
- **食物字典的 route 目前擋掉 URL 驅動的到達**(proposal-review 抓到,**原本以為零改動**):
  `dictionary` route 要求 `state.extra`,沒有就 `_Redirect(to: '/health/diet')` ——
  PWA 捷徑是純 URL 驅動,**會落在記錄飲食,四個捷徑有兩個進同一畫面**。
  要讓它在無 extra 時包一層 **wrapper**:**等 `todayController` 載完才建**畫面
  (冷啟動時直接取會拿到空 list,而 `FoodSearchScreen.mealNames` 是**建構時快照**、
  永久留著 → 加食物時 `nextSnackName` 一律回「點心」而**撞名**),
  並在 `initState` 補做 in-app 進場會做、URL 驅動不會做的
  `createMealController.start(null)` + `dictionaryController.clearSearch()`。
  既有測試明確斷言舊行為,會被打紅,已列進 tasks。
- **記錄飲食**直接指向既有路由 `/health/diet`,零 app 端改動。
- **`_trackerFor` 要能拿到 query** —— 它目前只收 `state.pathParameters['name']`。

## WebAPK 的 URL 保留 —— **使用者已驗證可行**

原本這是本 change 最大的未知(見下),但**使用者回報這個做法已經實機驗證過可行**,
所以實機驗證改列為交付後的最終確認(tasks 6),不再是前置關卡。以下保留背景。

## 背景:為什麼這曾經是個未知

`#89` 的**實機驗證**留下這個結論(其 design.md):

> 真冷啟動 → 停首頁,PWA 內「複製連結」得到 `.../`,**連 `#/` 都沒有**
> → WebAPK 冷啟動時用 `start_url`(manifest 為 `.`)啟動,fragment 遺失。

而它的「不做」清單寫:**「如果 WebAPK 是整個 URL 換成 `start_url`,改成 path strategy
也沒用」**。

PWA shortcuts 走的正是冷啟動。**差別**在於 shortcut 的 `url` 是 manifest **自己宣告**的
(launcher 直接帶它啟動),而 #89 遇到的是 service worker `openWindow` 從**外部**觸發 ——
機制不同,規範上 shortcut 的 url 應該被尊重。**但這是假設,不是事實。**

**實機確認仍要做**(tasks 6),但作為最終確認而非前置關卡。

**有一個會製造假陰性的陷阱**:WebAPK 的 shortcuts 是**安裝/更新時烘進 APK** 的,
Chrome 約**一天**才檢查一次 manifest 更新。只重新整理或重開 app,長按 icon **不會**
出現新捷徑 —— 沒先重新安裝就下結論,「捷徑沒出現」會被誤判成平台限制而錯誤收工。

**若實際上仍失敗** → 桌機/瀏覽器分頁仍可用,Android PWA 上無效;退路不是改 URL 形式
(#89 已證明 fragment / path 都救不了),而是**接受平台限制**並記錄。

## Impact

- Affected specs: `pwa-shortcuts`(ADDED,新 capability)
- Affected code: `web/manifest.json`、`lib/app.dart`(`_trackerFor` 接 query
  **+ `dictionary` route 在無 extra 時自建參數**)、
  `lib/contexts/vitals/presentation/vitals_screen.dart`(`autoAddSection` + 聚焦)
- Affected tests:`test/app_test.dart` 那條「URL 驅動的字典會 redirect 回飲食日」
  **會被打紅**(預期相反了),要一起改寫
- **不動**:URL strategy(維持 go_router 預設 hash —— #89 已論證改了對 WebAPK 沒用);
  既有路由結構;`start_url`。
- **i18n 限制**:manifest **不走 ARB**,而且 W3C manifest 沒有多語言欄位(要多語系得
  各語言一份 manifest + `lang`)。捷徑名稱用**繁體中文**(使用者的實際語言),
  這是刻意的取捨,寫進 design。
