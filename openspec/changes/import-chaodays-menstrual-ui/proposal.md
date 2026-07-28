## Why

後端已支援生理期匯入（[life-os-backend PR #55](https://github.com/loftapartment/life-os-backend/pull/55)，issue #85），端點 `POST /api/import/chaodays/menstrual` 已上線，但匯入畫面上還沒有這一列 —— 使用者看不到入口。這個 change 補上前端的最後一段。

## What Changes

第六種匯入類型，走既有五種一模一樣的路徑：

- `ImportType` 加 `menstrual`（放在最後）。
- `ImportRepository` 加 `importMenstrual`，`HttpImportRepository` 打 `/api/import/chaodays/menstrual`，回應用既有的 `_parseCounts`（後端回 `{imported, skipped, from, to}`，與 weight/water/bowel 同形）。
- `ChaodaysImportController` 的 `switch` 加一個 case。
- `_TypeResultRow._label` 加一個 case，l10n 加 `importTypeMenstrual`（zh：生理期）。

型別列是 `ImportType.values` 自動渲染的，所以勾選、進度圖示、失敗訊息、無障礙描述全部自動沿用。

**不加任何說明文字。** 後端會跳過「還沒結束」的生理期（寫成 lifeos 的開放期間會永久壓住之後所有匯入），但 summary 只有 imported/skipped 兩個數字，看不出跳過的原因是重疊還是未結束 —— 所以在那一列常駐一句解釋，在常見情況下只是噪音。列為 follow-up。

Gate = `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `chaodays-import-ui`: 匯入畫面 SHALL 提供生理期匯入類型，與既有五種共用同一套流程、憑證處理與錯誤呈現。
