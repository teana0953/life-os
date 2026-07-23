# Tasks

TDD throughout. `flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`
before finishing. Colors from `Theme.of(context)`; strings via ARB (en+zh_Hant+zh,
`flutter gen-l10n`, commit generated). Frontend-only, no backend.

## 1. Domain
- [x] 1.1 In `lib/contexts/vitals/domain/vitals_series.dart`, add `NormalRange
      {min, max}` and `normalRangeFor(VitalsMetric metric, {double? heightCm})`:
      systolic 90–120, diastolic 60–80, pulse 60–100, glucose 70–140, spo2 95–100;
      weight = healthy BMI 18.5–24.9 × (height/100)² rounded to 1 decimal (null when
      heightCm null/≤0); bodyFat null. Test first (clinical values, weight 165→~50.4/
      67.8, weight no-height→null, bodyFat→null).

## 2. Trend chart band
- [x] 2.1 Test first (widget) then implement in `trend_card.dart`: `TrendCard` gains
      an optional `double? heightCm`; the chart looks up `normalRangeFor(selected,
      heightCm: heightCm)`. When non-null, add an fl_chart `HorizontalRangeAnnotation`
      band (Theme-derived subtle color, not hard-coded) and expand `minY`/`maxY` to
      include both the band and the data (with padding, no crash on single/empty
      points), plus a `trendNormalRangeLabel` legend. When null (bodyFat, or weight
      without height), no band and no legend. Tests: band + legend for a clinical
      metric; none for bodyFat; band for weight WITH heightCm and none WITHOUT.

## 3. Wiring + i18n
- [x] 3.1 Add ARB `trendNormalRangeLabel` (en "Normal range" / zh「正常範圍」) + gen-l10n.
- [x] 3.2 In `dashboard_screen.dart`, pass `heightCm: widget.weightGoalController.goal
      ?.heightCm` to `TrendCard`.

## 4. Gate
- [x] 4.1 `flutter analyze` clean + `flutter test` green + `bash scripts/lint-actions.sh`
      pass. l10n committed. No change to trend data / other cards / trackers.
