# Tasks

## 1. 修四處 sheet 參數

- [ ] 1.1 `lib/contexts/finance/presentation/finance_scaffold.dart` 四個 `showModalBottomSheet` 呼叫(記一筆 :125、科目管理 :140、快照輸入 :163、預算 :179)補 `useSafeArea: true` + `showDragHandle: true`。對照 `food_search_screen.dart:164-168` / `exercise_screen.dart:114-118` / `goal_card.dart:51-55` 的既有寫法保持一致。

## 2. 測試

- [ ] 2.1 四個 sheet 各補一條測試:開啟後 drag handle 存在(`showDragHandle` 生效);若既有 sheet 測試已涵蓋開啟流程,擴充該測試即可。
- [ ] 2.2 迴歸:既有 finance sheet 測試(記一筆、預算、快照、科目管理)全綠。若因 drag handle 造成的位移而變紅,**先確認是位移而非行為改變**,再調整該測試斷言並在回報中說明。

## 3. 收尾

- [ ] 3.1 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
