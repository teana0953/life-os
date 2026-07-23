# Tasks

TDD throughout. `flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`
before finishing. Colors from `Theme.of(context)`; strings via ARB (en+zh_Hant+zh,
`flutter gen-l10n`, commit generated). Frontend-only, no backend.

## 1. Domain
- [x] 1.1 In `lib/contexts/vitals/domain/vitals_series.dart`, add `enum TrendView
      {weight, bodyFat, bloodPressurePulse, glucose, spo2}` and
      `metricsForView(TrendView)` returning the plotted metrics in draw order
      (single-metric views → one metric; bloodPressurePulse → [systolic, diastolic,
      pulse]). Test first (single views map 1:1; combined view maps to the three in
      order).

## 2. Trend card (view-based, multi-line)
- [x] 2.1 `trend_card.dart`: card state selects a `TrendView`; chips iterate
      `TrendView.values` (key `trend-view-<name>`). Build one `_ChartLine` per metric
      of the selected view (Theme color per line, distinct for the combined view).
- [x] 2.2 `_TrendChart` plots `List<_ChartLine>` — one `LineChartBarData` per line;
      area fill only for a single-line view. Band + y-axis expansion apply only to
      single-metric views (combined view → no band). Test first (combined view: one
      chart, three lines, no band).
- [x] 2.3 Legend: multi-line view shows a per-line legend (key `trend-lines-legend`,
      one swatch+label per line with data); single-metric view keeps the
      normal-range legend (key `trend-normal-range-legend`). Header unit for the
      combined view is `mmHg · bpm`.
- [x] 2.4 Screen-reader summary: single-metric view keeps
      `trendChartSemantics(label, days, value, unit)`; multi-line view uses
      `trendChartSemanticsMulti(label, days)`; empty view uses the existing empty
      summary. Test first.

## 3. i18n
- [x] 3.1 Add `trendMetricBloodPressurePulse` and `trendChartSemanticsMulti` to
      `app_en.arb` (with descriptions) + `app_zh_Hant.arb` + `app_zh.arb`; run
      `flutter gen-l10n`, commit generated.

## 4. Gates
- [x] 4.1 `flutter analyze` clean, `flutter test` green, `bash scripts/lint-actions.sh`
      pass.
