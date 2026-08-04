# 抽出共用的 modal sheet 呼叫 — 設計

## 這一期的價值,說清楚

`showModalBottomSheet` 在 `lib/` 有 **14 個呼叫點**(另有一處 grep 命中在註解裡,不算)。其中 **12 個用完全相同的三件組**:

```dart
isScrollControlled: true,
useSafeArea: true,
showDragHandle: true,
```

而且每一處還各自帶著一段解釋「為什麼要這三個」的多行註解——三份措辭近乎相同、各自被重新推導出來的知識。

**沒有任何一處漏掉選項,這一期不修 bug。** 這份盤點錯過兩次:第一次以為有兩處漏了 `showDragHandle`(grep 視窗被註解推出去),第二次把總數寫成 12/10/2 而實際是 **14/12/2**、分佈在 6 個檔不是 7 個。**實作時要自己重數,不要信任何寫下來的數字**——包括這一份;一個被靜默跳過的呼叫點正是這個 change 最會失敗的地方。

價值有三個,都不是「防止事故」:

1. **那段知識只住一個地方**。`showDragHandle` 為什麼非有不可(PR #115:高 sheet 填滿視窗 → scrim 消失 → 拖曳被內容的捲動吃掉 → 只剩瀏覽器返回鍵,而在 PWA 上那會把 router stack 拆回首頁)、`isScrollControlled` 為什麼非有不可(不設就被截在 9/16,送出鈕被切掉)、`useSafeArea` 實際上做了什麼(`SafeArea(bottom: false)`,底邊仍歸 sheet 自己處理)——目前散在三份註解裡。
2. **兩個例外會變成看得出來的例外**。現在它們只是「沒寫那三行」,跟「忘了寫」在程式碼上長得一樣。
3. **下一個 sheet 預設就是對的**,不必靠作者記得或去抄。

## 做法

`lib/shared/widgets/app_sheet.dart`:

```dart
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
})
```

固定帶那三個選項,doc comment 收攏上面三段理由。**12 個呼叫點改用它。**

## 決策要點

**D1 兩個例外保留原樣,但要註明它們是例外。**
- `food_search_screen.dart:214`(選餐別):**三個選項一個都沒設**(不是只少 `isScrollControlled`),維持 9/16 上限,自己包 `SafeArea` + `SingleChildScrollView`。
- `care_history_screen.dart:147`(狀態選擇):有 `showDragHandle`,沒有另外兩個,自己包 `SafeArea`。

兩者都是短的選擇器,不是表單。**不要為了「統一」把它們也改掉**——那會改變使用者看到的高度與捲動行為,而這一期不是要改行為。各自加一行註解指向 `showAppSheet`,說明為什麼這裡不用它。

**D2 helper 不吃額外參數。** 目前 12 個呼叫點除了那三個選項與 `builder` 之外**沒有傳任何其他東西**(沒有 `shape`、`backgroundColor`、`isDismissible`、`enableDrag`、`constraints`)。先不預留;真的有第 13 種需求時再加,加參數比拿掉容易。

**D3 這是純重構,行為必須零變化。** 十二個呼叫點改完之後,每一個 sheet 的外觀與行為都要跟改之前一模一樣。**驗證方式是拿 `main` 對照**,不是讀註解說「應該一樣」。

## 測試

- **helper 自己的 widget test**:拖曳把手存在;內容超過 9/16 時不被截斷。**每一條都要突變**:把對應選項從 helper 拿掉,那一條必須紅。
- **`useSafeArea` 不要用「底部 inset」去驗**——那條斷言不可能失敗。Flutter 的 `bottom_sheet.dart` 在有無這個選項時都讓 sheet 延伸到螢幕底部(它自己的 doc 就這麼寫),差別在 `SafeArea(bottom: false)` 對上 `MediaQuery.removePadding(removeTop: true)`,也就是**上/左/右**的 padding。要驗就驗那三邊。
- **既有測試不得破**。十二個呼叫點各自有既有的畫面測試,但其中兩處沒有斷言任何 sheet 選項 覆蓋各自的畫面;它們全綠就是行為未變的第一層證據。
- **第二層證據**:與 `main` 對照渲染結果。**要挑既有測試最薄的那幾個改動點**——`group_detail_screen_test.dart` 與 `exercise_screen_test.dart` 完全沒有斷言任何 sheet 選項,所以第一層證據在那兩處是空的,對照要瞄準它們。挑既有測試已經很厚的地方對照才是做樣子。

## 不做

- 不碰兩個例外的行為(D1)、不預留參數(D2)、不動空狀態(那是分歧不是重複,需要先定標準,另案)。
