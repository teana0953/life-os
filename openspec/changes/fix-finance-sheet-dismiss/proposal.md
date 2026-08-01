## Why

使用者實機回報:管理科目的 bottom sheet 太長時**關不掉**——點不到外面、沒有下拉把手,只剩實體返回鍵;而 PWA 上實體返回是瀏覽器返回,會退出 go_router 路由堆疊直接**回首頁**,不是回財務頁。

根因:`finance_scaffold.dart` 的四個 `showModalBottomSheet` 只設 `isScrollControlled: true`,缺 `useSafeArea` 與 `showDragHandle`。全專案其他呼叫點(food_search、exercise、goal_card、care_today、care_history)都有帶——finance 是唯一沒跟上慣例的,而且四個全中。

## What Changes

`lib/contexts/finance/presentation/finance_scaffold.dart` 四個 sheet 呼叫點(記一筆 :125、科目管理 :140、快照輸入 :163、預算 :179)補上 `useSafeArea: true` + `showDragHandle: true`,與其他 context 一致。

效果:頂端留出 safe area 讓 barrier 可點、出現標準 drag handle 可下拉關閉且視覺上明示可關。

不改 sheet widget 本身的內容、版面、key。範圍外:盤點第二批的 SheetForm 外殼抽取(重構,不與修 bug 混);其他 context 的 sheet(已符合慣例)。

## Capabilities

### Modified Capabilities

- `finance-ledger-ui`:財務的模態 sheet 一律可用點外關閉與下拉手勢關閉,長內容時不再把使用者困在 sheet 裡。

## Impact

- `lib/contexts/finance/presentation/finance_scaffold.dart`:四處 sheet 參數。
- 視覺:四個 sheet 頂端多一條 drag handle(約 22px),與其他 context 一致——預期變化,非回歸。
- 既有 finance sheet 測試應續綠;若因位移變紅,確認是位移非行為改變後調整斷言。
