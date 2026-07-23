## Why

The backend now serves vitals as per-metric daily time series
(`/api/vitals/range`, life-os-backend PR #23). This adds the dashboard's **second
card (feature C2): a trend line chart** for the health metrics the user asked to
see over time — weight and body fat plus blood pressure, heart rate, blood oxygen,
and blood glucose — with a metric picker and a range selector (7 / 30 / 90 days).

## What Changes

- **Vitals context extended** (`lib/contexts/vitals/`): `SeriesPoint {day, value}`,
  `VitalsSeries {weight, bodyFat, systolic, diastolic, pulse, glucose, spo2}` (each
  a list of points), `VitalsRange {from, to, series}`, and a `VitalsMetric` enum.
  `VitalsRepository.getRange(idToken, from, to)` + its `HttpVitalsRepository`
  implementation (GET `/api/vitals/range`; bearer; 401→reauth; snake_case). A
  `GetVitalsTrends` use case.
- **`fl_chart`** added to `pubspec.yaml` for the line chart (the app has no chart
  library yet).
- **`TrendController`** (ChangeNotifier): loads the range for the selected span
  (7 / 30 / 90 days, computed from an injectable clock), holds the `VitalsRange`,
  and reloads when the span changes; status loading / loaded / error / needsReauth.
- **Trend card** on the dashboard (the second card, after the goal card): a title,
  a **metric picker** (chips for 體重 / 體脂 / 收縮壓 / 舒張壓 / 心跳 / 血糖 / 血氧),
  a **range selector** (7 / 30 / 90 天), and an `fl_chart` line chart of the selected
  metric's series over the range. When the selected metric has no data in the
  range, the chart area shows a "no data yet" message rather than an empty plot.
  Colors from `Theme.of(context)`. Reuses `LedgeCard`.
- The dashboard loads the trend controller on first build and reloads it (like the
  goal) after returning from the record shell, so a just-recorded reading shows.
  **DI** threaded `main.dart` → `App` → `_AuthenticatedHome` → `HomeScreen` →
  `DashboardScreen` (a new `trendController`, mirroring `weightGoalController`). New
  i18n keys (en + zh-Hant + zh); l10n regenerated.

Frontend-only; consumes the existing backend API. No behaviour change to the goal
card, the trackers, or the tab shell — only a second card is added to the
dashboard.

## Capabilities

### Added Capabilities

- `dashboard-trend-card`: a trend line chart on the dashboard showing any one of
  the vitals metrics (weight, body fat, systolic, diastolic, pulse, glucose, blood
  oxygen) over a selectable range (7 / 30 / 90 days), driven by `/api/vitals/range`.
  The dashboard's second card. Single-metric view with a picker; multi-series
  overlay and menstrual-cycle overlay are deferred.
