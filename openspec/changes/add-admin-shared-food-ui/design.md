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
- `HomeController.load(idToken)` 只在 `_AuthenticatedHome.initState` 被呼叫(app.dart:964-974),而那個 widget 只活在首頁路由;**深連結直接進 `/health/dictionary`(PWA 捷徑就是這樣)不會載入 profile**。

## 決策

### D1 — `UserProfile.isAdmin`

`UserProfile` 加 `final bool isAdmin`,`fromJson` 讀 `json['is_admin'] as bool? ?? false`。**用 `?? false` 而不是必填**:後端雖已上線,但舊快取回應或未來回滾都可能少這個鍵,少一個鍵不該讓整個 profile 解析炸掉變成錯誤畫面。

### D2 — admin 狀態怎麼到達字典畫面:`homeController` 直接傳入,並在需要時自行補載

不新增第二個 profile 控制器(會變成兩次 `/api/me`),而是把既有的 `HomeController` 當作 session profile 的持有者:

- `FoodSearchScreen` 多一個必填參數 `isAdmin`(純 bool,不是 controller)——畫面本身不該知道 profile 怎麼來的。
- app.dart 的 food-search / dictionary 路由從 `widget.homeController.profile?.isAdmin ?? false` 取值,並以 `AnimatedBuilder` 監聽 `homeController`,profile 載入完成時該畫面會重建。
- **深連結補載**:把 `_AuthenticatedHome.initState` 那次 `homeController.load(...)` 提到**認證後、與路由無關**的位置(`_AppState` 取得 idToken 後),讓任何進入點都有 profile。`HomeController.load` 是冪等的(重跑只是重設狀態再抓一次),但仍要避免同一次認證重複觸發 —— 以「已載入過就不重載」的旗標守著,`_AuthenticatedHome` 改成只在尚未載入時觸發。

取捨:profile 還在載入時,admin 看到的字典畫面**短暫沒有編輯入口**,載完才出現。可接受(不會誤讓非 admin 看到),且比在字典畫面自己再打一次 `/api/me` 單純。

### D3 — 編輯入口:結果列的 `PopupMenuButton`,只對 admin 且只對共用品項顯示

結果列的 trailing 目前是收藏鈕。改成:非 admin 或非共用品項時**完全維持現狀**(單一收藏 `IconButton`);admin 看共用品項時,收藏鈕旁多一個 `⋮` `PopupMenuButton`,選單只有一項「編輯」。

為何不是長按:長按沒有可見的可發現性,且與既有互動語彙不合(這個 app 其他清單的次要動作都是可見圖示)。為何不是直接放一個鉛筆 `IconButton`:結果列已有收藏鈕,兩個圖示會擠掉名稱寬度;`⋮` 之後要加「刪除」也有地方放。

`onTap`(把品項加進 tray)維持不變 —— 編輯是次要動作,不能取代主要動作。

### D4 — 表單:一個 bottom sheet,建立與編輯共用

`SharedFoodItemSheet`,`showModalBottomSheet` + `isScrollControlled: true`。**不是 `AlertDialog`** —— 這個專案踩過:手機上 `AlertDialog` 配鍵盤會把內容擠掉/遮住,含文字輸入的表單一律用 bottom sheet(既有 `_PortionEditDialog` 之外的新表單照此)。

欄位:名稱、四項份數(主食/肉類/水果/蔬菜)、六項營養素(碳水/蛋白質/脂肪/糖/纖維/熱量)、量基準(`base_amount` + `measure_unit`)。數值輸入沿用專案慣例:**值為 0 時顯示空字串 + `hintText: '0'`**(見 CLAUDE.md「Numeric input empty-zero convention」)。

同一個 sheet 兩種模式:
- **建立**:全部空白,送出打 `POST /api/admin/food-items`。
- **編輯**:預填該品項現值,送出打 `PATCH /api/admin/food-items/:id`,**只送有改動的欄位**(對齊後端「缺鍵=不動」語意,也避免把沒碰的欄位覆寫成一樣的值)。

### D5 — 量基準的成對規則在前端就擋

後端要求 `base_amount` 與 `measure_unit` 同時有值或同時為空,違反回 400。前端在送出前就檢查,錯誤顯示在欄位旁、講清楚怎麼修(「數量與單位要一起填,或一起留空」),不要讓使用者靠後端 400 才知道。`base_amount` 也必須為正(後端 `> 0`)。

### D6 — 建立入口:字典畫面的 AppBar 動作

admin 在字典/搜尋畫面的 AppBar 多一個「新增共用品項」動作(`IconButton`,`Icons.add`);非 admin 完全看不到。放 AppBar 而不是列表底部:它與「當前搜尋結果」無關,是畫面層級的動作。

### D7 — 成功後重新整理

建立或編輯成功後關閉 sheet、顯示 `SnackBar`,並重跑目前的搜尋(有查詢字串就重搜,否則重載收藏),讓改動立刻反映在列表。**不做本地樂觀更新** —— 這是低頻的管理動作,一次重搜遠比維護一份本地副本簡單且不會不同步。

### D8 — repository/use case 分層

`FoodDictionaryRepository` port 加兩個方法:`createSharedItem(idToken, input)`、`updateSharedItem(idToken, id, patch)`;`HttpFoodDictionaryRepository` 實作,沿用既有 `_send`(401 → `DietReauthenticationRequired`)。新增兩個 use case(`CreateSharedFoodItem`、`UpdateSharedFoodItem`)在 `application/`。403 要有自己的錯誤型別(不能與一般失敗混為一談):非 admin 打這兩個端點時,畫面要說「沒有權限」,不是「請再試一次」。

### D9 — 錯誤是**型別**不是文字

依 CLAUDE.md i18n 規則,infrastructure/domain 丟型別化錯誤,controller 存型別,畫面在 `build()` 才轉成 `AppLocalizations` 文案。新增的 ARB key 先寫進 `app_en.arb`(含 description)與 `app_zh_Hant.arb`。

## UI/UX 設計

### 使用者路徑

- **主路徑(編輯)**:admin 從飲食頁進食物搜尋(或 PWA 捷徑直接進字典)→ 搜到一個共用品項 → 點該列的 `⋮` → 選「編輯」→ bottom sheet 帶著現值開啟 → 改幾個欄位 → 送出 → sheet 關閉、SnackBar 告知成功、列表即時顯示新值。
- **主路徑(建立)**:admin 在同一畫面點 AppBar 的 `+` → 空白 bottom sheet → 填名稱與數值 → 送出 → SnackBar 告知成功、該品項出現在後續搜尋中。
- **例外路徑**:非 admin 看不到 `⋮` 也看不到 `+`(不是停用,是不存在);表單驗證失敗留在 sheet 內、錯誤在欄位旁;送出時 401 走既有的重新登入出口;403 顯示「沒有權限」並關閉入口。

### 介面與一致性

- 結果列維持 `ListTile` 形狀與 `PortionPills` subtitle;新增的 `⋮` 與既有收藏鈕並排在 trailing。
- bottom sheet 用專案既有的圓角/外框語彙,主要動作 `FilledButton`、次要 `OutlinedButton`(來自 theme,不自己刻)。
- 所有顏色/字級都走 `Theme.of(context)`,不寫死。
- 數值欄位遵守 0 顯示為空字串 + `hintText: '0'` 的專案慣例。

### 狀態設計

- **送出中**:主要按鈕變為不可按 + spinner,欄位維持可讀(不清空)。
- **驗證失敗**:錯誤文字出現在對應欄位下方,已填內容全部保留,sheet 不關。
- **送出失敗(網路/500)**:sheet 內顯示可重試的錯誤訊息,內容保留。
- **403**:訊息說明沒有權限,並關閉該入口(重新整理 profile 前不再顯示)。
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
