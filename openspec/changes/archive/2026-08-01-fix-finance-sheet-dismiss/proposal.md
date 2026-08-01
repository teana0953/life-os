## Why

使用者實機回報:管理科目的 bottom sheet 太長時**關不掉**——點不到外面、沒有下拉把手,只剩實體返回鍵;而 PWA 上實體返回是瀏覽器返回,會退出 go_router 路由堆疊直接**回首頁**,不是回財務頁。

根因:`finance_scaffold.dart` 的四個 `showModalBottomSheet` 只設 `isScrollControlled: true`,缺 `showDragHandle`(關鍵)與 `useSafeArea`。其他 context 的**內容可長的** sheet 都有帶 handle(exercise、goal_card、care_today:314、care_history、food_search 的新增食材 sheet)——finance 是唯一沒跟上的,而且四個全中。(`food_search_screen.dart:214` 的選餐別 picker 三個參數都沒帶,但它只有四個選項、有 scrim,維持現狀合理。)

## What Changes

`lib/contexts/finance/presentation/finance_scaffold.dart` 四個 sheet 呼叫點(快照 :125、科目管理 :140、記一筆 :163、預算 :179)補上 `showDragHandle: true`(主要修法)+ `useSafeArea: true`(對齊慣例),與其他 context 一致。

效果:出現標準 drag handle——一塊**不在 scrollable 內**的可拖區域,無論內容多長都能下拉關閉,且視覺上明示可關。

**歸因更正**(proposal review 對照 Flutter SDK 查證):原先以為 `useSafeArea` 也是解方,實際上它只是 `SafeArea(bottom: false)`,而 PWA 的 top padding 一般為 0——在使用者踩雷的環境是 no-op。真正管用的是 `showDragHandle`。

不改 sheet widget 本身的內容、版面、key。範圍外:盤點第二批的 SheetForm 外殼抽取(重構,不與修 bug 混);其他 context 的 sheet(已符合慣例)。

## Capabilities

### Modified Capabilities

- `finance-ledger-ui`:**由 finance shell 開啟的所有模態 sheet**(含 networth 與 budgets 的)一律可用下拉手勢關閉,長內容時不再把使用者困在 sheet 裡。

## Impact

- `lib/contexts/finance/presentation/finance_scaffold.dart`:四處 sheet 參數。
- 視覺:四個 sheet 頂端多一條 drag handle(**48px**,SDK 的 `Padding(top: kMinInteractiveDimension)`),與其他 context 一致——預期變化,非回歸。
- 既有 finance sheet 測試預期續綠(全為 byKey 斷言,不受 48px 位移影響)。
- **已知殘留**:症狀的另一半——財務頁按返回會回首頁而非上一層——本 change 未修(go_router 路由堆疊的獨立問題),值得另開 change。
