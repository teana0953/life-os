# 總覽卡的刷新失敗呈現一致化（issue #100）

## 問題

四張總覽卡對「已經有資料了，然後重新載入失敗」各做各的。細節見 proposal。

## 事實盤點

**四個 controller 失敗時都保留舊資料**（`CareTodayController` / `WeightGoalController` / `HealthCalendarController` / `MenstrualController` 的 catch 都只寫 `status`，不碰資料欄位）。所以這純粹是 render 判斷的差異，資料層不用動。

**reload 是批次觸發、但失敗是各自的**：`HealthScaffold._load()` 用 `Future.wait` 並行 13 個 `controller.load()`，每個都在內部 catch、不往外 throw。四張卡打四組不同 endpoint：

| 卡 | endpoint |
| --- | --- |
| `CareTodaySummaryCard` | `/api/care/today` |
| `GoalCard` | `/api/weight-goal` + `/api/body-profile` |
| `HealthCalendarCard` | `/api/health-calendar` |
| `NextPeriodCard` | `/api/menstrual` |

**高度實測**（360px 內容寬、en、預設字級）：

| 卡 | 正常 | 錯誤卡 | 差 |
| --- | --- | --- | --- |
| `CareTodaySummaryCard` | 276 | 276（不變，因為它靜默） | 0 |
| `GoalCard` | 274 | 164 | −110 |
| `NextPeriodCard` | 128 | 164 | +36 |
| `HealthCalendarCard` | 438 | 164 | **−274** |

三張同時失敗，總覽從 1148px 塌到 800px。

## 設計決策

### D1 — 「從未載入」與「刷新失敗」是兩件事，不是不一致

| 情況 | 呈現 | 理由 |
| --- | --- | --- |
| 從未載入、載入中 | 各自的 loading（或 care 的 `SizedBox.shrink()`） | 沒有東西可以留 |
| **從未載入、失敗** | 錯誤 + 重試（**取代內容**） | 沒有內容可留，卡片除了講失敗沒別的事能做 |
| 已有內容、載入中 | 保留內容，**不標記** | #82 的教訓：自動刷新不該打空畫面。而且載入中不是失敗 |
| **已有內容、失敗** | 保留內容 + 標記 + 重試 | 見 D2 |

**兩種失敗的處理不同，不是前後矛盾** —— 決定它們的是「有沒有內容可以留」，而那是客觀的差異。

### D2 — 有內容時保留內容，而不是換成錯誤卡

`GoalCard` 現在的註解明說了相反的話：

> This must not hinge on `goal == null`: a reload that fails after a successful first load would otherwise silently keep showing the stale card.

**那個顧慮成立 —— 在沒有任何訊號的前提下。** 保留舊資料而不說，就是 care 卡現在的問題（使用者無從得知看到的是幾分鐘前的東西）。標記就是那個訊號。

反過來，換成錯誤卡的代價是實測的：把使用者正在讀的東西抽走、版面塌 348px，而**觸發它的多半不是使用者的動作**（匯入完成、回到總覽都會自動 reload）。使用者沒做什麼，畫面自己少了一塊。

所以：**保留內容 + 明說沒更新到**，兩邊的顧慮都答到。

### D3 — 重試的顆粒度是一張卡

四張卡打四組不同 endpoint、各自 catch。單一 endpoint 500 只會讓一張卡舊，這時「重跑整批」會多打三個沒必要的請求。使用者也已經確認要每張卡自己的 refresh。

（曾考慮總覽層一條橫幅 + 重跑整批：在「網路整個斷掉」時比較乾淨，但那時橫幅得點名是哪幾張卡才夠精確，而單卡失敗時它反而比卡上標記難定位。放棄。）

### D4 — 標記放在卡片內容之下

四張卡的版型差異極大（128px 兩行 ↔ 438px 整月月曆 + 三個環）。**尾端是唯一不用動既有版型就能插入的位置** —— 每張卡在 `LedgeCard` 的最後多一列即可。

代價：使用者可能先讀完內容才看到「這是舊的」。放在標題列旁邊會先被讀到，但四張卡的標題列結構全不一樣（care 卡最上面是狀態列不是標題），要各自動刀。**這一條留給 uiux leg 判斷是否值得。**

### D5 — 標記不重用既有的 `error*LoadFailed` 文案

既有那 11 個 key（8 個 `error*LoadFailed` + `healthCalendarLoadFailed` + `trendLoadFailed` + `dietDictionaryLoadFailed`）是「Unable to load X. Please try again.」句型 —— 那是「載不到」，而這裡是「載得到舊的、只是沒更新到」。語意不同，而且那個句型太長，塞不進一列。新增一個共用的 `cardRefreshFailed`（zh：沒有更新到 / en：Couldn't refresh），重試沿用既有的 `retry`。

### D5a — 兩個實作上的坑

**`WeightGoalController.load` 先寫 `goal` 再寫 `profile`。** body-profile 那半失敗時，`goal` 已經被換成**新鮮**資料、狀態卻是 error —— 卡片會顯示新資料 + 「沒有更新到」。標記在那個情況下是錯的（東西其實更新了一半）。這是既有行為，本 change 不修，但**標記的措辭要禁得起它**：講「沒有更新到」而不是「這是舊資料」，前者對「更新了一半」仍然成立。

**`CareTodaySummaryCard._hasLoadedOnce` 只從 `status == loaded` 播種**（`initState` 讀一次、之後每次 loaded 設 true）。重進 health module 時 controller 是 app 級 singleton、可能停在 error 但手上還有 slots —— 新的卡會用「從未載入」的分支蓋掉那些內容。**判斷要改成看資料在不在（`slots.isNotEmpty`），不是看 `_hasLoadedOnce`**，否則這個 change 會製造一個新的「內容被錯誤卡蓋掉」。

### D6 — 401 不動

`HealthScaffold._overviewNeedsReauth` 涵蓋 6 個 controller，401 時整個 `HealthScaffold` 被換成「請重新登入」。卡片層不碰。

## 元件

| 檔案 | 改動 |
| --- | --- |
| `shared/widgets/stale_notice.dart`（新） | 一條窄橫列：文案 + 重試 |
| `contexts/notifications/presentation/care_today_summary_card.dart` | 靜默 → 標記；**首次載入失敗從整張消失改成錯誤卡** |
| `contexts/body_profile/presentation/goal_card.dart` | 錯誤分支加 `goal == null` 條件 |
| `contexts/health_calendar/presentation/health_calendar_card.dart` | 同上 |
| `contexts/menstrual/presentation/next_period_card.dart` | 同上 |
| `l10n/app_{en,zh,zh_Hant}.arb` | `cardRefreshFailed` |

## 測試現況（要補的洞）

| 卡 | 「已有資料 + 重新載入失敗」有測試嗎 |
| --- | --- |
| `GoalCard` | 有（`goal_card_test.dart:187`）—— **斷言的是被取代的行為，要改寫不是刪掉** |
| `CareTodaySummaryCard` | 有（`:295`）—— 斷言靜默保留，要改寫成保留 + 標記 |
| `HealthCalendarCard` | **完全沒有**（全檔只有 3 條測試） |
| `NextPeriodCard` | 沒有（錯誤測試都沒預先塞資料） |

## 不做（YAGNI）

- 趨勢分頁的 `TrendCard` / `CareAdherenceCard` —— 同樣的問題，但不在 #100 範圍。另開。
- 常駐的手動 refresh 按鈕 —— 使用者確認只在失敗時出現。
- 區分「網路斷」與「後端 500」的文案 —— controller 層沒有這個資訊，硬做要往下挖四條 repository。
