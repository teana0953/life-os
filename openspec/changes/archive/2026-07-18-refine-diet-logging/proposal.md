# Proposal: refine-diet-logging

## Why

Reviewing the shipped diet UI against the design mockup surfaced two functional
gaps: you can only log foods from the dictionary (no way to type your own), and
Today shows only a single number (`staple`) per logged food instead of that
food's portions across its groups — so an entry like 蛋 (1 meat) shows "0".
Both were reviewed-and-intended behaviors that the first pass under-built. The
backend already supports both (`logManualFoodEntry` accepts portions; entries
carry all four portion fields), so this is a front-end-only refinement.

## What Changes

- **Manual food entry**: add a manual logging path alongside dictionary logging —
  `DietLogRepository.logManualEntry` (optional name, per-group portions with
  decimals, meal, eaten-at) over the backend's manual `POST /api/diet-entries`
  path (`portions` + `name` + `meal` + `eaten_at`, no `food_item_id`); a
  `LogManualEntry` use case; a manual-entry form (name + four portion inputs +
  meal chips + eaten-at, defaulting to now) reached from a "找不到? 手動輸入" entry
  point at the bottom of the dictionary/logging flow; Today refreshes on save
  (same `onSaved` pattern as dictionary logging).
- **Per-food portion pills on Today**: each logged food shows its portions across
  every group it contributes to (staple/meat/fruit/veg) as category-colored,
  labeled pills — instead of a lone `staple` number.

## Capabilities

### New Capabilities
<!-- None. -->

### Modified Capabilities
- `health-diet`: adds manual food entry (name + per-group portions, reachable
  from the logging flow); Today shows each logged food's portions across all its
  groups rather than only staple.

## Impact

- **New**: `LogManualEntry` use case, a manual-entry form widget + controller
  wiring, and a `logManualEntry` method on `DietLogRepository` /
  `HttpDietLogRepository`; new ARB keys (en + zh-Hant).
- **Modified**: `today_screen.dart` (portion pills per entry), the dictionary/log
  flow (manual entry point), `main.dart` wiring, tests.
- **Backend**: consumes the existing manual `POST /api/diet-entries` — no change.
- **Out of scope** (visual polish, separate follow-up): Today progress as a
  horizontal bar, meal cards with emoji/time styling, and +/- steppers for the
  target.
