# 前端跟进设计:measure-unit-household-ui(「顆等同克毫升」前端半)

## 背景
后端 #14 把 `measure_unit` 泛化成开放 text,家常量单位食物(顆/碗/杯/片… 208 条有 base)现在带 `base_amount` + `measure_unit`,dev DB 已 reseed(g61/ml15/量词132/null63)。前端要把用户可见部分补上:直接输入颗数/碗数、consumed 显正确单位、份量模式显「份」不再硬抠名字。

## 核心简化(关键)
后端现在把单位(顆/碗/杯)放进了 `measureUnit`,所以前端**不再需要从名字字符串抠单位** —— `unit_label.dart` 的 `unitLabelForName` 整个**废弃**。逻辑统一为两类:
- **有 base measure(208 条,含 g/ml/量词)**:份量模式 label=「份」;measure 模式 label=该单位字(公克/毫升/顆/碗/杯)、可直接打数字;consumed 显 measure(如「9 顆」「240 毫升」)。
- **无 base(63 条:份/包装/模糊)**:只有份量模式=「份」;consumed 显「N 份」。

## 改动
1. **`measureLabelFor` 泛化**(amount_stepper.dart):`g`→公克、`ml`→毫升、**其他非空字串→原字(顆/碗/杯…)**、`null` **或空字串**→null(空字串必须归 null,否则会渲染空白 measure 标签 / consumed「9 」;后端 both-or-null 保证不太可能出现,但防御)。
2. **AmountStepper `unitLabel` 统一「份」**:today_screen 与 food_search_screen 两处从 `unitLabelForName(item.name, loc)` 改为 `loc.dietPortionUnit`(新 key「份」)。`allowMeasure` 逻辑不变(`baseAmount!=null && measureUnit!=null`)——家常量现在满足 → 出现份量/顆切换。
   - **仅改数字框后的单位 label**(`amount_stepper.dart:137` 的 `unitLabel`);**模式切换 SegmentedButton 的份量段(`dietQuantityLabel`="份量")刻意不动**——「份量」是切换按钮名,「份」是数字后的单位,是两个不同 UI 元素,别混。
3. **`_consumedAmountLabel` fallback**(today_screen):无 base 分支从 `quantity + unitLabelForName` 改 `quantity + dietPortionUnit`(「1 份」)。有 base 分支不变(measureLabelFor 泛化后自动显顆/碗)。
4. **删 `unit_label.dart`(unitLabelForName)+ 其测试**(不再从名字抠单位;唯一用处已被上面取代)。
5. **i18n 新增 `dietPortionUnit`**:份 / "portion(s)",en + zh-Hant + zh。

## 验收(TDD widget/unit 测试)
- `measureLabelFor`:'顆'→顆、'g'→公克、'ml'→毫升、null→null。
- 今日家常量(櫻桃/9顆,base9 unit顆):collapsed consumed 显「9 顆」(quantity1×9);展开 AmountStepper 有 份/顆 切换,份模式显「份」、顆模式可直接打数字送 measure。
- 无 base 家常量(如掌心大):consumed 显「N 份」,只有份量模式。
- g/ml 食物:行为不变(份/公克 切换、consumed「240 毫升」)。
- 搜尋托盤 AmountStepper 同理(份/单位字)。

## 范围
纯前端表现层 + i18n。不动 DTO(measureUnit 已 String?)、不动 API。遵循 CLAUDE.md(Chiikawa theme、gen_l10n、TextField、widget 测试注入 fake + l10nTestApp、empty-zero、可重用 AmountStepper)。
