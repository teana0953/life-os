# Finance Ledger UI(前端)— 設計

來源:總設計 spec 已由使用者核准(`docs/superpowers/specs/2026-07-31-finance-ledger-design.md`)。後端切片已完成(life-os-backend PR #61,`/api/finance/*` 契約以其 archive 後的 `openspec/specs/finance-ledger/spec.md` 為準)。本檔為前端切片。

## 目標

財務大域入口 + 個人記帳三畫面:總覽、明細、記一筆。mobile-first PWA。

## 範圍外

預算、淨值、分帳、推播、匯率換算、桌面多欄佈局、分類管理 UI(增改分類——本期只用預設分類;後續 sub-project 再做)。

## 後端契約(已凍結,實作照打)

```
GET    /api/finance/transactions?from&to     # from/to 必填 YYYY-MM-DD
POST   /api/finance/transactions             { type, amount, currency?, category_id, date, note? }
PUT    /api/finance/transactions/:id         { type, amount, currency, category_id, date, note? }  # currency 必填
DELETE /api/finance/transactions/:id
GET    /api/finance/categories               # 首呼觸發預設分類種子
GET    /api/finance/summary?month=YYYY-MM    # { month, totals:[{currency,expense,income,net}], by_category:[{category_id,type,currency,amount}] }
```

- `amount` 為最小幣別單位整數(TWD 元、USD cent)。幣別小數位數映射放 domain:`{TWD:0, JPY:0, KRW:0, 其餘:2}`,顯示與輸入解析共用。
- 幣別白名單:`TWD/USD/JPY/EUR/CNY/KRW/GBP/HKD/AUD/CAD`(下拉選單,預設 TWD)。

## 架構(照 hydration 模式,`lib/contexts/finance/`)

- `domain/`:`FinanceTransaction`、`FinanceCategory`、`MonthlySummary`(totals + byCategory)實體;`FinanceRepository` port(單一 port 涵蓋交易/分類/summary,YAGNI);typed exceptions(照 `diet_exceptions.dart` 慣例:NotFound、驗證錯、網路錯)。
- `application/`:`GetFinanceMonth`(一次取 summary+transactions+categories,見下)、`AddTransaction`、`UpdateTransaction`、`DeleteTransaction`。
- `infrastructure/`:`HttpFinanceRepository`(照 `http_water_repository.dart` 模式;PUT/POST 帶 `Content-Type: application/json`)。
- `presentation/`:`FinanceScaffold`(底部 nav 兩格:總覽/明細)、`FinanceController`(ChangeNotifier)、`FinanceOverviewTab`、`FinanceTransactionsTab`、`AddTransactionSheet`。
- DI:`main.dart` 組線,照現有慣例。

### FinanceController(單一 controller,月份為鍵)

- 狀態:`selectedMonth`(`YYYY-MM`,預設今天所在月)、`categories`、`transactions`(該月)、`summary`(該月)、`status`(loading/loaded/**needsReauth**/error)、typed error。
- **Auth 組線**:照 health_scaffold 慣例——`AuthRepository.idToken()` 取 token 傳 use case;API 回 401 → `needsReauth` 狀態,UI 走 `async_state_scaffold` 的 `isReauth` 出口(「請重新登入」),不是死路錯誤畫面。
- `load(month)`:先設 selectedMonth 再非同步抓(categories + summary + 該月 transactions,from=月初 to=月底);回應落地前檢查「回應對應的 month == 當前 selectedMonth」才寫入——防快速切月時舊回應覆蓋新月份(本專案共用 controller 日期錯位的累犯防線)。
- **跨月寫入**(累犯第四型防線):add/update 成功後,以「該筆交易的 date 所在月」為準 reload——若與 selectedMonth 不同,**selectedMonth 跳到該月**再載入,使用者永遠看得到剛存的那筆(spec 的 immediately-visible 承諾因此在跨月情境也成立)。delete 成功後 reload 當前月。
- **禁止 build 期同步 notify**(累犯):`load` 首個 await 前不 notify,進場觸發用 post-frame。

### 月份工具

`YYYY-MM` 字串運算(上/下月、月初月底、當月判定)放 `domain/finance_month.dart` 純函式,單元測試覆蓋(TZ 無關:全部字串運算,不過 DateTime.toUtc)。

## 路由與入口

- 首頁 hub(`home_screen.dart`)spaces grid **已有**財務 placeholder tile(index 1,`spaceFinance`,目前不可點)——本 change 是把它變可點:包 `InkWell` + `Key('finance-tile')` + `context.push('/finance')`,照 index 0 health-tile 現行寫法;不是新增一格,既有 tile 測試(health-tile/spaces-grid key)預期不破。
- `/finance` 單一 GoRoute → `FinanceScaffold`;兩個 tab 是 scaffold 內部狀態(照 HealthScaffold 慣例,不拆子路由——本期無更深層畫面,記一筆是 bottom sheet)。
- 掛在 `app.dart` 現有 route 表,DI 參數照 `_AuthenticatedHome`/health 模式傳入。

## UI/UX 設計

### 使用者路徑

- **主路徑(記一筆)**:首頁 → 財務 tile → 總覽;任一 tab 右下 FAB → 記一筆 bottom sheet → 填金額(數字鍵盤)→ 選分類(grid)→ 存 → sheet 關閉、當月資料刷新、新交易立即可見。預設值讓最常見情境(今天、TWD、支出)零額外操作:只需金額+分類兩步。
- **切換收入**:sheet 頂部 支出/收入 segmented 切換,分類 grid 隨 type 換組。
- **看月報**:總覽頁月份列 ‹ › 箭頭切月;支出/收入/結餘卡 + 分類統計 + 最近 5 筆。
- **查明細**:明細 tab,按日分組倒序;點一筆 → 同一個 sheet 帶入現值(編輯模式,可刪除)。
- **例外路徑**:金額空/0 → 存檔鈕 disabled(不彈錯);網路失敗 → snackbar 錯誤+內容保留可重試;載入失敗 → 錯誤畫面+重試鈕(注意:`async_state_scaffold` 只內建 loading/reauth 兩態,error+retry 在 builder 內自建,照 health 各 tab 現行做法);401 → `isReauth` 出口。
- **跨月存檔**:sheet 日期改成非當前檢視月(或編輯改 date 跨月)→ 存檔成功後畫面跳到該筆所在月,剛存的交易即刻可見。

### 介面與一致性

- 全部顏色/字體/形狀走 `Theme.of(context)`(Chiikawa 設計語彙),卡片用 `LedgeCard`/標準 20–22px 圓角+2px outline,主按鈕 `FilledButton`。
- 金額輸入:數字鍵盤,空值+`hintText`(repo 的 empty-zero 慣例);`TextField` 不用 `TextFormField`。
- bottom sheet:`showModalBottomSheet(isScrollControlled: true)` **加 `padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom)`**(鍵盤頂起;照 exercise_screen.dart:385 模式)。
- 金額顯示:依幣別小數位格式化;支出用 `colorScheme.error`;收入綠——`sageSuccess` 目前**沒有**映進 ColorScheme,在 `app_theme.dart` 新增 theme 層 helper(如 `financeIncomeColor(ColorScheme)`,light/dark 各給 AA 對比安全的 sage 值,照該檔既有 AA helper 慣例),screen 只呼叫 helper、不碰 hex。
- 多幣別:總覽卡按幣別分行列示(TWD 一行、USD 一行);單幣別(常態)就一行,不加雜訊。
- 分類統計:**不用 fl_chart**(fl_chart 1.x 無原生橫向 bar,repo 唯一用例是 LineChart)——用既有 `fractional_progress_bar` 橫條模式:每分類一列(icon+名稱+金額+比例橫條),依金額排序,幣別分組。
- 分類 icon:預設分類 icon 後端一律存 `'other'`,前端映射**以分類 `name` 為 key**(餐飲→restaurant、交通→directions_bus …),name 沒中映射才 fallback `icon` 欄位→最後 `category` 泛用 icon;映射表放 presentation。

### 狀態設計

- loading:總覽/明細首載 spinner(async_state_scaffold)。
- 空狀態:該月無交易 → 引導文案+「記第一筆」按鈕(開 sheet),不是空白頁。
- 錯誤:載入錯 → 錯誤畫面+重試;寫入錯 → snackbar 說明+表單內容保留。
- 邊界:金額 0/空 → 存檔 disabled;超長 note 正常換行截斷顯示。

### 可及性/理解性

- 全部文案走 ARB(en + zh_Hant + zh 同步,三檔),錯誤訊息說明下一步(「請檢查網路後重試」)。
- 互動元件加 `Key`(測試+語意):`finance-tile`、`finance-fab`、`amount-field`、`save-transaction-button` 等。

## i18n

新 key 加進 `app_en.arb`(含 description)+ `app_zh_Hant.arb` + `app_zh.arb`(與 zh_Hant 同步——repo 慣例三檔都要),`flutter gen-l10n` 後 commit generated。分類名稱:後端種子存中文名,前端直接顯示後端回傳的 `name`(不翻譯——使用者資料非 UI 文案)。

## 測試(重要邏輯必須覆蓋;TDD 依需求)

- domain:`finance_month.dart` 純函式(跨年切月、月底日數)、金額格式化/解析(各幣別小數位、非法輸入)。
- application/controller:fake repository——載入狀態轉換、切月舊回應不覆蓋新月份(競態測試)、寫入後 reload、跨月寫入跳月、401→needsReauth、typed error 傳遞。
- presentation widget test:記一筆表單(金額空→disabled、填好→enabled、送出呼叫 use case)、明細按日分組、總覽卡數字、空狀態顯示、l10nTestApp 包裝斷言 localized key。
- `TZ=UTC flutter test` 複驗(鐵律)。

## 驗收

記一筆 → 明細出現 → 總覽數字更新 → 切月資料正確 → 重整(PWA)資料還在;`flutter analyze` + `flutter test` 全綠(看到 `All tests passed!`)。
