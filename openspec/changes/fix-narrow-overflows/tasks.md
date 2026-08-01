# Tasks

> 每處動手前**先讀原始碼並實測**當前溢出量(design 的數字來自三個 agent 的對照量測,但行號可能已飄)。修法依實測決定,不照抄 design 的方向猜測。

## 1. menstrual-legend Row(最大宗:320/en 60px、360/en 20px)

- [ ] 1.1 實測確認當前溢出量與成因,修到 {320,360} × {en,zh} × textScale {1.0,2.0} 零溢出。優先 `Wrap` 或可收縮子項,不截字。
- [ ] 1.2 該畫面既有窄寬度測試中的 `takeException()` 改硬斷言零 exception。

## 2. networth 科目小計 Row(320/en 15px;textScale 2.0 放大成 20 個 exception)

- [ ] 2.1 實測後修;注意 textScale 2.0 時 viewport 會壞到 `find.byKey().evaluate()` 自己 crash,修好後該情境要能正常查詢。
- [ ] 2.2 對應測試改硬斷言。

## 3. health_calendar_card 三 ring Row(320/en 12px)

- [ ] 3.1 實測後修(三個 ring 的 `spaceEvenly`)。注意測試需帶正式環境的 `padding: EdgeInsets.all(20)`,否則測不到。
- [ ] 3.2 對應測試改硬斷言。

## 4. diet 對話框橫向垂直溢出(640×360,140px)

- [ ] 4.1 實測後修(內容可捲動或限制高度)。這是唯一的垂直溢出。
- [ ] 4.2 補橫向版面測試。

## 5. 守門機制

- [ ] 5.1 抽一個共用的版面守門 helper(收集**全部** `FlutterError` 而非只取第一個——binding 只保留第一個,`takeException()` 看不到後續),放 `test/support/`。四處測試共用。
- [ ] 5.2 逐一記錄改了哪幾支既有測試的 `takeException()`、為何(這是本 change 的驗收目標,不是違反零改動原則)。

## 6. 收尾

- [ ] 6.1 `bash scripts/lint-actions.sh` + `flutter analyze`(0 issue) + `flutter test` 全綠 + `TZ=UTC flutter test` 複驗。
- [ ] 6.2 **mutation 驗證**:在任一受守畫面人為加一個溢出 → 守門測試應變紅(證明不再是假守門)。
