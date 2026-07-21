# 设计:稳定 AmountStepper 布局(stabilize-amount-stepper-layout)

## 问题
编辑食物项 / 搜尋托盘里,切换「份量 ↔ 顆/公克/毫升」时,AmountStepper 会从两行变一行(或反之),元素跳动,不好点。

## 根因
`amount_stepper.dart` build 用 `Wrap`,3 个 child:①−/field/+ trio、②数字框后的 unit label、③份量/measure 的 SegmentedButton。Wrap 换行由**内容总宽度**驱动;unit label **跟随模式变宽度**(份 vs 顆/公克/毫升),于是切换时 Wrap 换行临界点变化,SegmentedButton 在「与前一行同行」与「换到下一行」之间跳 → 行数变化、元素跳。

## 目标
1. 切换模式时**行数稳定**(SegmentedButton 恒定位置,不跳)。
2. 窄屏 **320dp / 360dp** + **en 与 zh-Hant 双 locale** 都**不 overflow**(en 的 label 更长:份量段 "Quantity"、measure 段 "Grams"、unitLabel "portion(s)")。

## 方案

**主方案 A'(优先,UX 最佳):固定两行 —— trio+unit label 一行,SegmentedButton 独立第二行。**
- 第一行:Row(−/field/+ + 数字后 unit label),unit label 用 Flexible+ellipsis 兜底(窄屏长 label 收缩不 overflow)。
- 第二行:allowMeasure 时 SegmentedButton,恒独立一行。
- 切换模式只改第一行 label,行数不变(segment 恒第二行)→ 稳定。unit label 紧邻数字,符合「18 顆」阅读直觉。

**已知风险 + apply 必须实测**:solo 试 A' 时 food_search tray 的 320dp no-overflow 测试报第一行 RenderFlex overflowed ~15px(en)。apply 用 TDD 查清并解决,可能手段:收紧 trio 的 IconButton(visualDensity/constraints/padding)让 −/+/field 更紧凑给 label 留宽;确认第一行 Row 拿到 bounded 宽约束(Flexible 才生效);label Flexible 收缩到 ellipsis。

**回退方案 A(若 A' 双 locale 320dp 无法既稳定又不 overflow):unit label 移到第二行,与 SegmentedButton 同行。**
- 第一行只 trio(固定 ~150-160,稳不 overflow);第二行 unit label + SegmentedButton。切换只改第二行 label,segment 恒第二行 → 稳定。代价:label 离数字略远、与 segment 单位词轻微重复(可接受)。

**apply 决策规则**:先做 A',TDD 实跑 320/360dp × en/zh-Hant no-overflow;过就用 A',确实过不了再退 A。两者都满足「稳定」硬目标。

## 保留(不回退)
- after-field label 跟随模式(measureMode ? measureLabel : unitLabel)——#39 修的 blocking。
- SegmentedButton 份量段 label(dietQuantityLabel=份量)不动。
- measureLabelFor 逻辑、两处调用点语义、DTO/API 都不改。

## 范围
只动 amount_stepper.dart build 布局 + 相关 widget 测试。

## 验收(TDD)
- **稳定**:同一 gram/household item,measureMode=false 与 true 两种渲染下 SegmentedButton 与 trio 的行关系不变(断言 segment 恒在 trio 下方独立一行 / 行数不随 measureMode 变)。
- **不 overflow**:320dp 与 360dp、en 与 zh-Hant 下,food_search tray gram item 行、today 展开编辑器,takeException 均 isNull。
- **既有断言仍过**:measure 段(公克/毫升/顆)、份量段(份量)、数字后 unit label 跟随模式、既有窄屏测试。
