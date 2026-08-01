# Tasks

## 1. 修四處 sheet 參數

- [ ] 1.1 `lib/contexts/finance/presentation/finance_scaffold.dart` 四個 `showModalBottomSheet` 呼叫(**快照 :125、科目管理 :140、記一筆 :163、預算 :179**——動手前先讀該檔確認對應關係)補 `showDragHandle: true`(主要修法)+ `useSafeArea: true`(對齊慣例)。對照 `food_search_screen.dart:164-168` / `exercise_screen.dart:114-118` / `goal_card.dart:51-55` 的既有寫法保持一致。

## 2. 測試

- [ ] 2.1 四條測試**寫在 `test/contexts/finance/presentation/finance_scaffold_test.dart`**:從 scaffold 實際開啟每個 sheet,斷言 drag handle 存在。**不要**寫進 `budget_sheet_test.dart` / `add_transaction_sheet_test.dart`(它們自帶一份 showModalBottomSheet)或直接 pump widget 的測試檔——那會生出永遠不紅的假測試。寫完以 mutation 驗證:拿掉 `showDragHandle` 應變紅。
- [ ] 2.2 迴歸:既有 finance sheet 測試(記一筆、預算、快照、科目管理)全綠。若因 drag handle 造成的位移而變紅,**先確認是位移而非行為改變**,再調整該測試斷言並在回報中說明。

## 3. 收尾

- [ ] 3.1 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
