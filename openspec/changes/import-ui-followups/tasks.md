# Tasks

> 全部建立在同分支的 `select-import-types` 之上（PR #92）。那個 change 的所有測試
> —— 勾選框常駐、D2 回歸點（跑完後仍可改選再跑）、leading/trailing 位置斷言、
> `enabled` 語意、圖示配色 —— **必須維持通過**。

## 1. Controller: 只清被動到的類型 (TDD)
- [ ] Test first (red)：
  - 清除單一類型只影響那一型，其餘 `typeStates` 不動
  - `import()` 只重置**這輪要跑的**類型；未選類型上一輪的 `TypeState` 原封不動（**D2 的回歸點**：目前是無條件 `_freshTypeStates()`）
  - 既有語意不變：停在第一個失敗、`authFailed` 退回 `notAttempted`、401 → `needsReauth`、`DataRevision` 每輪最多 bump 一次且至少一種成功才 bump
- [ ] `ChaodaysImportController`: 加清除單一類型狀態的方法；`import()` 的重置改成只作用於 `types`。

## 2. Screen: 版面順序與標題 (TDD)
- [ ] Test first (red)：送出按鈕在類型清單**之後**（比較兩者的垂直位置，不是只看存在）；卡片標題存在且用 `labelLarge`。
- [ ] `ChaodaysImportScreen`: 把送出按鈕移到類型卡片之後；類型卡片加標題。維持既有的 `ListView` / `maxWidth: 600` 結構。
- [ ] l10n: 新增卡片標題字串到 `app_en.arb`（含 `description`）+ `app_zh_Hant.arb` + `app_zh.arb`。

## 3. Screen: 改勾選清該列結果 (TDD)
- [ ] Test first (red)：跑完一輪後改動某列的勾選 → 那列的結果文字與狀態圖示消失、其他列的**留著**。
- [ ] 勾選變動時呼叫 controller 的清除方法。

## 4. Screen: 首次匯入前不畫狀態圖示 (TDD)
- [ ] Test first (red)：`ImportStatus.idle` 時沒有狀態圖示；跑過之後沒輪到的類型**仍然**顯示空心圈（這條保護既有行為，別誤刪）；第一次送出時類型標題的水平位置不變（等寬空白，不是移除）。
- [ ] `_TypeResultRow`: 依 `ImportStatus` 決定 trailing 畫圖示或等寬空白。

## 5. 主題: 拉開停用勾選框的兩態 (TDD)
- [ ] Test first (red)：`lightTheme.checkboxTheme` 的 disabled 填色與外框色不同，且各自對 `surfaceLight` 的對比達標（實際算出比例寫進註解）。
- [ ] `app_theme.dart`: 新增 `CheckboxThemeData`。深色維持現況（3.06:1 已足夠），只動淺色。**注意這是全 app 的 Checkbox 主題** —— 目前只有匯入畫面在用，但仍要確認沒有其他使用點被影響。

## 6. 狀態圖示的語音標籤 (TDD)
- [ ] Test first (red)：匯入中該列的 semantics 讀得到「正在匯入」；成功／失敗各自讀得到對應描述。
- [ ] 四種狀態各給 `semanticLabel`；l10n 新增四個字串（ARB ×3）。
- [ ] 重新產生 `lib/l10n/generated` 並提交 diff（CLAUDE.md i18n 規則）。

## 7. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠，`select-import-types` 的既有測試無退化。

## 8. On-device verification (manual — 需使用者，部署後)
- [ ] 版面順序讀起來順不順；送出按鈕移到最下面後找不找得到。
- [ ] 匯入中「沒選」與「已選但還沒輪到」在深色與淺色主題下是否真的分得出來（D4 拉開對比後）。
- [ ] 跑完改勾選 → 那列結果消失、其他列留著，符不符合直覺。
