## Why

The backend now persists a per-day bowel record (`/api/bowel`, life-os-backend
PR #17). Users need a UI to record each day's count, whether it was normal, and a
note. It's the third daily health tracker after diet and hydration, so it lives
as a fourth tab in the daily-log shell, sharing its viewed day — like the water
tab, but simpler (a small form + Save, no target/progress).

## What Changes

- **New `bowel` context** (`lib/contexts/bowel/`): `BowelDay { day, count,
  isNormal, note }` (`isNormal` is `bool?` — null means not recorded) +
  `BowelRepository` port; `GetBowelDay` / `SaveBowelDay` use cases;
  `HttpBowelRepository` (GET/PUT `/api/bowel`, snake_case `day/count/is_normal/
  note`, bearer token, 401→reauth); `BowelController` + `BowelScreen`.
- **A fourth tab in the diet shell**: `DietShellScreen`'s bottom `NavigationBar`
  gains a **排便** destination after 今日 / 目標 / 飲水, showing `BowelScreen` for
  the shell's viewed day (`_day`), with `bowelController.load(token, _day)` called
  in `_load()` and `_reloadCurrentDay()` (the shell owns loading).
- **BowelScreen UI**: a viewed-date + today/history title header; a count stepper
  (次數, −/＋, min 0); a normal/abnormal `SegmentedButton` (未選/正常/異常 — nullable,
  unselected until chosen); a multiline note field; and a **Save** button that
  upserts the whole record (disabled while saving; a SnackBar on failure). The
  controller holds an editable draft populated on load and reset on a day change.
  Loading/error/reauth via the shared `AsyncStateScaffold`; sections in
  `LedgeCard`.
- **Reuse + one extraction** (per request — reuse shared, extract genuine
  duplication): reuse `LedgeCard` / `AsyncStateScaffold` / `NumericAmountField` /
  `day_format`; and extract the **date + today/history title header** — now
  duplicated in `water_screen` and needed again here — into a shared
  `TrackerDayHeader`, migrating `water_screen` to it (behavior/pixels unchanged).
- **DI** threaded main.dart → `App` → `_AuthenticatedHome` → `HomeScreen` →
  `DietShellScreen` (mirroring `waterController`). New i18n keys (en + zh-Hant +
  zh base); l10n regenerated.

Frontend-only; consumes the existing backend API. No change to diet/water
behavior beyond adding the bowel tab and the header extraction.

## Capabilities

### Added Capabilities

- `bowel`: record the day's bowel movements — a count, an optional normal/abnormal
  flag, and a free-text note — from a 排便 tab in the daily-log shell, saved to the
  backend, viewable per day.
