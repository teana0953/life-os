# Tasks

> 全部建立在同分支的 `select-import-types` 之上（PR #92）。
>
> **有兩條既有測試會被這個 change 刻意反轉**，必須改寫而不是繞過：
> - `chaodays_import_controller_test.dart` 的 *a new run clears every type's result,
>   including the ones it skips* —— D2 正是要反轉它。
> - `chaodays_import_screen_test.dart` 的 *the checkbox leads the row and the status icon
>   trails it* —— 它在 idle 狀態靠 `Icons.circle_outlined` 取 trailing 的 dx，D3 之後那裡
>   沒有圖示；改成跑過之後再比位置。**不可以**為了讓它變綠而在 `pristine` 留一個看不見的圖示。
>
> 另外有三條 controller 斷言的期望值會從 `notAttempted` 翻成 `pristine`（尚未開跑時的初始狀態），
> 那是 `pristine` 的定義變更、不是行為退化，照改即可。
>
> 其餘既有測試（勾選框常駐、跑完後仍可改選再跑、`enabled` 語意、圖示配色）**必須維持通過**。

## 1. 新增 `TypeStatus.pristine` (TDD)
- [x] `TypeStatus` 加 `pristine`（「從未跑過，或剛被清掉」），`notAttempted` 縮回單一意義「這一輪跑了但沒輪到它」。`_freshTypeStates()` 改寫入 `pristine`。
- [x] 新增 enum 值會讓所有 `switch (state.status)` 編譯失敗 —— **逐一明確決定** `pristine` 顯示什麼，不要用 `default:` 或 `_` 掃過去（那會讓下一個新增狀態時失去同樣的保護）。

## 2. Controller: 只清被動到的類型 (TDD)
- [x] Test first (red)：
  - 清除單一類型只影響那一型且落在 `pristine`，其餘 `typeStates` 不動
  - `import()` 只重置**這輪要跑的**類型；未選類型上一輪的 `TypeState` 原封不動（**D2 的回歸點**：目前是無條件 `_freshTypeStates()`）
  - 既有語意不變：停在第一個失敗、`authFailed` 把該型退回 **`notAttempted`**（不是 `pristine` —— 它確實參與了那一輪）、401 → `needsReauth`、`DataRevision` 每輪最多 bump 一次且至少一種成功才 bump
- [x] `ChaodaysImportController`: 加清除單一類型狀態的方法（寫入 `pristine`）；`import()` 的重置改成只作用於 `types`，**且重置成 `notAttempted` 而不是 `pristine`** —— 這一輪要跑的類型「已選但還沒輪到」正是 `notAttempted` 的意思（design 狀態表、既有 controller 斷言、以及 §5 要保護的那條 circle_outlined 都釘住它）。`pristine` 只有兩個寫入點：初始化與 D2 的清除。

## 3. Screen: 版面順序與標題 (TDD)
- [x] Test first (red)：送出按鈕在類型清單**之後**（比較兩者的垂直位置，不是只看存在）；卡片標題存在且用 `labelLarge`。
- [x] `ChaodaysImportScreen`: 把送出按鈕移到類型卡片之後；類型卡片加標題。維持既有的 `ListView` / `maxWidth: 600` 結構。
- [x] l10n: 新增卡片標題字串到 `app_en.arb`（含 `description`）+ `app_zh_Hant.arb` + `app_zh.arb`。

## 4. Screen: 改勾選清該列結果 (TDD)
- [x] Test first (red)：跑完一輪後改動某列的勾選 → 那列落到 `pristine`（結果文字與狀態圖示都消失）、其他列的**留著**。
- [x] 勾選變動時呼叫 controller 的清除方法。

## 5. Screen: `pristine` 不畫狀態圖示 (TDD)
- [x] Test first (red)：`pristine` 時沒有狀態圖示；跑過之後沒輪到的類型（`notAttempted`）**仍然**顯示空心圈（這條保護既有行為，別誤刪）；圖示出現時類型標題的水平位置不變 —— 斷言 trailing 佔位的**實際寬度**相同，不要只斷言標題 dx（那條在 `ListTile` 的固定 leading 版面下大概率恆真、等於空測試）。
- [x] `_TypeResultRow`: 依**該型的** `TypeStatus` 決定 trailing 畫圖示或等寬空白（**不是**全域 `ImportStatus` —— 見 design D3）。空白寬度對齊 `Icon` 的 24，不是 importing spinner 的 20。

## 6. 主題: 拉開停用勾選框的兩態 (TDD)
- [x] Test first (red)：`lightTheme.checkboxTheme` 的 disabled 填色與外框色不同，且各自對 `surfaceLight` 的對比達標（實際算出比例寫進註解）。
- [x] `app_theme.dart`: 新增 `CheckboxThemeData`。深色維持現況（3.06:1 已足夠），只動淺色 —— 注意 `_buildTheme()` 是淺深共用的，要分岔而不是一律套用。（已確認 `lib/` 內只有匯入畫面用 `Checkbox`。）

## 7. 狀態圖示的語音標籤 (TDD)
- [x] Test first (red)：匯入中該列的 semantics 讀得到「正在匯入」；成功／失敗各自讀得到對應描述。
- [x] 各狀態給語音描述；l10n 新增字串（ARB ×3）。注意 importing 用的是 `CircularProgressIndicator`，它吃的是 `semanticsLabel` 而不是 `Icon.semanticLabel`。`pristine` 不需要描述（它本來就沒有狀態可講）。
- [x] 重新產生 `lib/l10n/generated` 並提交 diff（CLAUDE.md i18n 規則）。

## 8. Gate
- [ ] `bash scripts/lint-actions.sh` + `flutter analyze` + `flutter test` 全綠，`select-import-types` 的既有測試無退化。

## 9. On-device verification (manual — 需使用者，部署後)
- [ ] 版面順序讀起來順不順；送出按鈕移到最下面後找不找得到。
- [ ] 匯入中「沒選」與「已選但還沒輪到」是否真的分得出來 —— **淺色**已拉開（填色 8.32:1／外框 5.17:1，兩態相距 1.61:1）；**深色**兩個 disabled 態仍是同一個顏色（相距 1.00:1），原本「3.06:1 已足夠」量的是對卡片的可見度而不是兩態區隔。深色看得出問題的話回頭一起拉開。**看的時機**：匯入進行中那一瞬間 —— 那是唯一兩個 disabled 態同時出現在同一張卡片上的時刻。
- [ ] 跑完改勾選 → 那列結果消失、其他列留著，符不符合直覺。
