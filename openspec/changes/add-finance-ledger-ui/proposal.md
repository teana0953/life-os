## Why

財務大域 sub-project 1(個人記帳)的後端已完成(life-os-backend PR #61,`/api/finance/*`)。前端目前沒有任何財務入口——需要記帳三畫面(總覽/明細/記一筆)讓功能閉環。總設計正本:`docs/superpowers/specs/2026-07-31-finance-ledger-design.md`(已核准)。

## What Changes

- 首頁 hub 既有的財務 placeholder tile(index 1)變可點,push `/finance`。
- 新 context `lib/contexts/finance/`(domain/application/infrastructure/presentation 四層,照 hydration 模式):`HttpFinanceRepository` 接後端契約、`FinanceController`(月份為鍵,防切月競態)、月份純函式工具、幣別小數位格式化。
- `FinanceScaffold`:財務自己的底部 nav 兩格(總覽/明細),照 HealthScaffold 慣例(tab 為內部狀態)。
- 總覽 tab:月份切換、支出/收入/結餘卡(按幣別分行)、分類統計(fractional_progress_bar 橫條列)、最近 5 筆、空狀態引導。
- 明細 tab:按日分組倒序、點一筆開編輯(可刪除)。
- 記一筆/編輯:同一個 bottom sheet(`isScrollControlled` + viewInsets padding),金額數字鍵盤(empty-zero 慣例)、支出/收入切換、分類 grid、日期預設今天、幣別下拉預設 TWD、備註。
- i18n:en/zh_Hant/zh 三 ARB 同步 + gen-l10n。

範圍外:預算、淨值、分帳、分類管理 UI、桌面多欄。

## Capabilities

### New Capabilities

- `finance-ledger-ui`:個人記帳前端——財務入口、總覽/明細兩 tab、記一筆/編輯 bottom sheet、多幣別分行顯示。

### Modified Capabilities

(無——首頁只是讓既有 placeholder tile 可點,不動既有 capability 行為。)

## Impact

- `lib/contexts/user/presentation/home_screen.dart`:財務 placeholder tile 變可點。
- `lib/app.dart`:+`/finance` route 與 DI 傳遞;`lib/main.dart`:組線。
- 新增 `lib/contexts/finance/**`、對應 widget/unit tests。
- `lib/l10n/*.arb` + generated。
- 既有畫面零行為變更。
