# 设计:趋势图正常范围参考带(trend-normal-range / C2 加强)

## 目标
在既有趋势卡(fl_chart 折线图)的 y 轴加**正常范围参考带**(阴影 band + 图例),让使用者一眼看数值有没有落在健康区间。纯前端,无后端。

## domain(`lib/contexts/vitals/domain/vitals_series.dart`)
- `class NormalRange { final double min; final double max; const NormalRange(this.min, this.max); }`。
- `NormalRange? normalRangeFor(VitalsMetric metric, {double? heightCm})`:
  - systolic → (90,120)、diastolic → (60,80)、pulse → (60,100)、glucose → (70,140)、spo2 → (95,100)。
  - **weight** → 依健康 BMI 18.5–24.9 × 身高²:heightCm null 或 ≤0 → null;否则 `min = round1(18.5 × (h/100)²)`、`max = round1(24.9 × (h/100)²)`。
  - **bodyFat** → null(性别/年龄相关)。
  - 纯函式、零外层 import。

## presentation(`trend_card.dart`)
- `TrendCard` 加 `final double? heightCm;`(可选,默认 null)。传给内部图表。
- `_TrendChart` 加参数:`metric`(当前选中)、`heightCm`。build 时 `final normal = normalRangeFor(metric, heightCm: heightCm);`。
- **band**:normal 非 null 时,`LineChartData.rangeAnnotations = RangeAnnotations(horizontalRangeAnnotations: [HorizontalRangeAnnotation(y1: normal.min, y2: normal.max, color: <Theme 取色, 低 alpha>)])`。颜色走 Theme(如 `theme.colorScheme.tertiary.withValues(alpha: 0.14)` 之类的 subtle tint;**不硬编**),与折线主色可辨。
- **y 轴范围**:normal 非 null 时,minY/maxY 要**同时涵盖资料点与 band**(+ 少量 padding),否则 band 会被裁。计算:`values = [...spots.map(y), normal.min, normal.max]`(资料空时只有 band),`dataMin/dataMax = min/max(values)`,`pad = max((dataMax−dataMin)*0.1, 1)`,`minY = dataMin−pad`、`maxY = dataMax+pad`。normal 为 null 时维持现状(fl_chart 自动 y 范围)。单点/空资料不炸。
- **图例**:normal 非 null 时,卡片显示一个小 legend(色块 + `trendNormalRangeLabel`「正常範圍」),放图表下方或标题附近。null 时不显示。
- 空资料(该指标无点)时仍可显示 band + legend(让使用者知道正常区间),或维持既有 trend-empty——**设计倾向**:空资料时仍走 trend-empty 讯息(不画图),故 band 只在有图时出现(简单一致)。若要空资料也显示 band 可后续加,不在本 change 强求。

## dashboard 接线(`dashboard_screen.dart`)
- 建构 `TrendCard` 时传 `heightCm: widget.weightGoalController.goal?.heightCm`。dashboard 已 listen weightGoalController(goal 卡用),goal 载入/身高更新后会 rebuild → TrendCard 拿到新 heightCm → 体重 band 出现/更新。无需额外载入。

## i18n
新增 ARB(en + zh_Hant + zh):`trendNormalRangeLabel`(en "Normal range" / zh「正常範圍」)。跑 `flutter gen-l10n` 提交 generated。

## 测试(flutter test,TDD)
- domain(`vitals_series_test.dart` 加):`normalRangeFor` —— 5 个临床指标固定值;weight 有身高(165 → ~50.4/67.8)、无身高(null);bodyFat null。
- widget(`trend_card_test.dart` 加):
  - 选临床指标(如 spo2)有资料 → LineChart 的 `rangeAnnotations.horizontalRangeAnnotations` 非空(band 存在)+ `trendNormalRangeLabel` 图例显示。
  - 选 bodyFat → 无 band(annotations 空)、无图例。
  - weight + 传 heightCm → band 存在;weight + heightCm null → 无 band。
  - (可断言 minY/maxY 涵盖 band。)
- `flutter analyze` 干净 + `bash scripts/lint-actions.sh` 过。

## 明确延後
- 依生理性别/年龄的体脂范围;更细的血糖(空腹/餐后分带);超出正常范围的点变色/警示;正常范围的来源可调。

## 范围
只加 domain normalRangeFor + 趋势卡 band/legend/y轴 + heightCm 参数 + dashboard 传身高 + i18n + 测试。不改趋势资料、其他卡、tracker。
