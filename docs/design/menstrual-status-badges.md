# 生理期狀態徽標:首頁磚塊與追蹤卡呈現

- **uiux id**:life-os-ux236
- **專案**:life-os
- **來源**:https://github.com/teana0953/life-os/issues/236 (延伸範圍:首頁健康總覽磚塊與生理期追蹤卡如何跟日曆的週期第幾天標記連動)
- **平台**:web
- **design system**:docs/design-system.md(本次新增)
- **產出日期**:2026-08-29

## 需求理解
issue #236「[生理期] 支援顯示週期第幾天」的延伸範圍。原提案(menstrual-cycle-day-marker change)已核可,只動日曆(MenstrualCalendar)逐格顯示週期第幾天。本次要讓首頁健康總覽磚塊(home-menstrual-prediction tile)與健康總覽的生理期追蹤卡(NextPeriodCard)跟日曆的視覺語彙連動一致,並修正首頁磚塊「有些狀態沒有顯示具體日期」的缺陷。

## 需求(經三輪 mockup 迭代確認)

`computeNextPeriodStatus` 現有六種狀態(NextPeriodState),要讓首頁磚塊與追蹤卡都用「圓形徽標 + 明確日期」呈現,徽標配色沿用日曆既有的兩種標記樣式,不新發明第三套配色:

1. **ongoing(進行中)**:實心藍色圓形徽標「N天」(呼應日曆經期日 filled marker,色=hachiwareBlue)。首頁磚塊第二行補上「{本次開始日} 開始」的日期(目前完全沒有日期,是本次修正的缺陷之一)。追蹤卡左側加同款徽標,主文字改「進行中」,副文字保留「下次預計 {date}」(若有)。
2. **upcoming(還有幾天)**:空心藍框圓形徽標「N天」(呼應日曆預測日 outline marker)。首頁磚塊/追蹤卡本來就有日期,維持,徽標是新增的視覺呼應。
3. **today(預測日=今天)**:中性 outline 色實心徽標「今天」。首頁磚塊補上明確日期行(=predictedNextStart,不需要加「(=今天)」後綴,因主文字已經說「預計今天」)。
4. **overdue(已逾期)**:空心 honey 警示色圓框徽標「逾N天」(色=honeyWarning/financeBudgetWarningTextLight,現有 app_colors.dart 既有 token,非新色)。首頁磚塊第二行補上「預計 {date}」(目前完全沒有日期,是本次修正的缺陷之二)。首頁磚塊卡片外框連動變成 warning 色系。追蹤卡左側加同款徽標,主文字改「已逾期」,新增一行說明「已超過預測日 N 天」。
5. **needsOneMore(只有一筆紀錄)**:無變更——本來就沒有任何預測日期可顯示(需兩次記錄才能算週期),不是缺陷。
6. **noRecords(完全沒有紀錄)**:無變更,同上理由。

## 範圍外項目

- 不重新設計日曆本身(menstrual-cycle-day-marker change 已定案的部分)。
- 不改動 domain/application/infrastructure 層或後端 API——徽標與日期都是既有 `MenstrualStats`/`NextPeriodStatus` 資料的呈現方式改變,不需新欄位。
- 不改變 `computeNextPeriodStatus` 的狀態機或優先順序邏輯本身。
- 不改變首頁磚塊/追蹤卡的導覽行為(點擊仍開生理期追蹤畫面)。

## 已確認的視覺對照表(供 UI Spec 引用)

| 狀態 | 徽標樣式 | 顏色 | 首頁磚塊第二行日期 |
|---|---|---|---|
| ongoing | 實心圓 | primary(hachiwareBlue) | {本次開始日} 開始 |
| upcoming | 空心圓框 | primary(hachiwareBlue) | 預計 {predictedNextStart} |
| today | 實心圓 | outline 中性色 | {predictedNextStart} |
| overdue | 空心圓框 | warning(honeyWarning 系) | 預計 {predictedNextStart} |
| needsOneMore | 無徽標 | — | 無日期可顯示(維持原樣) |
| noRecords | 無徽標 | — | 無日期可顯示(維持原樣) |

## User Flow

```mermaid
flowchart TD
    A[使用者開啟首頁 HomeScreen] --> B{menstrual arm 狀態<br/>ArmSlot.status}
    B -->|loading 尚未取得| B1[磚塊值區顯示 hourglass + 載入中<br/>不顯示徽標與日期]
    B -->|failed 且無舊值| B2[磚塊值區顯示 cloud_off + 載入失敗<br/>整區可點 = 單臂重試 home-menstrual-prediction-retry]
    B -->|failed 但有舊值| B3[保留舊徽標與日期 + 右側 error 色 cloud_off 標記]
    B -->|loaded| C{computeNextPeriodStatus 六態}

    C -->|ongoing| C1["實心徽標「N天」+ 第二行「{開始日} 開始」<br/>開始日 = today - days + 1"]
    C -->|upcoming| C2[空心藍框徽標「N天」+「預計 {predictedNextStart}」]
    C -->|today| C3[中性 outline 實心徽標「今天」+「{predictedNextStart}」]
    C -->|overdue| C4[空心 warning 框徽標「逾N天」+「預計 {predictedNextStart}」<br/>磚塊外框改 warning 色]
    C -->|needsOneMore| C5[無徽標,文案「再記錄一次即可預測」<br/>無日期,維持原樣]
    C -->|noRecords| C6[無徽標,文案「無資料」<br/>無日期,維持原樣]

    C1 & C2 & C3 & C4 & C5 & C6 --> T[點擊磚塊 InkWell]
    B3 --> T
    T --> M[context.push '/health/menstrual'<br/>生理期追蹤畫面]

    A2[使用者開啟健康總覽 HealthScaffold] --> D{MenstrualController.status}
    D -->|overview == null| D1[LedgeCard + CardLoading<br/>next-period-loading]
    D -->|error 且 overview == null| D2[LedgeCard + CardErrorRetry<br/>next-period-retry]
    D -->|有 overview| E[NextPeriodCard 依同一組六態渲染<br/>左徽標 + 主文字 + 副文字]
    E -->|同時 error/loading/refreshing| E1[卡片下方掛 StaleNotice 單卡重試]
    E --> F[點擊 next-period-card InkWell]
    F --> M

    M --> G[MenstrualCalendar 逐格顯示<br/>日期 + 週期第幾天 小字]
    G -.視覺語彙對應.-> C1
    G -.視覺語彙對應.-> C2
```=== UX

## UX

### 資訊架構(三處如何呼應)

同一個 `computeNextPeriodStatus` 結果,三種資訊密度的漸進揭露:

| 位置 | 角色 | 顯示深度 |
|---|---|---|
| 首頁磚塊 `home-menstrual-prediction` | **一瞥**(和另外 7 個磚塊並排) | 徽標(狀態+數字)+ 一行日期 |
| 健康總覽 `NextPeriodCard` | **一句**(整寬卡) | 徽標 + 狀態主文字 + 日期/說明副文字 |
| 追蹤畫面 `MenstrualCalendar` | **全貌** | 每一格的日期 + 週期第幾天,加圖例 |

視覺語彙唯一化:**填色圓 = 已發生/正在發生的經期日**(日曆 `isPeriod` filled marker,`color.primary`);**空心圓框 = 預測**(日曆 `isPredicted` outline marker,`color.primary` 2dp 框)。首頁/追蹤卡的徽標直接沿用這兩型,不新增第三型;overdue 只是把空心框的顏色從 primary 換成 warning,形狀語意(=預測)不變 —— 這正是 overdue 的語意(預測日已過但未被證實)。`today` 用 outline 中性實心,對應日曆上「今天」用 `color.outline` 細框的既有慣例。

### 互動狀態(loading / empty / error / success × 六態)

**loading**(共同):
- 磚塊:`_statusLine` hourglass + `cardRefreshing`,**不畫徽標**(徽標位置屬 figure,`hasValue == false` 時整區被換掉)。維持既有等高契約。
- 追蹤卡:`overview == null` → `LedgeCard` + `CardLoading`(`next-period-loading`)。

**error**:
- 磚塊冷失敗(無舊值):`_statusLine` cloud_off +「載入失敗」+ 整行即重試。**徽標與日期都不顯示** —— 不得讓失敗畫成「無資料」或畫成舊徽標。
- 磚塊熱失敗(有舊值):徽標與日期照舊畫,右側 `_valueMarker` 以 `color.error` 標示過時 + 可重試。
- 追蹤卡冷失敗:`CardErrorRetry`;熱失敗:內容保留 + `StaleNotice`。

**empty**:
- `noRecords`:磚塊 `homeNoData`,追蹤卡 `nextPeriodNoRecords`。**無徽標、無日期**(本次不變)。
- `needsOneMore`:磚塊 `homeMenstrualNeedsMore`,追蹤卡 `nextPeriodNeedsOneMore`。**無徽標、無日期**(本次不變)。
- 兩者的徽標欄位整個不佔位(不畫空圓),否則會讀成「0 天」。

**success**(四個有變化的態):

| 狀態 | 磚塊徽標 / 第二行 | 追蹤卡徽標 / 主文字 / 副文字 |
|---|---|---|
| ongoing | 實心「N天」/「{開始日} 開始」(**新增,現況缺失**) | 實心「N天」/「進行中」/「下次預計 {date}」(僅在 `predicted != null && daysBetween(now, predicted) > 0` 時,沿用現有 `showsPrediction` 判斷) |
| upcoming | 空心藍「N天」(新增徽標)/「預計 {date}」(既有) | 空心藍「N天」/ 現有 `nextPeriodUpcoming` 拆為「還有 N 天」/「預計 {date}」 |
| today | 中性實心「今天」/「{date}」(**新增日期行**,不加「(=今天)」後綴) | 中性實心「今天」/「預計今天」/ 無副文字 |
| overdue | 空心 warning「逾N天」/「預計 {date}」(**新增,現況缺失**)+ **磚塊外框改 warning 色** | 空心 warning「逾N天」/「已逾期」/「已超過預測日 N 天」(**新增說明行**) |

### 可及性

- 徽標一律 `ExcludeSemantics`,由外層容器提供**完整句子**,禁止讓螢幕閱讀器讀到裸數字。首頁磚塊走既有的 `valueSemanticLabel` 管道(`_SnapshotTile._figure` 已有 `Semantics(label:) + ExcludeSemantics` 的既成模式),避免「4」「今天」這種孤立詞。
- 建議語句形態(新增 ARB key,英文模板需 `description`):
  - ongoing:「生理週期預測:進行中,第 4 天,7月2日開始」
  - upcoming:「生理週期預測:還有 6 天,預計 7月28日」
  - today:「生理週期預測:預計今天,7月28日」
  - overdue:「生理週期預測:已逾期,已超過預測日 3 天,預計 7月25日」
  - needsOneMore / noRecords:沿用現有文案,不加徽標語意。
- overdue 的 warning 外框**不得是唯一訊號**:徽標內已有「逾N天」文字 + 第二行日期,顏色只是加成(符合本 repo「pastel 只作邊框/填色,不作前景文字」與「有字就不靠顏色」的既定原則,見 `_statusLine` 的註解)。
- 追蹤卡新增的「已超過預測日 N 天」說明行,與主文字同屬一個 `Semantics` 容器順序朗讀,不另建 focus node。
- 文字縮放:徽標內文字必須跟 `MenstrualCalendar` 標記一樣採上限箝制(design.md 決策 2 用 `TextScaler.clamp(maxScaleFactor: 1.3)`),否則圓形徽標在 2× 會撐破;箝制只作用在徽標內,日期行不箝制。
- 首頁磚塊第二行的加入會改變磚塊高度契約,**必須同步更新** `home_screen_responsive_test.dart` 的等高守衛(R3 系列),且六態之間磚塊高度必須一致(needsOneMore/noRecords 無第二行時需佔位或全體改為 `minHeight` 提高),否則會重現註解中記載的「磚塊在不同狀態間變高、點擊落到錯誤目標」事故。=== WIREFRAME

## Wireframe

### A. 首頁磚塊 `home-menstrual-prediction`(`_SnapshotTile`,`_DashboardSection` 的 `Wrap` 子項)

```
ongoing                              upcoming
┌────────────────────────────────┐   ┌────────────────────────────────┐
│ 生理週期預測                    │   │ 生理週期預測                    │
│ [_SnapshotTile / label 列]      │   │                                │
│                                │   │                                │
│ (●4天) 生理期第 4 天            │   │ (○6天) 還有 6 天                │
│  ↑新元件:CycleBadge(filled)     │   │  ↑新元件:CycleBadge(outline)    │
│  [_tileValue FittedBox 單行]    │   │                                │
│ 7月2日 開始                     │   │ 預計 7月28日                    │
│  ↑新元件:TileSecondaryLine      │   │  ↑新元件:TileSecondaryLine      │
└────────────────────────────────┘   └────────────────────────────────┘
 外框 = _SnapshotTile 既有 outline     外框 = 既有 outline

today                                overdue
┌────────────────────────────────┐   ╔════════════════════════════════╗
│ 生理週期預測                    │   ║ 生理週期預測                    ║
│                                │   ║                                ║
│ (◍今天) 預計今天                │   ║ (○逾3天) 預測日已過 3 天        ║
│  ↑CycleBadge(filled, 中性)      │   ║  ↑CycleBadge(outline, warning)  ║
│                                │   ║                                ║
│ 7月28日                        │   ║ 預計 7月25日                    ║
└────────────────────────────────┘   ╚════════════════════════════════╝
                                      外框 = warning 色(本狀態唯一變化)

needsOneMore(不變)                  noRecords(不變)
┌────────────────────────────────┐   ┌────────────────────────────────┐
│ 生理週期預測                    │   │ 生理週期預測                    │
│                                │   │                                │
│ 再記錄一次即可預測              │   │ 無資料                          │
│ (無徽標)                        │   │ (無徽標)                        │
│ (第二行留白佔位,保持等高)       │   │ (第二行留白佔位,保持等高)       │
└────────────────────────────────┘   └────────────────────────────────┘

loading / cold-error(既有,不變)
┌────────────────────────────────┐   ┌────────────────────────────────┐
│ 生理週期預測                    │   │ 生理週期預測                    │
│ ⧗ 更新中…  [_statusLine]        │   │ ☁ 載入失敗 · 重試 [_statusLine] │
│ (無徽標、無第二行)               │   │ (整行即 retry InkWell)          │
└────────────────────────────────┘   └────────────────────────────────┘
```

### B. `NextPeriodCard`(`LedgeCard` 內)

```
ongoing
┌──────────────────────────────────────────────────────┐  LedgeCard
│  下次生理期                     [textTheme.titleLarge]│
│  ┌────┐                                              │
│  │ ●  │ 進行中                       [titleMedium]  ›│  新元件:CycleBadge(filled)
│  │4天 │ 下次預計 7月28日             [bodyMedium]    │  ›= Icon(chevron_right)
│  └────┘                                              │      next-period-open-icon
└──────────────────────────────────────────────────────┘

upcoming
┌──────────────────────────────────────────────────────┐
│  下次生理期                                          │
│  ┌────┐                                              │
│  │ ○  │ 還有 6 天                                   ›│  CycleBadge(outline, primary)
│  │6天 │ 預計 7月28日                                 │
│  └────┘                                              │
└──────────────────────────────────────────────────────┘

today
┌──────────────────────────────────────────────────────┐
│  下次生理期                                          │
│  ┌────┐                                              │
│  │ ◍  │ 預計今天                                    ›│  CycleBadge(filled, outline 中性)
│  │今天│ (無副文字)                                   │
│  └────┘                                              │
└──────────────────────────────────────────────────────┘

overdue
┌──────────────────────────────────────────────────────┐
│  下次生理期                                          │
│  ┌────┐                                              │
│  │ ○  │ 已逾期                                      ›│  CycleBadge(outline, warning)
│  │逾3 │ 預計 7月25日                                 │
│  │ 天 │ 已超過預測日 3 天            [新增說明行]     │
│  └────┘                                              │
└──────────────────────────────────────────────────────┘

needsOneMore / noRecords(不變,無徽標)
┌──────────────────────────────────────────────────────┐
│  下次生理期                                          │
│  再記錄一次就能預測下次 / 還沒有生理期紀錄          ›│
└──────────────────────────────────────────────────────┘

loading                              cold error
┌──────────────────────────┐         ┌──────────────────────────┐
│      CardLoading         │         │  CardErrorRetry          │
│  next-period-loading     │         │  next-period-retry       │
└──────────────────────────┘         └──────────────────────────┘

任一狀態 + 重新載入中/失敗
└─ StaleNotice(既有,掛在 InkWell 外、LedgeCard 內)
```=== UI_SPEC

## UI Spec

### 新元件:CycleBadge(圓形徽標)

| 項目 | Token |
|---|---|
| 直徑 | `size.marker`(32dp,與日曆日格標記共用同一直徑) |
| 形狀 | `BoxShape.circle` |
| 邊框寬度(空心型) | `border.width` |
| 徽標內文字字級 | `text.label-small` |
| 徽標內文字顏色(實心 primary 型,ongoing) | `color.on-primary` |
| 徽標內文字顏色(空心 primary 型,upcoming) | `color.ink`(不用 `color.primary`——pastel 前景違反硬性約束;圖形語意由框色承載,文字色不必跟色系) |
| 徽標內文字顏色(實心中性型,today) | `color.ink` |
| 徽標內文字顏色(空心 warning 型,overdue) | `color.finance-budget-warning-text`(經 `financeBudgetWarningColor(scheme)`) |
| 文字縮放上限 | 沿用 `menstrual-cycle-day-marker/design.md` 決策 2 的 1.3× 箝制(既有無障礙決策,非新 token) |

### 四種狀態的顏色對應

| 狀態 | 徽標填色 | 徽標框色 | 徽標文字色 |
|---|---|---|---|
| ongoing(實心) | `color.primary` | 無 | `color.on-primary` |
| today(實心) | `color.outline` | 無 | `color.ink` |
| upcoming(空心) | 無 | `color.primary` | `color.ink` |
| overdue(空心) | 無 | `color.warning` | `color.finance-budget-warning-text` |

### 首頁磚塊

| 項目 | Token |
|---|---|
| 磚塊外框(一般狀態) | `color.outline` × `border.width-thin` |
| 磚塊外框(overdue) | `color.warning` × `border.width-thin` |
| 磚塊圓角 | `radius.tile` |
| 磚塊內距 | `space.tight-padding` |
| 標籤文字 | `text.body-small` |
| 主值文字 | `text.title-medium` |
| 徽標與主值之間水平間距 | `space.stack-xs` |
| 主值與第二行日期之間垂直間距 | `space.stack-2xs` |
| 第二行日期文字 | `text.body-small`,色 `color.ink-muted` |
| 磚塊最小高度 | `size.tile-min-height`(估計值,實作階段須以 `real_font_metrics_test.dart` 覆核六態等高後才能定案,見 design system「尺寸」章節註記) |
| 磚塊間距(grid gutter) | `space.tile-gutter` |

### NextPeriodCard

| 項目 | Token |
|---|---|
| 卡片容器 | `LedgeCard`(`radius.ledge-card`、`border.width`、`shadow.ledge`) |
| 卡片內距 | `space.card-padding` |
| 標題文字 | `text.title` |
| 徽標與文字欄之間水平間距 | `space.stack-md` |
| 標題與主文字之間 | `space.stack-xs` |
| 主文字 | `text.title-medium` |
| 主文字與副文字之間 | `space.stack-2xs` |
| 副文字(日期) | `text.body-small`,色 `color.ink-muted` |
| 新增說明行(overdue「已超過預測日 N 天」) | 字級 `text.body-small`,色 `color.ink-muted`,與其上一行間距 `space.stack-2xs` |
| 右側導覽指示 icon 色 | `color.ink-muted` |
| InkWell 圓角 | `radius.ledge-card` |
| 錯誤/載入態內距 | 錯誤 `space.card-padding`、載入 `space.section-padding`(沿用現況) |

### Breakpoint

| 情境 | Token |
|---|---|
| 首頁內容最大寬 | `space.content-max-width` |
| 健康總覽卡片最大寬 | `space.form-max-width` |
| 磚塊單欄 ↔ 雙欄切換 | `bp.section-two-column` |
| 最窄支援寬度驗證基準 | `bp.phone`(320dp 為既有驗證下限;徽標 + 主值 + 第二行必須在此寬度不溢位,尤其 CJK 的「預測日已過 3 天」) |
