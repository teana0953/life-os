# 財務 bottom sheet 關不掉 — 設計

使用者實機回報:「管理科目的 bottom sheet 太長,無法回去原本的頁面,只能按實體的返回鍵,但又會回首頁」。

## 根因

`finance_scaffold.dart` 的四個 `showModalBottomSheet` 呼叫(快照 :125、科目管理 :140、記一筆 :163、預算 :179)**只設了 `isScrollControlled: true`**,缺 `useSafeArea` 與 `showDragHandle`。

對照全專案其他呼叫點,慣例是三件一組:
- `food_search_screen.dart:164-168` — isScrollControlled + useSafeArea + showDragHandle
- `exercise_screen.dart:114-118` — 同上
- `goal_card.dart:51-55` — 同上
- `care_today_screen.dart:303-309` — isScrollControlled + useSafeArea(有註解說明為何需要 isScrollControlled)
- `care_history_screen.dart:147-153` — showDragHandle

**finance 是唯一一組沒跟上慣例的**,四個全中。

後果鏈(**已對照 Flutter SDK 原始碼查證**,`packages/flutter/lib/src/material/bottom_sheet.dart`):

1. 內容長(科目管理列出全部科目 + 新增區塊)+ `isScrollControlled: true` → sheet 高度可長到滿版。
2. M3 預設 `constraints: maxWidth 640` → 手機寬度下 sheet 佔滿寬,**沒有左右 scrim**;滿版高度時上下 scrim 也歸零 → 點不到外面。
3. **沒有 drag handle 是關鍵**(SDK :363-405):drag handle 放在 Stack 頂端、內容再 `Padding(top: kMinInteractiveDimension)`,handle 區域**不在 scrollable 內**,拖它才命中外層 `_BottomSheetGestureDetector`;沒有 handle 時,拖內容會被 `SingleChildScrollView` 的 drag recognizer 先贏走 → **拖不動**。
4. 兩條關閉路徑都斷 → 只剩實體返回鍵 → PWA 上那是瀏覽器返回 → 退出 go_router 路由堆疊 → **回首頁**(而非回財務頁)。

**歸因更正**:原本以為 `useSafeArea` 是解方之一,查證後不成立——`useSafeArea` 只是 `SafeArea(bottom: false)`(SDK :1119),僅讓出 top inset,而 Flutter web/PWA 的 top padding 一般為 0,在使用者實際踩雷的環境**是 no-op**。真正解決問題的是 `showDragHandle`。

## 修法

四處補齊 `showDragHandle: true`(**主要修法**)+ `useSafeArea: true`(次要,對齊其他 context 慣例;PWA 上多半 no-op,但原生 iOS/Android 的瀏海機仍有用,且無害)。

**保證來自 drag handle**:它提供一塊不在 scrollable 內的可拖區域,無論內容多長都能下拉關閉,且視覺上明示「這是可關的 sheet」。

**不加 maxHeight**:雖然加 `maxHeight ≈ 0.9 viewport` 能保證留出 scrim,但那會改變四個 sheet 在長內容時的高度行為(現在是滿版),偏離「修 bug 不改設計」的界線,也與其他 context 不一致。drag handle 已足以保證可關閉。若日後實機顯示仍不足,再另案處理。

## 範圍

- 只改 `finance_scaffold.dart` 四個呼叫點的 sheet 參數(:125 快照、:140 科目管理、:163 記一筆、:179 預算)。
- 不改四個 sheet widget 本身的內容、版面、key。
- 範圍外:盤點第二批的 SheetForm 外殼抽取(那是重構,這是修 bug,不混);其他 context 的 sheet(已符合慣例)。

## 已知殘留(不在本 change 修)

使用者症狀的另一半——**在財務頁按實體/瀏覽器返回會回首頁而非回上一層**——本 change 沒有修,只是讓使用者不必再被迫用返回鍵。那是 go_router 路由堆疊的獨立問題(財務 shell 內的 tab 切換不進堆疊),值得另開 change。

## 風險

`showDragHandle: true` 會在 sheet 頂端加一條 handle,**四個 sheet 的頂端多出約 22px**——這是預期中的視覺變化(與其他 context 一致),不是回歸。既有 finance sheet 測試**預期續綠**——全為 byKey 斷言,不受位移影響。若仍有測試變紅,確認是位移而非行為改變後再調整該斷言。

## 測試

- 四條測試**必須寫在 `finance_scaffold_test.dart`**——`budget_sheet_test.dart` 與 `add_transaction_sheet_test.dart` 自帶一份 showModalBottomSheet、另兩支直接 pump widget,寫在那裡會生出永遠不紅的假測試。
- 迴歸:既有 finance sheet 測試全綠(記一筆、預算、快照、科目管理)。
- 實機驗證(留給使用者):長內容的科目管理 sheet 能以**下拉 drag handle** 關閉,回到淨值頁而非首頁。

## 驗收

四處參數補齊;`flutter analyze` 0 issue;`flutter test` 全綠;使用者實機確認 sheet 可正常關閉。
