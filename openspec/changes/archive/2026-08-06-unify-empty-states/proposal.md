## Why

這個 app 有 **至少 20 個空狀態**(第一版盤點寫 16,漏了 `trend_card` 的 `trend-empty`、`group_detail_screen` 的 `split-group-no-expenses` 與 `split-add-member-empty`、以及 `care_today_summary_card` 的 `care-today-summary-setup` —— 最後那個是一個 **InkWell Row 橫幅**,第五種形狀),四種以上的形狀,而**標題樣式用了五種不同的做法**:

| 形狀 | 站點 |
|---|---|
| 完整引導(icon 48 + 12 + titleMedium + 4 + bodyMedium + 16 + 按鈕) | care_items、care_today、care_history、food_search 的 `_ResultsMessage` |
| 同上但 **icon 40** | care_adherence_card |
| 標題+內文,無 icon | friends(titleMedium+8)、split_activity(**titleLarge**+8) |
| 標題+按鈕,無 icon | finance_overview(**bodyLarge**+16)、networth(bodyLarge+12)、budget_card(**bodyMedium**+12)、split_tab(bodyLarge) |
| 單行淡字 | exercise、menstrual、today 的餐別 |
| 單行,**沒淡化** | finance_transactions(**只是在「單行」這一組裡唯一**;friends 的內文、split_activity 的內文、split_tab、networth、finance_overview、budget_card 也都是預設色) |
| **Row 橫幅** | care_today_summary_card 的 `care-today-summary-setup` |

這不是重複而是**分歧**:同一種東西在不同畫面長得不一樣,而且沒有一處寫下為什麼。使用者在一次操作裡會走過其中好幾個。

## What Changes

**兩層標準**(使用者選定):

1. **完整引導** —— 頁/分頁層級的空狀態。icon + 標題 + 選填內文 + 選填行動。抽成共用元件,以 `food_search` 已經參數化的 `_ResultsMessage` 為基礎。
2. **單行淡字** —— 卡片/區塊內的空位。`bodyMedium` + `onSurfaceVariant` + 置中。

**第一層要支援選填的次要行動** —— 這不是可選的:`care_history` 的空狀態有**兩個**按鈕(加寬期間 / 去管理)、`split_tab` 有**三個**行動。

**不引入 Mascot。** 理由是 **icon 能表達「哪一種空」**(`search_off` = 找不到 / `event_note_outlined` = 還沒排 / `favorite_border` = 還沒收藏),吉祥物全部一樣。(第一版還寫了「repo 把吉祥物保留給達成」——**那個前提是假的**:6 個用法有 4 個是頁首裝飾。)

## Capabilities

### Modified Capabilities

- `shared-widgets`:新增空狀態的兩層共用元件。

## Impact

- **兩個站點明確排除**(判斷結果,不是待辦):`care-today-summary-setup` 是可點擊的設定入口而不是空狀態說明(套第二層會刪掉它的點擊目標,套第一層會在卡片內展開頁層級引導,而且 8 個測試綁著它);`split-add-member-empty` 在 `AlertDialog` 的 body 裡,兩層都不適用。
- 其餘站點,**每一個都要判斷屬於哪一層**,不是機械替換。判錯會把卡片內的小空位變成一個佔滿版面的引導。
- **`_ResultsMessage` 不能原樣抽出來**:它把 Column 包在 `SingleChildScrollView` 裡,而多數目標是 `ListView` 子項或在 `LedgeCard` 內 —— 巢狀垂直 viewport 會 assert。共用元件是裸 Column,捲動留在呼叫點。而它的 `titleColor` 是**錯誤狀態**用的(它同時渲染 reauth 與載入錯誤),所以「抽成空狀態元件」與「只碰空狀態」互相矛盾,要明確二選一。
- **`Key` 大多要保留,但不是全部**:`today_screen` 的餐別空狀態**沒有 key**(測試用 `find.text` 定位),`friends` 的 key 由呼叫點提供;`trend-empty` 與 `split-empty-needs-friends` 沒有任何測試在用,不構成約束。
- 視覺**會變**(這是目的),所以「行為零變化」不適用;要逐站點說明變成什麼、為什麼。
- 窄螢幕:完整引導在 320dp × 文字比例 2.0 要能用。**溢出會不會丟 `FlutterError` 取決於祖先有沒有給高度上界**:在 `Center` 或固定高度盒子裡的會丟(`finance_transactions`、`trend_card`),`ListView` 子項的不會 —— 而**改完之後這個分佈會變**。要逐站點重新確認,不能靠一句通則。
