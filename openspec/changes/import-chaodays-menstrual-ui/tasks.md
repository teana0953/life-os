# Tasks

## 1. Port + adapter (TDD)

- [ ] Test first：`test/contexts/import/infrastructure/` 比照既有 —— `importMenstrual` 打 `/api/import/chaodays/menstrual`、body 四個欄位、回應 `{imported, skipped}` 解析。**錯誤映射不用重測**：401/400/502 都在共用的 `_import` helper 裡，既有只用 `importWeight` 測一次，per-type 測試（water/bowel）只驗 URL 與 parse —— 照那個規模做。
- [ ] `domain/import_repository.dart` 加 `importMenstrual`
- [ ] `infrastructure/http_import_repository.dart` 實作，`parse: _parseCounts`（**不要**新造 parser：後端回的是 `imported`/`skipped`，與 weight/water/bowel 同形）

## 2. Application use case

- [ ] `lib/contexts/import/application/import_menstrual.dart`，比照 `import_water.dart`。**controller 注入的是 use case 不是 port** —— 少了這層，實作會想把 repository 直接塞進 controller，違反依賴規則。
- [ ] `lib/main.dart` 的 `ChaodaysImportController(...)` 加第六個位置參數

## 3. Controller (TDD)

- [ ] `ImportType` 加 `menstrual`（**放最後**：`values` 的順序就是畫面順序，插在中間會改動既有五列的位置。已確認沒有任何地方用 `.index` 或持久化 enum 名字）
- [ ] `_import` 的 `switch` 加 case
- [ ] Test：**把 `controller_test` 既有那條寫死五種順序的斷言改成六種**（`_import` helper 預設 `types: ImportType.values.toSet()`，所以那條就是「switch 有真的打出去」的證明 —— 光加 case 而沒接上 use case 會讓它紅）
- [ ] Test：`types: {ImportType.menstrual}` → 只有 menstrual 被呼叫。一條同時涵蓋「有選會跑」與「沒選不跑」；只寫後者容易恆綠
- [ ] Test：menstrual 失敗時該列 `failed`

## 4. 畫面 + l10n

- [ ] `_TypeResultRow._label` 加 case
- [ ] `lib/l10n/app_zh.arb` + `app_en.arb` + **`app_zh_Hant.arb`** 加 `importTypeMenstrual`（zh：生理期 / en：Menstrual periods）。en 檔要有 `@importTypeMenstrual` 描述。zh_Hant 行為上會繼承 zh，但三檔同步是既有慣例
- [ ] Widget 測試：畫面上看得到那一列、勾選可切換。**假 summary 的數字要避開既有測試用過的值** —— `screen_test` 用 `findsOneWidget` 找 `importResultSummary(...)`，撞號會讓既有測試無辜變紅

## 5. 必然要跟著改的既有測試（不是退化）

- [ ] `controller_test:148`、`screen_test:347`、`screen_test:920` 三處寫死 `['weight','diet','water','bowel','dietTarget']` 的 runtime 斷言 → 加 menstrual
- [ ] 三個 fake `ImportRepository` / controller helper 補新方法與參數（編譯期會擋，不會漏）
- [ ] 這些是「多一種型別的必然結果」，不是退化。**真正的退化訊號是：有測試變紅而它跟型別數量無關。**

## 6. Gate

- [ ] `flutter analyze` 零 issue、`flutter test` 全綠。基準 **1166 passed / 1 skipped**，加了新測試後總數必然 > 1166

## 7. On-device verification (manual — 需使用者，部署後)

- [ ] 匯入畫面看得到「生理期」列，勾選狀態正常
- [ ] 匯一段有生理期紀錄的區間，確認數字正確、生理期頁面看得到資料
- [ ] 只勾生理期、其他都不勾 → 只有那一列跑
