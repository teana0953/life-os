# Tasks

> 分批（長區間切成半年一批）**不在本 change** —— 它落在後端 repo 的對應 change，
> 理由見 proposal.md（前端分批會讓 `signIn` 次數變成批數×類型數）。

## 1. Controller: 只跑選中的類型 (TDD)
- [x] Test first (red)，用既有的 fake use cases：
  - 只選一種時，只有那一種的 use case 被呼叫；其餘四種的 fake **完全沒被呼叫**，且 `typeStates` 維持 `notAttempted`
  - 選兩種時，兩種都跑，且順序仍照 `ImportType.values`（顯示順序不因選擇而變）
  - 選中的類型裡有一個失敗 → 既有語意不變（停在該處、狀態映射照舊、後面的選中類型不再跑）
  - 至少一種成功仍 bump `DataRevision`；一種都沒成功則不 bump
- [x] `ChaodaysImportController.import` 加一個 **required** 的 `Set<ImportType> types` 具名參數（不給預設值：預設值會讓漏傳的呼叫端靜默跑全部，測試也就抓不到）。迴圈改成 `ImportType.values.where(types.contains)`。
- [x] 更新呼叫端 —— 全 repo 只有兩處 `controller.import(`：`lib/contexts/import/presentation/chaodays_import_screen.dart` 與 `test/contexts/import/presentation/chaodays_import_controller_test.dart` 的 `_import` helper（傳全選以保持既有測試語意）。`chaodays_import_screen_test.dart` 與 `test/app_test.dart` 只建構 controller、簽名不變，預期零改動。

## 2. Screen: 勾選 + 送出條件 (TDD)
- [x] Test first (red)：
  - 首次 build 五個類型全部勾選
  - 全部取消勾選後送出按鈕停用（帳密與日期都填妥的情況下）
  - 只勾一種時送出，controller 收到的集合就只有那一種
  - 匯入進行中該列顯示狀態圖示、**沒有** `Checkbox`（不是 disabled 的 checkbox —— 匯入中根本不渲染它）
  - 匯入進行中，未選的類型整列以較低不透明度呈現，與「已選但還沒輪到」區分得開
  - **一輪匯入結束後（全部成功、以及中途失敗兩種情況）勾選框都回來，可以改選再送出** —— 這是 proposal 點名的主要情境，per-type 狀態驅動的寫法會在這裡壞掉
- [x] `ChaodaysImportScreen`: state 持有 `Set<ImportType> _selected`（初值全部）；`_canSubmit` 加上 `_selected.isNotEmpty`；`_submit` 傳 `_selected`。
- [x] `_TypeResultRow`: 加 `selected` / `onSelectedChanged` / `selectable`。leading 在 **`selectable`（= 非匯入中）** 時顯示 `Checkbox`，否則顯示既有狀態圖示。**不要用 `TypeState.status` 決定** —— 一輪跑完後五列都是 `success`，勾選框會整組消失。
- [x] 匯入中，未選的類型與「已選但還沒輪到」的 leading 目前都是 `circle_outlined`，使用者分不出「這個不會跑」和「這個等一下會跑」。未選的整列降低不透明度來區分（純視覺，不新增狀態）。
- [x] l10n: **不需要新字串** —— 勾選框以既有的 `importTypeWeight` 等類型名稱為標籤。順手修正 `@importDoneMessage.description` 裡已過時的敘述（它還在講固定跑全部類型）。

## 3. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠，既有 import 測試在「全選」語意下維持通過。

## 4. On-device verification (manual — 需使用者，部署後)
- [ ] 只勾「飲食」跑一次匯入，確認其他四種完全沒被動到（不是顯示失敗）。
- [ ] 跑完一輪後直接改選另一種再跑，確認勾選框還在、可以改。
