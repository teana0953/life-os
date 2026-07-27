## Why

[issue #88](https://github.com/loftapartment/life-os/issues/88)：「[食物字典] 多一個容易查詢的入口」。

食物字典目前**只存在於「加入某一餐」的流程裡**：`FoodSearchScreen` 需要 `meal` + `day` 才能建構，點任何一列就是加進 tray，底部還有提交按鈕。想查「這東西算幾份」得走 健康 → 飲食 → 選一餐 → 加食物 → 搜尋，看完還得小心退出以免誤加。

**順序是反的** —— 你得先承諾「要記到哪一餐」，才能查「這東西算幾份」；而真實的查詢情境（在超市、看菜單、決定要不要吃）根本還沒到選餐那一步。

## What Changes

- **飲食頁 AppBar 加一個查詢圖示** → 開同一個搜尋畫面，但**不預先指定餐別**。字典本來就屬於飲食，放這裡語意最順；不放「記錄」分頁是因為那六格全是「記錄某件事」，字典是「查」，並列會誤導。
- **`FoodSearchScreen` 的 `meal` 改成可選**：`null` 時標題是「食物字典」。純查詢時要看不到任何記錄相關的 UI，而這**不是既有行為** —— 現況只有 tray 面板會隨 tray 空而消失，提交按鈕在 `bottomNavigationBar` 是無條件渲染（tray 空時只是 disabled、文案仍為「完成（0）」），手動輸入連結也一直在。所以 `meal == null` 且 tray 為空時要**隱藏**這兩者，而不是讓它們 disabled —— disabled 的按鈕仍在說「這裡是拿來記錄的」。點了食物 tray 與提交按鈕才一起出現：記錄的意圖由使用者表達，不是介面預設。
- **選餐延到送出時**：`CreateMealController` 的 `meal` 只在 `submit` 最後一行用到，`start(meal)` 只是 seed，所以延後綁定不需要改資料流。送出時開 bottom sheet 選三個標準餐或點心，**整個 tray 加到同一餐**。點心名稱要看該日已有哪些餐才能算，飲食頁本來就有那份資料，進字典時一起帶過去。
- **沿用飲食頁當下瀏覽的日期**，不是永遠今天 —— 否則補記昨天的飲食時，東西會悄悄記到今天。

不另做唯讀畫面：那會讓「查到了想記錄」變成死路（退出、選餐、再搜一次），而查詢與記錄本來就是連著的動作。最愛管理是免費得到的（空查詢顯示最愛、每列有愛心，都是既有行為）。

前端 only；後端與 `ImportRepository`／字典 API 不動。新增少量 l10n 文案（ARB ×3）。Gate = lint + `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `health-diet`: 食物字典 SHALL 有一個不必先選餐就能進入的查詢入口；從該入口記錄食物時，餐別 SHALL 在送出時才決定。
