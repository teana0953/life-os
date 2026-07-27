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
  - 匯入進行中五個 `Checkbox` 都還在，但 `onChanged == null`、點整列也不會翻勾（停用，不是撤掉）
  - 匯入進行中，未選的類型顯示未勾的勾選框、已選但還沒輪到的顯示打勾的勾選框 —— 兩者靠勾選框本身就區分得開
  - 跑完後每列的狀態圖示（✓／✗／空心圈）與勾選框並存；跑完後選擇維持不變（不重置回全選）
  - 每一列的 semantics 是**一個** label 恰為類型名、帶 checked 狀態的節點
  - **一輪匯入結束後（全部成功、以及中途失敗兩種情況）勾選框都恢復可改，可以改選再送出** —— 這是 proposal 點名的主要情境，per-type 狀態驅動的寫法會在這裡壞掉
- [x] `ChaodaysImportScreen`: state 持有 `Set<ImportType> _selected`（初值全部）；`_canSubmit` 加上 `_selected.isNotEmpty`；`_submit` 傳 `_selected`。
- [x] `_TypeResultRow`: 加 `selected` / `onSelectedChanged` / `selectable`，改用 `CheckboxListTile`（`controlAffinity: leading`、狀態圖示放 `secondary`、`enabled` 跟著 `onChanged` 走、標題明寫 `colorScheme.onSurface`）。`onChanged` 在 **`selectable`（= 非匯入中）** 時給值、否則 null。**不要用 `TypeState.status` 決定** —— 一輪跑完後五列都是 `success`，勾選框會整組鎖死。
- [x] 狀態圖示（成功 ✓／進行中轉圈）在淺色主題改用 `app_theme.dart` 的 `importSuccessIconColor` / `importRunningIconColor`：pastel `tertiary` / `primary` 在 cream 卡片上只有 1.28:1 / 1.64:1，而 trailing 現在是成敗的常駐載體，非文字圖形需要 3:1。深色主題維持既有 pastel。
- [x] `ChaodaysImportController.import` 進來就 `types.toSet()` —— screen 交的是它自己的可變集合，而迴圈跨 await 惰性讀它。
- [x] l10n: **不需要新字串** —— 勾選框以既有的 `importTypeWeight` 等類型名稱為標籤。順手修正 `@importDoneMessage.description` 裡已過時的敘述（它還在講固定跑全部類型）。

## 3. Gate
- [x] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠，既有 import 測試在「全選」語意下維持通過。

## 4. On-device verification (manual — 需使用者，部署後)
- [ ] 只勾「飲食」跑一次匯入，確認其他四種完全沒被動到（不是顯示失敗）。
- [ ] 跑完一輪後直接改選另一種再跑，確認勾選框還在、可以改。
- [ ] 匯入進行中看一眼：沒選的類型與已選但還沒輪到的類型，靠停用狀態的勾選框（未勾 vs 打勾）在深色與淺色主題下是否都分得出來 —— 兩者的 trailing 同為空心圈，差異只在勾選框，而 Material 會把停用狀態渲染得偏淡。
