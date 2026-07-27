## Why

`select-import-types`（同分支，PR #92）把類型選擇做進 chaodays 匯入畫面。審查列了五項不阻擋合併、但確實影響體驗的問題，這個 change 一次清掉：

1. 選擇控制項排在**送出按鈕下方**，且那張卡片沒有標題 —— 設定「要匯什麼」的控制項出現在它驅動的動作之後，手機上還可能一開始在摺線下，「全不選 → 按鈕停用」的因果因此看不到。
2. 跑完後改勾選不會清掉過期結果（會出現「沒打勾的列旁掛著上次的筆數」）；反過來按送出又會清掉**全部**類型的結果，所以只重跑一種會讓其他四種的結果一起消失。
3. 尚未匯入時 trailing 的空心圈零資訊量（五列全是它），而且左方框、右圓框並置，圓形外框在列上的慣例是 radio。
4. 停用狀態的勾選框在淺色主題只有 1.91:1，未勾與打勾幾乎分不出 —— 而勾選框是「我到底選了什麼」的唯一載體。（原始回報的理由是「兩者 trailing 同為空心圈」，那在下述 `pristine` 之後不再成立，但決策本身仍要做。）
5. 狀態圖示對螢幕閱讀器完全不發聲。

## What Changes

- **卡片順序**：帳密／日期 → 類型選擇＋結果 → 送出。選擇卡片加 `labelLarge` 標題，比照 `care_item_form.dart` 週幾選擇區塊的既有形式（標題＋控制項，且在動作之前）。
- **只有被動到的才清結果**：改勾選 → 清掉**那一列**的結果與圖示；按送出 → 只重置**這一輪要跑的**類型，其餘保留。清除放在 controller（`typeStates` 是它持有的），screen 在勾選變動時呼叫。
- **新增 `TypeStatus.pristine`**（「從未跑過，或剛被清掉」），`notAttempted` 縮回單一意義「這一輪跑了但沒輪到它」。`pristine` 時 trailing 留等寬空白，不畫空心圈 —— 「跑過但沒輪到」的空心圈是正面資訊、保留（且已被測試釘住），「從未跑過」的則不是。這個區分必須是 per-type 的：D2 的「改勾選 → 那列回到空白」發生時全域狀態是 `done`，用 `ImportStatus` 表達不出來。
- **`CheckboxThemeData`** 拉開 disabled 的填色與外框，讓停用狀態的未勾／打勾分得出來。深色（3.06:1）維持現況。
- **狀態補上語音描述**（`pristine` 不需要 —— 它本來就沒有狀態可講；importing 吃的是 `CircularProgressIndicator.semanticsLabel`）。連同 D1 的卡片標題，是本 change 僅有的新 l10n 文案（ARB ×3 + 重新產生）。

前端 only；後端與 `ImportRepository` 介面不動。Gate = lint + `flutter analyze` + `flutter test`。

## Capabilities

### Modified Capabilities

- `chaodays-import-ui`: 選擇控制項 SHALL 排在它驅動的送出動作之前；結果 SHALL 只在對應類型被改動或重跑時才清除；狀態 SHALL 有非視覺的對應描述。
