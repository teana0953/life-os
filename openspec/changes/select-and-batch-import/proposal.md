## Why

[issue #86](https://github.com/loftapartment/life-os/issues/86)：「可以選擇要匯入哪些資料 —— 匯入太長的時間區間，會被對方的 server 擋住」。

`ChaodaysImportController.import` 目前把五種類型（體重／飲食／飲水／排便／飲食目標）**固定全跑**，每個類型對整段 `[startDate, endDate]` 打**一個** request（`http-chaodays-client.ts` 直接把日期放進 chaodays 的 query）。第一個失敗就停、整體轉 `unavailable`。

於是兩件事都做不到：想只補匯某一種資料時得五種全跑；區間一長就被 chaodays 擋下來，而且沒有任何降級 —— 整批失敗。

## What Changes

- **新增 `lib/contexts/import/domain/date_range_batches.dart`**：純函式，把 `[start, end]` 切成每批最多 **183 天**的連續、不重疊、不遺漏的子區間。用固定天數而非月曆上的 6 個月 —— 月曆加法有月底空洞（8/31 + 6 個月沒有 2/31），切點會隨起始日漂移。183 天是使用者依實際經驗指定的值，不是量測出的上限；若仍被擋，改這個具名常數即可。
- **`ChaodaysImportSummary` 加合併**：一個類型的多批結果合併成一筆。`imported`/`skipped` 相加；可空的 `glucoseImported`/`waterTargetsImported` **只要任一批非 null 就相加，全 null 才維持 null**，否則某批剛好沒有血糖資料會把整個類型的數字抹成 null。
- **`ChaodaysImportController`**：`import` 接受要跑的類型集合；對每個選中的類型依序跑完它的所有批次（type-major）再換下一個；`TypeState` 帶批次進度。失敗語意不變 —— 停在第一個失敗，已寫入的批次保留（匯入是逐日 upsert、可重跑，重跑時會落在 `skipped`）。
- **`ChaodaysImportScreen`**：五個類型各自可勾選，預設全選；全不選時送出停用。勾選框放在既有的 `_TypeResultRow` 上（取代匯入前的灰色圈圖示），不另開卡片 —— 否則畫面會有兩份相同的類型清單。匯入中顯示 `第 n／共 m 批`，批次數為 1 時不顯示。

**後端完全不動。** 切分放在前端而不是後端：後端跑在 Cloudflare Workers，單一 request 有 subrequest 與時間上限，把 N 批塞進一次呼叫等於把「長區間被 chaodays 擋」換成「Worker 逾時」；前端切則是每批一次獨立呼叫，各自完整，進度也能逐批回報。

切分與合併都是純函式（domain 層，單元測試直接覆蓋），controller 只負責編排。`ImportRepository` 介面不變。前端 only；新增批次進度文案（ARB ×3）。Gate = lint + `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `chaodays-import-ui`: 匯入 SHALL 讓使用者選擇要匯入哪些資料類型，且 SHALL 把過長的日期區間自動分批送出，而不是讓整批失敗。
