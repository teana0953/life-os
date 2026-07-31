# Finance Budgets UI(前端)— 設計

財務 sub-project 2 前端。後端已完成(life-os-backend PR #62,`/api/finance/budgets`)。前置:sub-project 1 前端已 merge(PR #110,`contexts/finance` 四層、FinanceScaffold 總覽/明細)。

## 目標

預算設定+進度呈現:總覽 tab 加預算卡;設定 bottom sheet(總額+各 expense 分類)。推播接收端零改動(既有 Web Push 基礎)。

## 範圍外

淨值、分帳、每日摘要、預算歷史、外幣預算(後端即 TWD only)。

## 後端契約(凍結)

```
GET    /api/finance/budgets?month=YYYY-MM
  → { month, budgets: [{ id, category_id|null, amount, spent, remaining, percent }] }
PUT    /api/finance/budgets      { category_id|null, amount }   # upsert
DELETE /api/finance/budgets/:id
```

- 金額 TWD 元整數;`category_id` null = 總額;percent 為整數(後端 round)。
- 進度只計 TWD expense;80/100 推播由後端發,前端無需輪詢。

## 架構落點(沿用 finance context)

- `domain/`:`FinanceBudget` 實體(含 progress 欄位);`FinanceRepository` port 加三方法(listBudgets(month)/upsertBudget/deleteBudget)。
- `infrastructure/`:`HttpFinanceRepository` 加對應實作。
- `application/`:併入現有 use case 慣例(thin)。
- `presentation/`:
  - `FinanceController` 加 `budgets` 狀態:`load(month)` 一併抓 budgets(與 summary/transactions 同一個 `Future.wait` 批,沿用既有競態防線——同月才落地;**切月同步清除也比照 summary/transactions**,不殘留舊月 budgets);`saveBudgets` 逐筆循序套 diff(部分失敗語意見 UI/UX 節),完成或失敗都 reload 當前月。
  - `BudgetCard`(總覽 tab 新卡)+ `BudgetSheet`(設定 bottom sheet)。

## UI/UX 設計

### 使用者路徑

- **看進度(主路徑)**:總覽 tab、月摘要卡下方新「預算」卡:總額預算一列 + 有設預算的分類各一列;每列:名稱、`spent / amount`(TWD 格式)、文字百分比、fractional_progress_bar 進度條(`fillColor` 由 caller 給,三段變色可行)。**三段判定一律用後端回傳的整數 `percent`**(<80 正常、80–99 警示、≥100 error+「已超支」標籤),bar 填充比例用 `spent/amount` clamp 1.0——避免前端自算與後端 round 在 79/80 邊界不一致。警示色:`honeyWarning` 是 pastel(光底 2.08:1 不過 AA),照 `financeIncomeColor` 先例在 app_theme 加 AA 安全 helper。
- **設定預算**:預算卡右上「編輯」icon 鈕 → `BudgetSheet`(bottom sheet,isScrollControlled+viewInsets padding):第一列「每月總預算」,下方 expense 分類各一列(**未 archived 的全列;archived 只在「目前有預算」時列出**,標示已封存、只能清空刪除不能改值——後端對 archived upsert 會 400),金額欄 empty-zero 慣例(空=未設);sheet 標題下加說明「預算為每月循環設定,修改即套用到所有月份」。填數字=upsert、清空既有=刪除;「儲存」批次套用。
- **批次儲存的部分失敗語意**(無交易性,誠實處理):逐筆循序送 diff;任一筆失敗 → **立即 reload 當前月**(讓已套用的部分如實反映)、sheet 保持開啟、使用者輸入值保留、diff 基準改用 reload 後的新 budgets 重算——重試只補送真的還沒成功的(已成功的 delete 不會重送打出 404)。全部成功 → 關閉+reload。
- **空狀態**:一筆預算都沒設 → 預算卡顯示引導文案+「設定預算」按鈕(開 sheet),不是隱藏——功能可被發現。
- **非當月**:切到過去/未來月,預算卡照常顯示該月進度(預算是循環設定,spent 隨月變)。

### 介面與一致性

- 卡片 LedgeCard/圓角 outline 慣例;進度條 reuse `fractional_progress_bar`(分類統計已用);編輯鈕照 repo icon button 慣例;`TextField` 數字鍵盤。
- 超支語意色:≥80 用 theme 的 honey/amber(查 app_colors 現有 semantic;若無 AA 安全變體,照 financeIncomeColor 先例在 app_theme 加 helper)、≥100 用 `colorScheme.error`。screen 不碰 hex。
- 文案 ARB 三檔(en/zh_Hant/zh)。

### 狀態設計

- 預算卡隨 controller 既有 loading/error/reauth 態(卡在 loaded 內容中,無獨立請求);sheet 儲存中 disabled+進度指示;儲存失敗內容保留。
- 邊界:金額 0/空=未設(刪除);非法輸入(非整數)擋在解析層,存檔鈕 disabled 規則同記帳 sheet。

### 可及性

- Key:`budget-card`、`budget-edit-button`、`budget-sheet-save`、每列 `budget-field-<category_id|total>`。
- 進度條附文字百分比(不只靠顏色)。

## 測試(重要邏輯必須覆蓋)

- controller:budgets 隨 load 落地(含競態——沿用既有月份 gate 測試模式)、切月同步清除舊月 budgets、儲存後 reload、批次 diff 邏輯(改 2 筆只發 2 個請求;清空發 delete;沒動不發)、部分失敗(立即 reload、基準重算、重試不重送已成功筆)。
- repository:三方法 status→typed exception、body 形狀。
- widget:預算卡三態色(79/80/100 邊界)、空狀態 CTA、sheet 批次儲存呼叫、失敗保留、l10nTestApp。
- `TZ=UTC flutter test` 複驗。

## 驗收

設預算 → 總覽出現進度;記帳到 80% → 卡變警示色(推播由後端,實機驗);清空預算 → 卡回空狀態。`flutter analyze`+`flutter test` 全綠。
