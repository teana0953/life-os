# chaodays 匯入：可選擇要匯哪些類型（issue #86 的前端部分）

## 問題

issue #86：「可以選擇要匯入哪些資料 —— 匯入太長的時間區間，會被對方的 server 擋住」。

現況 `ChaodaysImportController.import` 把五種類型（體重／飲食／飲水／排便／飲食目標）**固定全跑**、順序寫死，第一個失敗就停。想只補匯飲食，也得五種全跑一遍。

## 範圍：為什麼分批不在這個 change

issue 的另一半（長區間被擋）**落在後端 repo**，理由是登入次數：

後端每個 import use case 一開頭都 `chaodaysClient.signIn(uid, password)`。若在前端把區間切成 N 批、每批呼叫一次 use case，登入次數就變成 **批數 × 類型數** —— 匯三年（6 批）× 五類 = 30 次登入打同一台 chaodays。如果對方擋的是**請求速率**而不是單次區間長度，分批會讓情況更糟，正好與 issue 的目的相反。

後端切則維持每類型登入一次：`ChaodaysClient` 的 `fetch*` 方法**已經回傳輪替後的 session**（devise_token_auth 每次回應輪替 token，port 的註解明寫 `Returns the rotated session ... alongside the records`），現行 use case 只是 `const { records } = ...` 把它丟掉。分批時串接它即可，登入一次、後續批次沿用。

所以本 change 是純前端的類型選擇；分批另案處理。兩者互不依賴，可以各自出。

## 設計決策

### D1 — `import` 接受選中的類型集合，未選的不跑也不算失敗

`ChaodaysImportController.import` 新增一個 **required** 的 `Set<ImportType>`。required 而非有預設值：給了預設值，漏傳的呼叫端會靜默跑全部類型，而測試也抓不到 —— 這正是這個 change 要能夠信任的行為。

迴圈維持走 `ImportType.values` 再依集合過濾，**顯示與執行順序不因選擇而改變**（選了飲食和體重，跑的順序仍是體重→飲食）。

未選的類型維持 `TypeStatus.notAttempted`。它與「auth 失敗中斷、還沒輪到」共用同一個狀態，兩者對使用者的意義相同：**這次沒有動它**。不需要為「沒選」另立一個狀態。

### D2 — 勾選框常駐 leading、狀態圖示常駐 trailing；匯入中只是**停用**勾選框

一列上有兩件事要講：「下一次要不要跑」與「這次跑得怎樣」。曾經考慮讓 leading 分時承載兩者（非匯入中放勾選框、匯入中換成狀態圖示），但那讓兩個問題同時發生：

- 匯入結束的瞬間狀態圖示**全部消失** —— 使用者正在讀結果的那一刻，成功 ✓ 與失敗 ✗ 都被勾選框取代，成敗只剩 subtitle 文字承載。中途失敗時最痛：後面沒輪到的類型顯示「打勾的勾選框＋沒有 subtitle」，打勾是肯定語氣，得靠「沒有 subtitle」反推「沒跑到」。
- 匯入中「沒選」和「已選但還沒輪到」都是空心圈，得另外拿整列變淡來區分；而在 cream 底的淺色主題上，要讓變淡達到 AA 4.5:1 得把 alpha 拉到約 0.78，那時候幾乎看不出有變淡 —— 純變淡撐不起這個語意。

所以兩個位置各自常駐、永不換角：**leading 固定是勾選框，trailing 固定是狀態圖示**（空心圈／轉圈／✓／✗）。於是：

- 成敗一直看得到，跑完後結果與勾選框並存在同一列。
- 「沒選」vs「已選但還沒輪到」靠勾選框本身就分得出來（沒打勾 vs 打勾＋空心圈），**不需要變淡機制**。
- 沒有「同一格分時承載兩種意義」這個問題類別。

匯入中仍然不能改選，但作法是**停用**而不是撤掉：`Checkbox.onChanged`（連同整列的 onTap）設為 null。判斷用的是 `_isImporting` 這個**整體**狀態，不是 per-type 的 `TypeState.status` —— 後者會壞在最重要的情境上：一輪跑完後五列都停在 `success`（controller 只在下一次 `import()` 開頭才重置 `typeStates`），勾選框會**整組鎖死**，使用者沒辦法在同一畫面改選再跑一次，而「只補匯某一種」正是這個功能存在的理由。auth 失敗時更亂：失敗那型被退回 `notAttempted`（既有行為，刻意的），其他仍是 `success`，同一張卡片會半數可改半數鎖死。

實作用 `CheckboxListTile`（`controlAffinity: leading`、狀態圖示放 `secondary`）而不是自己組 `ListTile` + `Checkbox`：它把整列併成**一個** semantics 節點（一個以類型名為名的 checkbox），否則螢幕閱讀器會先讀到一個同名的 button 節點、再讀到一個同名的 checkbox 節點。`enabled` 就讓它跟著 `onChanged` 走 —— 匯入中整列回報 disabled，這正是螢幕閱讀器該聽到的（宣告成 enabled 卻沒有任何 toggle action 才是錯的）。隨之而來的 disabled 灰只會吃到**標題**：它是唯一沒帶明寫顏色、靠 ListTile 的 `DefaultTextStyle` 上色的文字；結果文字與狀態圖示都自帶 `color:`，本來就蓋得過去。所以只要比照 subtitle，給標題明寫 `colorScheme.onSurface`，匯入中使用者正在讀的東西就維持滿版對比。

狀態圖示的顏色在淺色主題另外處理：`tertiary`（成功 ✓）與 `primary`（進行中）在 cream 卡片上只有 1.28:1 / 1.64:1，而這一版把 trailing 定為成敗的常駐載體，非文字圖形至少要 3:1。整組 pastel 都達不到（sage 1.91、honey 2.08、primaryDeep 2.29），所以比照 `errorTextLight` 的先例補兩個同色相但更深的淺色主題專用 icon 色（`importSuccessIconLight` 3.45:1、`importRunningIconLight` 3.63:1），深色主題維持既有 pastel（8.8–9.6:1）。

### D3 — 全不選時停用送出，而不是按了才報錯

「匯入零種資料」不是有意義的操作，讓按鈕可按再跳錯誤只是多一步。與畫面既有的 gating 一致（帳密或日期沒填也是停用送出）。

### D4 — 預設全選

現有使用者不該因為這個 change 而發現東西沒匯到。表單完全不動的情況下，行為與今天逐字相同。

## 元件

| 檔案 | 改動 |
| --- | --- |
| `ChaodaysImportController` | `import` 加 required `Set<ImportType>`；迴圈依它過濾 |
| `ChaodaysImportScreen` | state 持有選中集合（初值全選）；`_canSubmit` 要求非空；傳給 controller |
| `_TypeResultRow` | 改用 `CheckboxListTile`：leading 常駐勾選框、trailing（`secondary`）常駐狀態圖示；`selectable`（非匯入中）決定勾選框是否可改 |
| 既有測試呼叫端 | controller/screen/app 測試補傳全選 |

沒有新的 domain 概念，沒有新檔案。後端與 `ImportRepository` 介面不動。

## UI/UX 設計

### 使用者路徑

**主路徑（不改選）**：進匯入頁 → 五種預設全勾 → 填帳密與日期 → 送出 → 與今天完全相同。

**補匯單一類型**：只勾「飲食」→ 送出 → 只有飲食那列跑，其餘四列維持灰色未動 → 想再補別的，勾選框仍在，改勾再送出。

**例外路徑**：
- 全部取消勾選 → 送出按鈕停用。
- 匯入進行中 → 勾選框留在原位但停用（與帳密、日期欄位同一種處理：留在原位 disabled，不消失）。
- 選中的類型中途失敗 → 既有錯誤呈現不變；失敗那列的 ✗ 留在 trailing，後面沒輪到的類型維持空心圈；匯入結束後勾選框恢復可改，可以只重跑失敗那一種。

### 介面與一致性

不新增畫面、不新增卡片。勾選框長在既有結果列的 leading 位置，狀態圖示從 leading 移到 trailing —— 使用者勾了什麼，就在同一列看到它跑起來，不會有兩份類型清單。用 `CheckboxListTile` 的主題預設樣式與點擊區域（整列可點）。

### 狀態設計

leading 的勾選框與 trailing 的狀態圖示各自獨立，任何時刻兩者都在：

| | leading（勾選框） | trailing（狀態圖示） |
| --- | --- | --- |
| 尚未匯入 | 可改；預設全勾 | 空心圈 |
| 匯入中，這型沒被選 | 未勾、停用 | 空心圈 |
| 匯入中，已選但還沒輪到 | 打勾、停用 | 空心圈 |
| 匯入中，正在跑 | 打勾、停用 | 轉圈 |
| 匯入結束，成功 | 恢復可改，維持使用者的選擇 | ✓ |
| 匯入結束，失敗 | 恢復可改 | ✗ |
| 匯入結束，沒輪到 | 恢復可改 | 空心圈 |

「沒選」與「已選但還沒輪到」在匯入中都是空心圈，但勾選框本身就分得出來，所以**不需要**額外的變淡／灰化。整列文字在任何狀態下都維持一般色（不是 disabled 灰）：未勾的列隨時可被勾選，匯入中的列則正是使用者在讀進度與結果的地方。

### 可及性/理解性

不需要額外說明文案：勾選框是標準控制項，「勾起來的會跑」符合直覺。停用的送出按鈕本身就傳達「還缺條件」，與表單其他欄位的行為一致。每一列讀出來是**一個**以類型名為名的 checkbox 節點（見 D2 的 `CheckboxListTile`），而不是一個同名 button 加一個同名 checkbox。狀態圖示目前沒有非視覺對應（既有問題，不在本 change 範圍）。

## 測試策略

- **controller（單元）**：只選一種 → 其餘四個 fake use case 完全沒被呼叫、狀態維持 notAttempted；選兩種 → 順序仍照 `ImportType.values`；選中的其中一種失敗 → 既有停止語意與狀態映射不變；`DataRevision` 的 bump 規則不變；呼叫端在 `import()` 開始後改動自己那個集合，這一輪跑的類型不受影響（controller 進來就 `types.toSet()`）；新的一輪會清掉**全部**類型的前次結果，包含這輪不跑的。
- **screen（widget）**：預設全勾；全不勾 → 送出停用；只勾一種 → controller 收到的集合只有那一種，且跑完後選擇維持不變（不重置回全選）；匯入中五個 `Checkbox` 都還在但 `onChanged == null`、點整列也不會翻勾；跑完後每列的狀態圖示（✓／✗／空心圈）與勾選框並存；每一列的 semantics 是一個 label 恰為類型名、帶 checked 狀態的節點；**一輪結束後（成功與失敗兩種）勾選框恢復可改且可改選再送出**（D2 的回歸點）。
- **既有測試不得退化**：現有 import controller/screen 測試在補傳全選後應維持通過 —— 若有測試因此變紅，代表行為真的改變了，要回頭檢查而不是改斷言。

## 不做（YAGNI）

- 記住上次的選擇（跨進出畫面）—— 預設全選已涵蓋主要情境；持久化要另外處理「日後新增類型時預設值該是什麼」。
- 「全選／全不選」快捷鍵 —— 五個項目，手動勾不構成負擔。
- 為「未選」另立一個 `TypeStatus` —— 與 `notAttempted` 對使用者的意義相同（見 D1）。
- 分批 —— 見上方「範圍」一節，落在後端 change。
