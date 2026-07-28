# Tasks

## 1. Port + adapter (TDD)

- [ ] Test first：`test/contexts/import/infrastructure/` 比照既有 —— `importMenstrual` 打 `/api/import/chaodays/menstrual`、body 四個欄位、回應 `{imported, skipped}` 解析、401/400 `chaodays_auth_failed`/502/其他狀態碼的錯誤映射各一條
- [ ] `domain/import_repository.dart` 加 `importMenstrual`
- [ ] `infrastructure/http_import_repository.dart` 實作，`parse: _parseCounts`（**不要**新造 parser：後端回的是 `imported`/`skipped`，與 weight/water/bowel 同形）

## 2. Controller (TDD)

- [ ] Test first：`test/contexts/import/presentation/` —— 選了 menstrual 會呼叫 `importMenstrual` 並填進 `typeStates`；**沒選就不呼叫**；失敗時該列 `failed` 且後續類型 `notAttempted`
- [ ] `ImportType` 加 `menstrual`（**放最後**：`values` 的順序就是畫面順序，插在中間會改動既有五列的位置）
- [ ] `_import` 的 `switch` 加 case（Dart 的 exhaustive switch 會逼你加，但**測試要真的驗到有打出去**）

## 3. 畫面 + l10n

- [ ] `_TypeResultRow._label` 加 case
- [ ] `lib/l10n/app_zh.arb` + `app_en.arb` 加 `importTypeMenstrual`（zh：生理期 / en：Menstrual periods），en 檔要有 `@importTypeMenstrual` 描述（既有慣例）
- [ ] Widget 測試：畫面上看得到那一列、勾選狀態可切換

## 4. Gate

- [ ] `flutter analyze` 零 issue、`flutter test` 全綠，基準 **1166 passed / 1 skipped**，既有測試零退化
- [ ] `flutter gen-l10n` 產物有跟著更新（或確認 build 會自動產）

## 5. On-device verification (manual — 需使用者，部署後)

- [ ] 匯入畫面看得到「生理期」列，勾選狀態正常
- [ ] 匯一段有生理期紀錄的區間，確認數字正確、生理期頁面看得到資料
- [ ] 只勾生理期、其他都不勾 → 只有那一列跑
