## Why

`showModalBottomSheet` 在 `lib/` 有 14 個呼叫點,其中 **12 個用完全相同的三件組**(`isScrollControlled` / `useSafeArea` / `showDragHandle`),而且每一處還各自帶著一段解釋「為什麼要這三個」的多行註解——三份措辭近乎相同、各自被重新推導出來的知識。

**這一期不修 bug**:初次盤點以為有兩處漏了 `showDragHandle`,那是 grep 視窗被註解推出去造成的誤判;逐檔看過後 12 處齊備(而且總數也錯過一次:12/10/2 vs 實際 14/12/2)。價值是把那段知識收到一個地方、讓兩個刻意的例外變成看得出來的例外、以及讓下一個 sheet 預設就對。

## What Changes

- `lib/shared/widgets/app_sheet.dart`:`showAppSheet<T>(context, {required builder})`,固定帶那三個選項,doc comment 收攏三段理由(`showDragHandle` 對應 PR #115 的高 sheet 出不去、`isScrollControlled` 對應 9/16 截斷、`useSafeArea` 實際上是 `SafeArea(bottom: false)`)。
- **12 個呼叫點改用它**(六個檔)。三處的回傳值有被使用,helper 的泛型要能原樣承接私有型別。
- **2 個刻意不同的保留原樣並註明是例外**:`food_search_screen`(選餐別,三個選項一個都沒設,維持 9/16 上限)與 `care_history_screen`(狀態選擇)。兩者都是短選擇器不是表單,改掉會改變使用者看到的高度與捲動行為。

**純重構,行為零變化。** 驗證要拿 `main` 對照,不是讀註解斷定。

## Capabilities

### Modified Capabilities

- `shared-widgets`:新增共用的 modal sheet 呼叫。

## Impact

- 新增 `lib/shared/widgets/app_sheet.dart` 與其測試。
- 修改 6 個檔案的 12 個呼叫點。
- 既有測試不得破——它們全綠是行為未變的第一層證據。
