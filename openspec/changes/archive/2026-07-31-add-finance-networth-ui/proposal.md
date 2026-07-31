## Why

淨值後端已上(life-os-backend PR #63):科目、月快照、淨值+成長率、趨勢。但前端沒有淨值 UI——設不了科目也看不到淨值。本 change 補上,sub-project 3 閉環。使用者另要求:記帳頁的月份切換抽成共用 component,淨值頁 reuse。

## What Changes

- 共用 `MonthNavHeader`(`lib/shared/widgets/`):`‹ YYYY-MM ›` 列,`keyPrefix` 參數隔離不同頁的測試 key;記帳頁的 private `_MonthNav` 重構為它(保留既有 `finance-month-*` key,測試不破)。
- 財務底部 nav 加第三格「淨值」;`NetWorthController`(獨立於 FinanceController):load(accounts+monthly+trend 同批,月份競態防線+切月清除+401 reauth)、saveSnapshot、科目 CRUD 後 reload。
- `NetWorthTab`:淨值大數字+月成長率(漲跌色+箭頭方向,null 時只顯示淨值)、資產/負債分組科目市值列、趨勢摺線圖(fl_chart)、科目管理入口。
- `SnapshotInputSheet`(點科目輸入該月市值,非負整數 errorText+gate)、科目管理(新增 kind+name、改名/排序/封存)。
- `FinanceRepository`/`HttpFinanceRepository` 加 networth 方法;ARB 三檔。

範圍外:股票版、外幣換算、與交易連動、桌面多欄。

## Capabilities

### New Capabilities

- `finance-networth-ui`:淨值 tab(淨值+成長率+趨勢)、科目市值月快照輸入、科目管理。

### Modified Capabilities

- `finance-ledger-ui`:記帳總覽的月份切換列改用共用 `MonthNavHeader`(行為與測試 key 不變,純重構;帶 finance-ledger-ui spec delta)。

## Impact

- 新 `lib/shared/widgets/month_nav_header.dart`;`finance_overview_tab.dart` 重構月份列。
- `lib/contexts/finance/`:domain/infrastructure port+impl 擴充 networth、presentation 新 tab+controller+sheets。
- `FinanceScaffold` 加第三 nav 格;`app.dart`/`main.dart` DI。
- `lib/l10n/*.arb` + generated。
