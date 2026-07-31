# 財務功能 — Sub-project 1:個人記帳核心(設計)

日期:2026-07-31
狀態:已與使用者確認

## 背景與整體藍圖

lifeos 新增「財務」大域,與「健康」平行。整體範圍分三個子系統,拆成多個 sub-project,各走自己的 spec→plan→實作循環:

1. **個人記帳**(本 spec):支出+收入、分類、幣別標記、月/分類統計;後續 sub-project 加預算+超支推播
2. **分帳**(Splitwise 核心):好友(邀請連結+token)、群組、均分/自訂分帳、按幣別餘額、settle up;對方為 lifeos 使用者,雙方可見
3. **淨值**(滿月記帳法):資產/負債科目、每月市值快照、淨值+月成長率;收支月統計從記帳自動彙總

建構順序(方案一,已確認):個人記帳 → 預算 → 淨值 → 好友/邀請 → 群組分帳 → settle up+整合。理由:個人記帳獨立即有價值;分帳依賴跨使用者授權(現有資料完全按使用者隔離),為全案最大後端架構風險,後置。

已確認的全域決策:
- mobile-first PWA,不做桌面多欄佈局
- 多幣別「標記不換算」:每筆交易可選幣別,統計/餘額按幣別分列,不接匯率 API
- 淨值頁不含股票版(持股/損益/股息追蹤不做)
- 預算超支提醒:app 內顯示 + Web Push(後續 sub-project)
- TDD 依需求採用,非強制;重要邏輯必須有測試覆蓋

## 本期範圍(sub-project 1)

個人記帳核心:交易 CRUD、分類管理(預設種子)、月統計、財務總覽/明細兩頁 + 記一筆 bottom sheet。

不含:預算、淨值、分帳、推播、匯率換算、子分類。

## 資料模型(後端 D1 + Drizzle)

### `finance_transactions`

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | pk | |
| `user_id` | fk | 使用者隔離 |
| `type` | text | `expense` \| `income` |
| `amount` | integer | 最小幣別單位(TWD 存元、USD 存 cent),避免浮點誤差;必須 > 0 |
| `currency` | text | ISO 代碼,預設 `TWD`,白名單驗證 |
| `category_id` | fk | 必填 |
| `date` | text | `YYYY-MM-DD`,沿用現有 date 慣例(防時區錯位) |
| `note` | text | 可空 |
| `created_at` / `updated_at` | | |

### `finance_categories`

| 欄位 | 型別 | 說明 |
|---|---|---|
| `id` | pk | |
| `user_id` | fk | |
| `name` | text | |
| `type` | text | `expense` \| `income` |
| `icon` | text | |
| `sort_order` | integer | |
| `archived` | boolean | 軟刪,交易引用不斷鏈 |

- 使用者首次使用財務功能時種預設分類(支出:餐飲/交通/購物/娛樂/居住/醫療/其他;收入:薪資/獎金/利息/其他)
- 僅一層,不做子分類
- 預留但本期不建:預算表、資產科目表、分帳欄位(`group_id`/`splits`)

## API(Firebase token auth,user 隔離)

```
GET    /finance/transactions?from=YYYY-MM-DD&to=YYYY-MM-DD
POST   /finance/transactions
PUT    /finance/transactions/:id
DELETE /finance/transactions/:id

GET    /finance/categories
POST   /finance/categories
PUT    /finance/categories/:id          # 改名/icon/排序/封存

GET    /finance/summary?month=YYYY-MM   # 總支出/總收入/結餘、按分類小計、按幣別分列
```

- `summary` 後端彙總,前端不抓整月明細自行加總
- 分類刪除一律 `archived` 軟刪

## 前端(Flutter)

**入口:** 首頁 hub(`/`,`home_screen.dart`)加「財務」tile,平行於 health-tile,push `/finance`。

**Shell:** `finance_scaffold` + 財務自己的底部 nav,本期兩格:總覽/明細(後續 sub-project 加分帳/淨值格)。

**頁面:**
1. **總覽** `/finance` — 本月支出/收入/結餘卡片、分類統計圖(fl_chart)、最近 5 筆、月份切換箭頭
2. **明細** `/finance/transactions` — 按日分組列表、月份選擇、類型/分類篩選
3. **記一筆** — bottom sheet(mobile 鍵盤 gotcha:不用 AlertDialog),FAB 開啟:金額數字鍵盤、支出/收入切換、分類 grid、日期預設今天、幣別預設 TWD 可換、備註

**路由:** go_router 巢狀路由,照 `/health` 子樹模式(#70/#71),web 返回鍵正常。

**架構:** `lib/contexts/finance/`,domain/application/infrastructure/presentation 四層,照 hydration 模式。

## 錯誤處理

- 金額 ≤0、缺分類:前端表單擋 + 後端 zod 驗證
- API 失敗:照 `async_state_scaffold` 模式,錯誤畫面+重試;寫入失敗 snackbar,不吞錯
- 幣別代碼白名單(常用清單,非自由文字)

## 測試

重要邏輯必須覆蓋:

- 後端(vitest):交易 CRUD、user 隔離(A 拿不到 B 的資料)、summary 彙總含跨幣別分列、分類軟刪後交易仍可讀
- 前端:記一筆表單驗證、明細按日分組、總覽卡片數字;controller test 照現有模式
- 日期時間相關改動:`TZ=UTC flutter test` 複驗(本機 UTC+8 / CI UTC)

## 驗收標準

記一筆 → 明細出現 → 總覽數字更新 → 重整不掉資料;全測試綠(看到 `All tests passed!`)。
