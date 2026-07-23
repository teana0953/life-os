## Why

The dashboard's trend chart (feature C2) plots a vitals metric over time, but a
raw line gives no sense of whether the values are healthy. This adds a **normal
reference range** as a shaded band on the chart's y-axis, so the user can see at a
glance whether their systolic pressure, pulse, blood oxygen, glucose, or weight
sits inside the normal range.

## What Changes

- **`normalRangeFor(metric, {heightCm})`** in the vitals domain: returns the
  metric's normal reference range (a `NormalRange {min, max}`), or null when there
  is none —
  - clinical metrics use widely-cited ranges: systolic 90–120, diastolic 60–80,
    pulse 60–100, glucose 70–140, blood oxygen 95–100;
  - **weight** is derived from a **healthy BMI (18.5–24.9)** and the user's height
    (`min = 18.5 × (height/100)²`, `max = 24.9 × (height/100)²`), null when height
    is unset;
  - **body fat** has no band (it depends on sex/age).
  These are general guides, not medical advice.
- **Trend chart band**: when the selected metric has a normal range, the chart
  draws a subtle shaded horizontal band across that range (an fl_chart
  `HorizontalRangeAnnotation`), and the y-axis min/max is expanded to include both
  the data and the band so the band is always visible. A small **"正常範圍"** legend
  labels the band. When the metric has no range (body fat, or weight before a
  height is set), no band is drawn.
- **Height wiring**: `TrendCard` gains an optional `heightCm`; the dashboard passes
  it from the weight-goal controller's height, so the weight band appears once the
  user has set their height (in the goal card).
- New i18n key for the legend (en + zh-Hant + zh); l10n regenerated.

Frontend-only; no backend change (the ranges are static/derived on the client). No
behaviour change to the trend data, the other cards, or the trackers — only the
chart gains a reference band.

## Capabilities

### Added Capabilities

- `trend-normal-range`: the dashboard trend chart shows a metric's normal
  reference range as a shaded band — fixed clinical ranges for blood pressure,
  pulse, blood oxygen, and glucose, and a healthy-BMI-derived range for weight
  (using the user's height) — with a legend, so values can be read against
  "normal" at a glance. Body fat gets no band.
