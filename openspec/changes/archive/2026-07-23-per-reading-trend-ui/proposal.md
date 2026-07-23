## Why

The backend now returns the vitals trend as **one point per reading** (each with
its time) and glucose points carry a **meal context**. The trend UI still assumed
one daily point per metric and had no way to record a reading's meal context. This
updates the UI to plot every reading on a time axis and to record/plot glucose by
meal context.

## What Changes

- **Data**: `SeriesPoint` gains `time` and (for glucose) `mealContext`;
  `GlucoseReading` gains a structured `mealContext` (空腹/餐前/餐後 | null), parsed
  from / serialized to the backend's `meal_context`.
- **Time axis**: the trend chart plots each point at its day offset **plus the
  fraction of the day its time represents**, so several readings on one day spread
  across that day's slot instead of stacking.
- **Glucose view**: the glucose view splits its single series by meal context into
  up to four coloured lines (空腹 / 餐前 / 餐後 / 未分類), with a per-context legend,
  while **keeping a general glucose normal band (70–140)** behind them.
- **Glucose input**: the daily-log glucose row replaces the free-text 餐前/餐後
  quick-picks with a structured **空腹 / 餐前 / 餐後 picker** (`ChoiceChip`s) that sets
  the reading's meal context (tapping the selected chip clears it).
- New i18n keys for the four meal contexts (en + zh-Hant + zh); the now-unused
  free-text quick-pick keys are removed.

Frontend-only. The other views (weight, body fat, blood oxygen, BP & pulse) and
their bands are unchanged.

## Capabilities

### Modified Capabilities

- `trend-combined-view`: the trend chart plots one point per reading on a time
  axis, and the glucose view splits by meal context into per-context lines over a
  glucose normal band; glucose readings are recorded with a structured meal
  context.
