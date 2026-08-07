# Tasks

**後端已經上了,契約查得到真答案** —— 不要猜欄位名。
`life-os-backend/src/adapters/http/routes/split.ts` 的 `expenseToJson` /
`balanceToJson` / `parseShareSchedule` 是正本。

**#85 必須先 merge**,否則讀取路徑沒有 schedule,做出來的編輯會把時程表弄掉。

## 0. 契約

- [x] 0.1 分攤的 JSON 多一個**可選**的 `schedule: { periods, per_period_amount }`,寫入端接受同一個拼法。沒有時程表的分攤**沒有這個 key**(不是 null)。
- [x] 0.2 餘額的幣別列多一個**可選**的 `schedules`,是**陣列**:`[{ expense_id, next_period, total_periods, period_amount }]`。
- [x] 0.3 `schedule` 只存在於 `mode: "exact"` 的分攤上,而且後端驗 `periods × per_period_amount === amount`,不符是 400。
- [x] 0.4 **parse 層要有守門**:widget fixture 都直接建構模型,`fromJson` 跑不到。**突變:讀錯鍵名**必須紅。`schedules` 讀成單一物件也必須紅。

## 1. 差額吸收(純函式,先做)

- [x] 1.1 放 `lib/contexts/split/domain/`,不是 widget 裡。輸入:分攤名單、要排程的人、期數、付款人 id。輸出:調整後的名單 + 「誰被動了多少」。
- [x] 1.2 吸收順序:**付款人自己的分攤 → 其他未排程的分攤者 → 都沒有就回傳「做不到」**。
- [x] 1.3 **不能挑一個已排程的分攤者來吸收** —— 那會讓那個人的 `periods × per_period` 對不上,後端 400。突變:把「未排程」的條件拿掉,必須紅。
- [x] 1.4 除得盡時**不做任何調整**(不是「調整 0 元」)。突變:一律走調整路徑,必須紅。
- [x] 1.5 「做不到」時要能算出**最接近的可行期數**(6,100 → 10 期 / 20 期)。

## 2. 表單

- [x] 2.1 exact 模式下,**一個下拉選誰按月還 + 期數輸入**;每期金額**由系統顯示,不是輸入框**。(原本寫的是「每個分攤者一個開關」,實作改成一份時程表 —— 兩份時程表就是兩個會互相追著調的金額,表單解釋不了,而後端允許不代表這裡要開。)
- [x] 2.2 **均分模式要說出來**(schedule 只在 exact 上存在),不是把控制項藏起來讓值靜靜失效。
- [x] 2.3 從 exact 切回 equal 時,已填的時程表**不能靜默留著** —— 要嘛清掉並說一聲,要嘛擋住切換。選一個,寫進註解。
- [x] 2.4 **編輯既有分帳時,時程表要載入**(`share.schedule`),沒動就原樣送回。**這條是整個 change 的地基** —— 送不回去等於刪掉,而刪掉會讓持有者被重複收費(#85 的兩半)。
- [x] 2.5 調整顯示成 `6,100 → 6,096`,兩個數字都看得到。突變:只顯示調整後的數字,必須紅。
- [x] 2.6 「做不到」時擋下儲存並列出可行期數。

## 3. 餘額卡

- [x] 3.1 每個時程表一行:第 N/M 期 · 每期金額。
- [x] 3.2 **不要折成一行摘要**,也不要只顯示第一個 —— 後端逐筆分帳回傳就是因為合併會產生一個不屬於任何一邊的數字。突變:只讀 `schedules.first`,一條「兩個時程表兩行」的測試必須紅。
- [x] 3.3 餘額金額**不因時程表改變**(仍是全額)。
- [x] 3.4 沒有時程表的列**完全不顯示這一段**。

## 4. 帳本明細

- [x] 4.1 `finance_transaction_row.dart` 的 `isInstallment` 從 `planId != null` 改成 `installmentNo != null`。
- [x] 4.2 `add_transaction_sheet.dart` 的 `_installmentInfo` 渲染條件同上;**「前往計畫」仍然掛在 `plan != null`**。
- [x] 4.3 沒有 plan 時顯示 `financeInstallmentPeriodOnly`(「第 N 期」),**不要編造總期數**。
- [x] 4.4 **既有的分期測試不能因此壞掉** —— 有 plan 的那半仍要顯示「第 3 期 / 共 12 期」與前往計畫。
- [x] 4.5 突變:條件改回 `planId != null`,一條「分帳分期的列有期數標記」的測試必須紅。

## 5. 驗證

- [x] 5.1 `flutter analyze`、`flutter test` 全綠。
- [x] 5.2 窄螢幕(320dp)守門:表單多了兩排控制項,餘額卡多了 N 行。**不是只看溢位** —— 畫面變高會讓既有掃描的 tap 打不到目標而全綠([[lifeos-narrow-screen-guards]] 的六種形態)。要數 `would not hit test` 警告。
- [x] 5.3 三個 ARB 都要加(`app_en` / `app_zh_Hant` / `app_zh`),key parity 自己核對(#99 還沒有自動守門)。
