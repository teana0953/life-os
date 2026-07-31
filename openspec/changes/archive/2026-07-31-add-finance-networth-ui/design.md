# Finance Net Worth UI(前端)— 設計

財務 sub-project 3 前端。後端已完成(life-os-backend PR #63,`/api/finance/networth/*`)。前置:#1#2 前端已 merge(finance context、FinanceScaffold)。

## 目標

淨值追蹤 UI:財務新增第三個 tab「淨值」——科目市值月快照輸入、淨值+月成長率、逐月趨勢圖;科目管理(自定名/封存)。順帶把記帳頁現有的月份切換抽成共用 component 兩頁共用(使用者明確要求)。

## 範圍外

股票版、外幣換算、與交易連動、桌面多欄。

## 後端契約(凍結)

```
GET  /api/finance/networth/accounts            → 科目清單(含 archived);首呼觸發種子
POST /api/finance/networth/accounts            { kind, name, sort_order? }
PUT  /api/finance/networth/accounts/:id        { name?, sort_order?, archived? }  # kind 不可改
PUT  /api/finance/networth/snapshots           { account_id, month, value }        # upsert
GET  /api/finance/networth?month=YYYY-MM        → { month, accounts:[{account_id,kind,name,value}], total_asset, total_liability, net_worth, prev_net_worth, growth_rate }
GET  /api/finance/networth/trend?from&to        → { points:[{month, net_worth}] }
```

- value TWD 元非負整數;資產/負債都存正值。growth_rate/prev_net_worth 可為 null(首月/prev≤0)。

## 共用月份 component(先做,兩頁共用)

抽 `lib/shared/widgets/month_nav_header.dart` — `MonthNavHeader` 是**啞展示元件**:參數 `monthLabel`(String,顯示用)+ `onPrevious()` + `onNext()` 兩個 callback + `keyPrefix`。**不依賴 finance domain**——前後月的運算(previousMonth/nextMonth)由 caller 做(caller 在 finance context,持有 finance_month),widget 只畫 `‹ label ›` 並在點箭頭時呼對應 callback。這樣 shared/widgets 不反向依賴 contexts/finance/domain,分層乾淨。Keys:`<keyPrefix>-previous/label/next`。
- 重構記帳:`finance_overview_tab.dart` 的 private `_MonthNav` 換成 `MonthNavHeader`;**保留既有測試 key**——現有測試找 `finance-month-previous/label/next`,故 MonthNavHeader 的 key 用可傳入的 `keyPrefix`(記帳頁傳 `finance-month`,淨值頁傳 `networth-month`),既有測試不破。
- 這是本 change 唯一的既有碼重構,範圍限於把重複的月份列抽出,不改行為。

## 架構(finance context 延伸)

- `domain/`:`NetWorthAccount`、`NetWorthSnapshot`、`MonthlyNetWorth`(accounts+totals+net+prev+growth)、`NetWorthTrendPoint` 實體;`FinanceRepository` port 加 networth 方法(listAccounts/createAccount/updateAccount/upsertSnapshot/getMonthlyNetWorth/getNetWorthTrend)。
- `application/`:networth use cases(thin,照 finance 既有 use case 慣例)——`ListNetWorthAccounts`、`CreateNetWorthAccount`、`UpdateNetWorthAccount`、`UpsertSnapshot`、`GetMonthlyNetWorth`、`GetNetWorthTrend`;NetWorthController 呼叫 use case,不直呼 repository port(遵 presentation→application→domain 鐵律)。
- `infrastructure/`:`HttpFinanceRepository` 加對應實作。
- `presentation/`:
  - `FinanceScaffold` 底部 nav 加第三格「淨值」(現有 總覽/明細 → 總覽/明細/淨值)。
  - `NetWorthController`(ChangeNotifier,獨立於 FinanceController——淨值資料量與生命週期不同):`selectedMonth` 狀態(**淨值 tab 有自己獨立的 selectedMonth,不與記帳 總覽/明細 同步**——這是刻意的:淨值是月末身價快照、記帳是當月流水,兩者常看不同月;各 tab 自己的月份列各自切,不共享。避免「記帳看 7 月、淨值被連動」的錯位)、`load(month)`(accounts+monthly+trend 同批,月份 gate 防競態、切月清除、401→needsReauth、首個 await 前不 notify;trend 的 from/to 見下)、`saveSnapshot`、科目 create/update 後 reload。
  - **趨勢視窗**:load 時 trend 取 `from = selectedMonth 往前推 11 個月`、`to = selectedMonth`(近 12 個月);切月時視窗跟著移。
  - `NetWorthTab`:MonthNavHeader、淨值大數字卡(net_worth + 月成長率箭頭/百分比,growth null 時只顯示淨值不顯示率)、資產/負債分組的科目市值列表(每列可點開輸入該月值)、趨勢摺線圖(fl_chart LineChart,照 vitals trend 現有用法)、科目管理入口。
  - `SnapshotInputSheet`:點科目列開 bottom sheet 輸入該月市值(數字鍵盤、viewInsets padding),存=upsert。**0 vs 空的語意**:value 合法範圍是 ≥0(0 是合法市值,例如清空的帳戶);**空字串=該月未記錄**(不送 upsert,或若既有快照則不動);只有「有內容但 parse 不出 ≥0 整數」(負數/非數字)才是非法→errorText+存檔 disabled。不沿用 budget sheet 的「≤0 非法」,因為淨值 0 合法。
  - `AccountManageSheet`/區塊:新增科目(kind+name)、改名/排序/封存;archived 科目在市值列表不顯示但管理區可見/可復原。

## UI/UX 設計

### 使用者路徑

- **看淨值(主路徑)**:財務 → 淨值 tab → 淨值大數字 + 月成長率(綠漲紅跌走 theme 語意色)、下方資產/負債科目各自小計、趨勢圖。月份 ‹ › 切換看歷史。
- **更新市值**:點某科目列 → SnapshotInputSheet 輸入該月市值 → 存 → 淨值/成長率即時重算。空值=該月未填(不計入)。
- **管科目**:淨值 tab 右上管理鈕 → 新增(選 asset/liability + 名稱)、改名/封存;封存的科目歷史快照仍計入過去月淨值(後端保證),只是不再出現在當月輸入列表。
- **例外**:金額非負整數,非法輸入 errorText+存檔 disabled(照 budget sheet 修正後的慣例——不可靜默);載入失敗錯誤畫面+重試;401 reauth 出口;首月無成長率只顯示淨值。

### 介面與一致性

- MonthNavHeader 共用(記帳/淨值一致);淨值大數字卡用 LedgeCard;成長率箭頭↑↓+百分比(不只靠色);資產/負債分組標題;趨勢圖 fl_chart 照 vitals 慣例;bottom sheet 慣例照 AddTransactionSheet;金額格式 TWD 無小數。
- 全走 theme,漲跌色沿用 financeIncomeColor(漲/收入綠)+ colorScheme.error(跌)helper。

### 狀態設計

- loading/error+retry/reauth 照 finance 現有各 tab;空狀態:科目全空(種子後不會)→ 引導;某月零快照 → 淨值顯示 0/「本月尚未記錄」引導填第一筆。
- 趨勢圖資料點 <2 → 顯示「資料不足,持續記錄以看趨勢」而非空圖。

### 可及性

- Keys:`networth-tab`、`networth-net-value`、`networth-growth`、`account-row-<id>`、`snapshot-field`、`account-manage-button`、`networth-month-*`。
- 成長率同時給數字與方向文字,趨勢圖有可讀摘要。

## i18n

ARB 三檔(en/zh_Hant/zh)+ gen-l10n。科目名顯示後端值不翻譯。

## 測試(重要邏輯必須覆蓋)

- MonthNavHeader:‹ › 呼 onChanged 正確前後月;keyPrefix 隔離(記帳/淨值兩套 key 並存不撞)。
- 重構回歸:記帳頁既有月份切換測試仍綠(key 不變)。
- NetWorthController:load 落地+競態(舊月不覆蓋)、切月清除、saveSnapshot 後 reload、科目 CRUD 後 reload、401→needsReauth、非法輸入不送。
- repository:networth 各方法 status→typed exception、body 形狀(含 growth null)。
- widget:淨值卡數字+成長率箭頭(漲/跌/null 三態)、資產負債分組、科目列點開 sheet、快照 upsert、科目管理、趨勢圖 <2 點提示、空月引導、l10nTestApp。
- `TZ=UTC flutter test` 複驗。

## 驗收

設科目→填市值→淨值算出→切月看歷史→趨勢圖成形;記帳頁月份切換不回歸;`flutter analyze`+`flutter test` 全綠。
