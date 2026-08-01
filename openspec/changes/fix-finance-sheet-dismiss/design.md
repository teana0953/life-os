# 財務 bottom sheet 關不掉 — 設計

使用者實機回報:「管理科目的 bottom sheet 太長,無法回去原本的頁面,只能按實體的返回鍵,但又會回首頁」。

## 根因

`finance_scaffold.dart` 的四個 `showModalBottomSheet` 呼叫(記一筆 :125、科目管理 :140、快照輸入 :163、預算 :179)**只設了 `isScrollControlled: true`**,缺 `useSafeArea` 與 `showDragHandle`。

對照全專案其他呼叫點,慣例是三件一組:
- `food_search_screen.dart:164-168` — isScrollControlled + useSafeArea + showDragHandle
- `exercise_screen.dart:114-118` — 同上
- `goal_card.dart:51-55` — 同上
- `care_today_screen.dart:303-309` — isScrollControlled + useSafeArea(有註解說明為何需要 isScrollControlled)
- `care_history_screen.dart:147-153` — showDragHandle

**finance 是唯一一組沒跟上慣例的**,四個全中。

後果鏈:內容長(科目管理列出全部科目 + 新增區塊)→ `isScrollControlled` 允許 sheet 長到滿版 → 頂端沒有 safe area 內縮、也沒有 drag handle → **點不到 barrier、拖不動、看不出可下拉**→ 使用者只剩實體返回鍵 → PWA 上那是瀏覽器返回 → 退出 go_router 路由堆疊 → **回首頁**(而非回財務頁)。

## 修法

四處補齊 `useSafeArea: true` + `showDragHandle: true`。這讓:
- sheet 頂端留出 safe area,barrier 可點(點外面關閉)
- 出現 drag handle,可下拉關閉,且視覺上明示「這是可關的 sheet」

**不需要**額外的 maxHeight 或關閉鈕:Material 的 `showDragHandle` 已提供標準關閉手勢,`useSafeArea` 保證 barrier 可觸及;加自訂關閉鈕反而與其他 context 不一致。

## 範圍

- 只改 `finance_scaffold.dart` 四個呼叫點的 sheet 參數。
- 不改四個 sheet widget 本身的內容、版面、key。
- 範圍外:盤點第二批的 SheetForm 外殼抽取(那是重構,這是修 bug,不混);其他 context 的 sheet(已符合慣例)。

## 風險

`showDragHandle: true` 會在 sheet 頂端加一條 handle,**四個 sheet 的頂端多出約 22px**——這是預期中的視覺變化(與其他 context 一致),不是回歸。既有 widget test 若斷言了 sheet 內容的絕對位置可能受影響;若有測試因此變紅,確認是位移而非行為改變後再調整該測試斷言。

## 測試

- 四個 sheet 各補/擴一條測試:開啟後 drag handle 存在(`showDragHandle` 生效)。
- 迴歸:既有 finance sheet 測試全綠(記一筆、預算、快照、科目管理)。
- 實機驗證(留給使用者):長內容的科目管理 sheet 能以點外面/下拉關閉,回到淨值頁而非首頁。

## 驗收

四處參數補齊;`flutter analyze` 0 issue;`flutter test` 全綠;使用者實機確認 sheet 可正常關閉。
