# 設計:食物字典 admin 編輯介面(前端)

來源:[life-os#87](https://github.com/teana0953/life-os/issues/87)「[食物字典] admin 可以自由編輯」的**前端半**。後端半已上線(backend PR #59 + #60):

- `GET /api/me` 回 `is_admin`。
- `POST /api/admin/food-items` 建立共用品項(`owner_user_id = null`,所有人可見),201。
- `PATCH /api/admin/food-items/:id` 部分編輯共用品項,200;缺鍵=不動,`base_amount`/`measure_unit` 送 null=清空;空 patch 400;不存在/別人的自訂品項/格式錯 id → 404;非 admin → 403。

使用者已確認前端這輪做 **編輯 + 建立共用品項**兩件。

## 兩軸判定

- `flow_profile`: **full** — 使用者可見的新流程。
- `needs_uiux`: **true** — 新增畫面元素、表單、狀態呈現。

## 現況(實查)

- `FoodSearchScreen`(food_search_screen.dart,804 行)是字典的唯一入口,結果列是 `ListTile`(第 265-286 行):title=名稱、subtitle=`PortionPills`、trailing=收藏 `IconButton`、`onTap` 把品項加進餐點 tray。
- `FoodItem`(domain/food_item.dart)已有 `ownerUserId`,**共用品項 = `ownerUserId == null`**,前端拿得到,不必再問後端。
- `FoodDictionaryRepository` port 只有 `search`/`listFavorites`/`favorite`/`unfavorite`。**前端目前完全沒有建立字典品項的路徑** —— `POST /api/food-items` 從未被呼叫;「手動輸入」(`_ManualEntryDialog`)只是往 tray 塞一筆一次性的手打項目,不進字典。所以「建立共用品項」是全新表單,不是在既有表單加開關。
- `UserProfile`(contexts/user/domain/user_profile.dart)沒有 `isAdmin` 欄位。
- `HomeController.load(idToken)` 只在 `_AuthenticatedHome.initState` 被呼叫(app.dart:964-974),而那個 widget 只活在首頁路由;**深連結直接進 `/health/diet/dictionary`(PWA 捷徑 `web/manifest.json` 指的就是這條)不會載入 profile**。
- 字典有**三個**建構點:`food-search` 路由、帶 `extra` 的 `dictionary` 路由,以及無 `extra` 時的 `_UrlDictionaryScreen`(app.dart:939)—— 捷徑走最後這條。
- `test/` 現有八處 `FoodSearchScreen(...)` 建構(food_search_screen_test.dart 等),新增必填參數會全部編譯失敗。

## 決策

### D1 — `UserProfile.isAdmin`

`UserProfile` 加 `final bool isAdmin`,`fromJson` 讀 `json['is_admin'] as bool? ?? false`。**用 `?? false` 而不是必填**:後端雖已上線,但舊快取回應或未來回滾都可能少這個鍵,少一個鍵不該讓整個 profile 解析炸掉變成錯誤畫面。

### D2 — admin 狀態怎麼到達字典畫面:沿用 `HomeController`,由需要的畫面**惰性確保**已載入

不新增第二個 profile 控制器(會變成兩次 `/api/me`),也**不動**既有的認證/首頁流程(`_AuthenticatedHome.initState` 的 `load` 原樣保留 —— 它同時是 profile 載入失敗後唯一的重試路徑:離開首頁再回來會重掛、重載)。改為:

- `FoodSearchScreen` 多一個參數 `isAdmin`(純 bool,不是 controller)——畫面本身不該知道 profile 怎麼來的。**給預設值 `false`**,所以既有的八處建構與測試不受影響,且「不知道 = 不是 admin」是安全預設。
- `HomeController` 加 `ensureLoaded(idToken)`:已載入或載入中就不做事,否則跑一次 `load`。觸發點放在 **`FoodSearchScreen.initState`**(post-frame)而不是三個路由 builder —— 一處涵蓋三個入口。畫面本身仍不認識 `HomeController`:接的是 app.dart 傳下來的一個 `VoidCallback`。
- **觸發時機**:`WidgetsBinding.instance.addPostFrameCallback` 之後才呼叫。`HomeController.load` 在第一個 await 之前就同步 `notifyListeners()`(home_controller.dart:27-30),在 build 當下呼叫會踩到 app.dart 已經記載過兩次的「build 期間 notify」風險。
- **切換使用者的失效**:`HomeController` 是 `main.dart:117` 建的單例,加 `reset()`(清掉 profile)。觸發點是 app.dart:304 既有的 auth 監聽,判準是**登出**(`signedIn` 由 true 轉 false)而非「換了使用者」—— `AuthRouterNotifier`(auth_router_notifier.dart:16-34)只有 loading/error/signedIn/idToken,來源是 `Stream<bool>`,拿不到 uid,而登入另一個帳號必定先經過登出,守得住。沒有這條,admin 登出、換另一個帳號登入後,新使用者會沿用上一個人的 `isAdmin`,直接看到 ⋮ 與 +。
- **`ensureLoaded` 的判準是 `profile != null`,不是「呼叫過沒」**:首頁那次 load 失敗時 profile 仍為 null,之後進字典會再打一次 —— 這正是深連結進來的畫面唯一的重試機會。
- 路由把 `homeController.profile?.isAdmin ?? false` 傳下去,並以 `ListenableBuilder` 監聽,profile 落地時該畫面重建、入口才出現。

**三個進入點都要接**:`food-search` 路由、`dictionary` 路由(帶 `extra` 的),以及 `_UrlDictionaryScreen`(app.dart:939 自己建 `FoodSearchScreen` 的那條)—— PWA 捷徑走的正是最後這條(`web/manifest.json` 指向 `/#/health/diet/dictionary`),也就是這整個決策存在的理由。

取捨:profile 還在載入時,admin 看到的字典畫面**短暫沒有編輯入口**,載完才出現。可接受(不會誤讓非 admin 看到)。

### D3 — 編輯入口:結果列的 `PopupMenuButton`,只對 admin 且只對共用品項顯示

結果列的 trailing 目前是收藏鈕。改成:非 admin 或非共用品項時**完全維持現狀**(單一收藏 `IconButton`);admin 看共用品項時,收藏鈕旁多一個 `⋮` `PopupMenuButton`,選單只有一項「編輯」。

為何不是長按:長按沒有可見的可發現性,且與既有互動語彙不合(這個 app 其他清單的次要動作都是可見圖示)。為何不是直接放一個鉛筆 `IconButton`:結果列已有收藏鈕,兩個圖示會擠掉名稱寬度;`⋮` 之後要加「刪除」也有地方放。

`onTap`(把品項加進 tray)維持不變 —— 編輯是次要動作,不能取代主要動作。

### D4 — 表單:一個 bottom sheet,建立與編輯共用

`SharedFoodItemSheet`,`showModalBottomSheet` + `isScrollControlled: true`,**且內容要以 `MediaQuery.of(context).viewInsets.bottom` 加底部 padding** —— `isScrollControlled` 只讓 sheet 可以長高,不會自己把內容推到鍵盤上方;repo 既有的 sheet 都有這行 padding,漏掉等於沒解決本來要解決的問題。**不是 `AlertDialog`** —— 這個專案踩過:手機上 `AlertDialog` 配鍵盤會把內容擠掉/遮住,含文字輸入的表單一律用 bottom sheet(既有 `_PortionEditDialog` 之外的新表單照此)。

欄位:名稱、四項份數(主食/肉類/水果/蔬菜)、六項營養素(碳水/蛋白質/脂肪/糖/纖維/熱量)、量基準(`base_amount` + `measure_unit`)。數值輸入沿用專案慣例:**值為 0 時顯示空字串 + `hintText: '0'`**(見 CLAUDE.md「Numeric input empty-zero convention」)。

表單的送出狀態(送出中/失敗/型別化錯誤)由一個 `SharedFoodItemController`(`ChangeNotifier`)持有,兩個 use case 注入它,`main.dart` 建立、經由路由傳進 `FoodSearchScreen` 再給 sheet。sheet 本身不直接持有 use case —— 這與本專案「畫面驅動 controller、controller 呼叫 use case」的既有分層一致。

同一個 sheet 兩種模式:
- **建立**:全部空白,送出打 `POST /api/admin/food-items`。
- **編輯**:預填該品項現值,送出打 `PATCH /api/admin/food-items/:id`,**只送有改動的欄位**(對齊後端「缺鍵=不動」語意,也避免把沒碰的欄位覆寫成一樣的值)。

### D5 — 量基準的成對規則在前端就擋

後端要求 `base_amount` 與 `measure_unit` 同時有值或同時為空,違反回 400。前端在送出前就檢查,錯誤顯示在欄位旁、講清楚怎麼修(「數量與單位要一起填,或一起留空」),不要讓使用者靠後端 400 才知道。`base_amount` 也必須為正(後端 `> 0`)。

### D5b — 編輯模式下「什麼都沒改」不可送出

後端對空 patch 回 400。前端在編輯模式下,**沒有任何欄位與原值不同時,送出鍵維持停用**,使用者不會拿到一個看不懂的 400;要離開就按取消。

### D6 — 建立入口:字典畫面的 AppBar 動作

admin 在字典/搜尋畫面的 AppBar 多一個「新增共用品項」動作(`IconButton`,`Icons.add`);非 admin 完全看不到。放 AppBar 而不是列表底部:它與「當前搜尋結果」無關,是畫面層級的動作。

### D7 — 成功後重新整理

編輯成功後關閉 sheet、顯示 `SnackBar`,並重跑目前的搜尋(有查詢字串就重搜,否則重載收藏),讓改動立刻反映在列表。

**建立**要特別處理:查詢字串為空時畫面顯示的是**收藏清單**(food_search_screen.dart:299-300),而新建的共用品項不是任何人的收藏,重載收藏看不到它,使用者會以為沒建成功。所以建立成功後**把搜尋框設成新品項的名稱並跑一次搜尋**,新品項一定看得見。前置條件:搜尋框現在是沒有 controller 的裸 `TextField`(food_search_screen.dart:322-326),要先給它一個 `TextEditingController` 才設得動文字;且 `search` 有 300ms debounce(dictionary_controller.dart:76-106),測試要等它的 Future。**不做本地樂觀更新** —— 這是低頻的管理動作,一次重搜遠比維護一份本地副本簡單且不會不同步。

### D8 — repository/use case 分層

`FoodDictionaryRepository` port 加兩個方法:`createSharedItem(idToken, input)`、`updateSharedItem(idToken, id, patch)`;`HttpFoodDictionaryRepository` 實作,沿用既有 `_send`(401 → `DietReauthenticationRequired`)。404(不存在/格式錯/別人的自訂品項)沿用既有的 `DietNotFound`,不要為它再造一個型別。新增兩個 use case(`CreateSharedFoodItem`、`UpdateSharedFoodItem`)在 `application/`。403 要有自己的錯誤型別(不能與一般失敗混為一談):非 admin 打這兩個端點時,畫面要說「沒有權限」,不是「請再試一次」。

### D9 — 錯誤是**型別**不是文字

依 CLAUDE.md i18n 規則,infrastructure/domain 丟型別化錯誤,controller 存型別,畫面在 `build()` 才轉成 `AppLocalizations` 文案。新增的 ARB key 先寫進 `app_en.arb`(含 description)、`app_zh_Hant.arb`,**以及 `app_zh.arb`** —— 這個 repo 的 `app_zh.arb` 不是空殼,它與 `app_zh_Hant.arb` 內容一致(除 `@@locale` 外逐字相同),漏掉會讓 `flutter gen-l10n` 對缺鍵發警告、`zh` 落回英文。

### D10 — 已加進 tray 的項目不追改

tray 的每一列持有加入當下的 `FoodItem` 複本(create_meal_controller.dart:26-31),預覽與總計都從那份快照算。admin 編輯字典**不回頭改寫**已在 tray 裡的項目 —— 與後端「餐點記錄是寫入當下快照」的語意一致,也避免使用者手上的數字在編輯後無聲跳動。寫成可驗 scenario,避免日後被當成 bug。

## UI/UX 設計

### 使用者路徑

- **主路徑(編輯)**:admin 從飲食頁進食物搜尋(或 PWA 捷徑直接進字典)→ 搜到一個共用品項 → 點該列的 `⋮` → 選「編輯」→ bottom sheet 帶著現值開啟 → 改幾個欄位 → 送出 → sheet 關閉、SnackBar 告知成功、列表即時顯示新值。
- **主路徑(建立)**:admin 在同一畫面點 AppBar 的 `+` → 空白 bottom sheet → 填名稱與數值 → 送出 → SnackBar 告知成功、該品項出現在後續搜尋中。
- **例外路徑**:非 admin 看不到 `⋮` 也看不到 `+`(不是停用,是不存在);表單驗證失敗留在 sheet 內、錯誤在欄位旁;送出時 401 走既有的重新登入出口;403 在 sheet 內顯示「沒有權限」、內容保留。

### 介面與一致性

- 結果列維持 `ListTile` 形狀與 `PortionPills` subtitle;新增的 `⋮` 與既有收藏鈕並排在 trailing。
- bottom sheet 用專案既有的圓角/外框語彙,主要動作 `FilledButton`、次要 `OutlinedButton`(來自 theme,不自己刻)。
- 所有顏色/字級都走 `Theme.of(context)`,不寫死。
- 數值欄位遵守 0 顯示為空字串 + `hintText: '0'` 的專案慣例。

### 狀態設計

- **送出中**:主要按鈕變為不可按 + spinner,欄位維持可讀(不清空)。
- **驗證失敗**:錯誤文字出現在對應欄位下方,已填內容全部保留,sheet 不關。
- **送出失敗(網路/500)**:sheet 內顯示可重試的錯誤訊息,內容保留。
- **403**:sheet **維持開啟**、已填內容保留,顯示「沒有權限」訊息(與一般的「請再試一次」區分)。不在此時偷偷移除入口 —— 入口消失卻沒說原因比留著更難理解;真正的權限狀態下次 profile 重載時自然反映。
- **profile 尚未載入**:admin 入口暫時不顯示,不顯示骨架也不佔位 —— 出現得比較晚,但不會閃動一個沒用的按鈕。

### 可及性/理解性

- `⋮` 與 `+` 都有 `tooltip`/語意標籤(「編輯共用品項」「新增共用品項」),不是純圖示。
- 錯誤訊息一律可行動:講出哪個欄位、要怎麼改。
- 表單欄位有 label,不是只靠 placeholder。

## 不做

- 刪除共用品項(後端沒有端點)。
- 編輯其他使用者的自訂品項(後端 404)。
- 管理員開通介面。
- 專屬的 admin 管理頁(這輪就內嵌在字典畫面)。
- 批次編輯、匯入匯出。
