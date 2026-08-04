# Tasks

**純重構,行為必須零變化。** 驗證要拿 `main` 對照,不是讀註解斷定「應該一樣」。

## 1. helper

- [ ] 1.1 `lib/shared/widgets/app_sheet.dart`:`Future<T?> showAppSheet<T>(BuildContext context, {required WidgetBuilder builder})`,固定帶 `isScrollControlled: true` / `useSafeArea: true` / `showDragHandle: true`
- [ ] 1.2 doc comment 收攏三段理由(目前散在三份近乎相同的註解裡):
  - `showDragHandle` — 沒有它,高 sheet 填滿視窗 → scrim 消失 → 拖曳被內容的捲動吃掉 → 只剩瀏覽器返回鍵,而在 PWA 上那會把 router stack 拆回首頁(PR #115)
  - `isScrollControlled` — 不設就被截在螢幕高的 9/16,送出鈕被切掉
  - `useSafeArea` — 實際上套的是 `SafeArea(bottom: false)`,底邊仍歸 sheet 自己處理(所以有些 sheet 還要自己加 `MediaQuery.paddingOf(context).bottom`)
- [ ] 1.3 **不吃額外參數**:目前 12 個呼叫點除那三個選項與 `builder` 外沒傳任何其他東西。真有第 13 種需求再加——加參數比拿掉容易

## 2. helper 的測試

- [ ] 2.1 拖曳把手存在
- [ ] 2.2 內容超過 9/16 時不被截斷(高內容的 sheet,底部元素仍在畫面內)
- [ ] 2.3 `useSafeArea` 的效果驗**上/左/右**的 padding,**不要驗底部 inset**——Flutter 的 `bottom_sheet.dart` 在有無這個選項時都讓 sheet 延伸到螢幕底部(它自己的 doc 就這麼寫),底部行為完全相同,拿它當斷言是一條不可能失敗的守門
- [ ] 2.4 **每一條各自突變**:把對應那個選項從 helper 拿掉,**那一條**必須紅(不是別條)。三個結果都要回報;若有任何一條找不到能讓它紅的突變,**不要留著它**

## 3. 十二個呼叫點

- [ ] 3.1 六個檔、十二處(proposal review 逐檔讀出來的清單,**仍要自己複核**):
  - `group_detail_screen.dart:167, 205` — `<void>`,結果未使用
  - `food_search_screen.dart:164` — `<void>`,builder 的 context 命名為 `sheetContext` 但只出現在註解裡
  - `exercise_screen.dart:115` — `<_NewEntry>`,**結果有被使用**
  - `goal_card.dart:53` — `<_GoalEdit>`,**結果有被使用**
  - `finance_scaffold.dart:194, 232, 334, 356, 378, 396` — 六處全部帶完整三件組(**不是五處**)
  - `care_today_screen.dart:296` — `<_EditSheetResult>`,**結果有被使用**
- [ ] 3.2 **動手前自己重數一次**,列出每個呼叫點與它實際帶的選項。**不要信任何寫下來的數字,包括上面這份**——這份盤點已經錯過兩次(第一次 grep 視窗被註解推出去誤判兩處漏選項;第二次總數寫成 12/10/2 而實際是 14/12/2)。一個被靜默跳過的呼叫點正是這個 change 最會失敗的地方
- [ ] 3.2b 三處的回傳值**有被使用**(`exercise_screen`、`goal_card`、`care_today_screen`),helper 的泛型要能原樣承接私有型別(合法 Dart);改完要確認那三處的回傳仍被正確消費
- [ ] 3.3 還有**第四份**同樣的選項理由,寫在 `care_today_screen.dart:1116` 的 widget build 裡(不是呼叫點),掃註解時不會掃到它——一併收進 helper 的 doc comment 或改成指過去
- [ ] 3.4 每個呼叫點原本的解釋性註解:選項的理由移進 helper 的 doc comment,**該呼叫點特有的**理由留著(例如 `care_today_screen` 那句「這個 sheet 的自然高度會被 9/16 截掉送出鈕」是具體到那個畫面的觀察)

## 4. 兩個例外

- [ ] 4.1 `food_search_screen.dart:214`(選餐別)保留原樣:**三個選項一個都沒設**、維持 9/16 上限、自己包 `SafeArea` + `SingleChildScrollView`
- [ ] 4.2 `care_history_screen.dart:147`(狀態選擇)保留原樣:只有 `showDragHandle`,自己包 `SafeArea`
- [ ] 4.3 兩處各加一行註解指向 `showAppSheet`,說明**為什麼這裡不用它**——現在它們跟「忘了寫」在程式碼上長得一樣

## 5. 行為零變化的證據

- [ ] 5.1 既有測試全綠——第一層證據,**但它在兩處是空的**:`group_detail_screen_test.dart` 與 `exercise_screen_test.dart` 完全沒有斷言任何 sheet 選項
- [ ] 5.2 **第二層**:與 `main` 的渲染結果逐項對照(sheet 高度、拖曳把手存在、送出鈕是否在畫面內),用 `git worktree` 開 `main` 跑同一份探測、**不要靠讀 diff 推論**。**要瞄準 5.1 空掉的那兩處**(`group_detail_screen`、`exercise_screen`)——挑既有測試已經很厚的地方對照是做樣子
- [ ] 5.3 `bash scripts/lint-actions.sh`、`flutter analyze`、`flutter test`、`TZ=UTC flutter test` 全綠
