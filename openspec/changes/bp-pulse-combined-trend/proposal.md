## Why

The dashboard trend chart plots one metric per chip, so systolic, diastolic, and
pulse each live on a separate chart. But those three are read together — blood
pressure is meaningless without both numbers, and pulse is usually taken at the
same time. Splitting them across three charts hides the relationship. This merges
them into a single **"血壓・心跳"** view: one chart, three lines.

## What Changes

- **`TrendView`** in the vitals domain: the trend card now selects a *view*, not a
  raw metric. Views are `weight`, `bodyFat`, `bloodPressurePulse`, `glucose`,
  `spo2`. `metricsForView(view)` returns the metrics a view plots — one for the
  single-metric views, and `[systolic, diastolic, pulse]` for the combined one.
- **Combined chart**: the `bloodPressurePulse` view plots three Theme-colored lines
  on one chart with a per-line legend (收縮壓 / 舒張壓 / 心跳). Its header unit shows
  both `mmHg · bpm`. Because three overlapping clinical bands would be noise, the
  combined view shows **no shaded normal-range band** (single-metric views keep
  theirs unchanged); its area fills are dropped so the lines stay readable.
- **Screen-reader summary**: single-metric views keep the value-carrying summary; a
  multi-line view uses a new value-less summary (`trendChartSemanticsMulti`).
- The three separate systolic/diastolic/pulse chips are replaced by the one
  combined chip. New i18n keys (combined view label + multi-line summary), en +
  zh-Hant + zh, l10n regenerated.

Frontend-only; no backend or trend-data change. The other views (weight, body fat,
glucose, blood oxygen) and their normal-range bands are unchanged.

## Capabilities

### Added Capabilities

- `trend-combined-view`: the dashboard trend chart is selected by view; the blood
  pressure & pulse view plots systolic, diastolic, and pulse together on one chart
  with a per-line legend and no shaded band, while single-metric views keep their
  existing single line and normal-range band.
