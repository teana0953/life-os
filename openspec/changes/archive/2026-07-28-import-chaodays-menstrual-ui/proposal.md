## Why

後端已支援生理期匯入（[life-os-backend PR #55](https://github.com/loftapartment/life-os-backend/pull/55)，issue #85），端點 `POST /api/import/chaodays/menstrual` 已上線，但匯入畫面上還沒有這一列 —— 使用者看不到入口。這個 change 補上前端的最後一段。

## What Changes

第六種匯入類型，走既有五種一模一樣的路徑：

- `ImportType` 加 `menstrual`（放在最後）。
- `ImportRepository` 加 `importMenstrual`，`HttpImportRepository` 打 `/api/import/chaodays/menstrual`，回應用既有的 `_parseCounts`（後端回 `{imported, skipped, from, to}`，與 weight/water/bowel 同形）。
- `ImportMenstrual` use case（`application/`，比照 `import_water.dart`）—— controller 注入的是 use case 不是 port，`lib/main.dart` 的 DI 跟著加第六個參數。
- `ChaodaysImportController` 的 `switch` 加一個 case。
- `_TypeResultRow._label` 加一個 case，l10n 加 `importTypeMenstrual`（zh：生理期）。

型別列是 `ImportType.values` 自動渲染的，所以勾選、進度圖示、失敗訊息、無障礙描述全部自動沿用。

**不加任何說明文字。** 後端會跳過「還沒結束」的生理期（寫成 lifeos 的開放期間會永久壓住之後所有匯入），但 summary 只有 imported/skipped 兩個數字。

也評估過條件式後綴（`_resultText` 已經有這個機制：glucose 與 waterTarget 都只在非 null 時才接，所以只在 `skipped > 0` 時附一句的成本是一個 ARB key 加一個 `if`，`skipped == 0` 時完全不出現）。不做的理由不是成本，是**措辭**：跳過的原因可能是「已經有重疊的紀錄」也可能是「這次還沒結束」，一句話要同時涵蓋兩者就只能含糊到沒有資訊量。要講清楚得讓後端分開回報兩種 skipped —— 那是後端的 change。列為 follow-up。

Gate = `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `chaodays-import-ui`: 匯入畫面 SHALL 提供生理期匯入類型，與既有五種共用同一套流程、憑證處理與錯誤呈現。
