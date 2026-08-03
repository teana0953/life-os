## Why

分帳後端已上(life-os-backend PR #65 + #66):群組、分帳支出、均分/自訂拆分、按幣別餘額、成員名字,12 條 endpoint。前端一條都沒接——使用者記不了分帳,也看不到誰欠誰。本 change 補上,sub-project 5 閉環。

使用者裁定:入口是**財務底部 nav 第四格「分帳」**(分帳本質就是財務,sub-project 6 還要把它整合進個人統計);分帳頁**以餘額為主**(打開分帳頁的問題幾乎都是「現在誰欠誰」)。

## What Changes

- 新 bounded context `lib/contexts/split/`(domain / application / infrastructure / presentation),照 `contexts/social/` 佈局。
- `SplitRepository` port + `HttpSplitRepository`:對接 `/api/split/*` 12 條;讀 body 的 `error` 欄分派十種 typed error(空或非 JSON 的 body 不得丟 decode error);401 → 既有 `needsReauth` 慣例;404 一律「找不到」不區分。
- `FinanceScaffold` 加第四格「分帳」——連帶要修 AppBar 標題的三元素陣列(index 3 會 RangeError)與只在 `_index == 2` 隱藏的 FAB(分帳 tab 會冒出記帳的 FAB),並比照淨值做延遲建立與載入;`SplitTab`:餘額分「別人欠你 / 你欠別人」兩段、按幣別分列、方向用文字不只靠顏色;底下是群組與最近支出。
- 群組詳情頁(成員、群組餘額、該群組支出),建立群組、從好友加成員、封存(二次確認)。
- 記一筆分帳的 sheet:群組/付款人/金額+幣別/說明/日期/參與者/拆法。**選了群組時候選只有該群組成員**,沒選群組時是好友+自己;均分即時顯示每人分到多少、自訂即時顯示還差多少;**呼叫者沒有實質份額時送出前就擋**,不等後端 400。
- 名字**直接用後端給的**(share、成員、餘額都帶 `display_name`——後端 PR #66 + #67)。初版設計那套「靠群組成員與好友湊」的前提被 proposal review 證明是錯的:後端只檢查建立者的好友關係,而每個 share 持有人都能讀,所以三人一次性分帳裡會出現讀者不認識的真人。候選名單需要的好友列表**重用 social context 的 `ListFriends`**,不新增第二條路徑。
- ARB 三檔新增文案;錯誤文案映射在 presentation。

範圍外:settle up / 還款(sub-project 6)、與 `finance_transaction` 連動(6)、匯率換算(全域決策)、離開群組、收據照片、通知。

## Capabilities

### New Capabilities

- `split-ui`:分帳 tab(餘額為主)、群組與成員、分帳支出 CRUD 與拆分 UI、錯誤與空狀態、窄螢幕版面。

### Modified Capabilities

- `finance-ledger-ui`:財務底部 nav 從三格變四格(既有三個 tab 的行為與 test key 不變)。

## Impact

- 新增 `lib/contexts/split/**`、`test/contexts/split/**`。
- 修改 `lib/contexts/finance/presentation/finance_scaffold.dart`(第四格 + controller)、`lib/app.dart`(群組詳情 route)、`lib/main.dart`(DI)、`lib/l10n/app_{en,zh_Hant,zh}.arb`。
- **底部 nav 從三格變四格是既有畫面的變更**:320dp × textScale 2.0 下四個標籤的版面必須重驗。
- 後端零改動。
