## Why

The backend now persists a per-day vitals record (`/api/vitals`, life-os-backend
PR #18). Users need a UI to record their weight, body fat, and repeated
blood-pressure, blood-glucose, and blood-oxygen readings. It is the fourth daily
health tracker, so it lives as a fifth tab in the daily-log shell, sharing its
viewed day — like the bowel tab, but larger: two scalar fields plus three
add/remove reading lists.

## What Changes

- **New `vitals` context** (`lib/contexts/vitals/`): `VitalsDay { day, weightKg?,
  bodyFatPct?, bpReadings, glucoseReadings, spo2Readings }` with the reading types
  (`BpReading{systolic,diastolic,pulse?}`, `GlucoseReading{label,value}`,
  `Spo2Reading{spo2,pulse?}`) + `VitalsRepository`; `GetVitalsDay` /
  `SaveVitalsDay` use cases; `HttpVitalsRepository` (GET/PUT `/api/vitals`,
  snake_case contract, bearer token, 401→reauth); `VitalsController` +
  `VitalsScreen`.
- **A fifth tab in the diet shell**: `DietShellScreen`'s bottom `NavigationBar`
  gains a **數值 (Vitals)** destination after 今日 / 目標 / 飲水 / 排便, showing
  `VitalsScreen` for the shell's viewed day, with `vitalsController.load(token,
  _day)` called in `_load()` and `_reloadCurrentDay()` (the shell owns loading).
- **VitalsScreen UI**: a date + today/history header; weight and body-fat fields
  (nullable); and three list editors — blood pressure (systolic/diastolic/pulse
  per row), glucose (a label with 餐前/餐後 quick-picks + a mg/dL value per row),
  and blood oxygen (SpO₂ + optional pulse per row) — each with add/remove; plus a
  **Save** button that upserts the whole day (draft state, an unsaved-changes cue,
  disabled while saving, a SnackBar on failure — mirroring the bowel screen).
  Reuses `LedgeCard`, `AsyncStateScaffold`, `TrackerDayHeader`,
  `NumericAmountField`; the three near-identical list editors share a screen-local
  generic section widget to avoid duplication.
- **DI** threaded main.dart → `App` → `_AuthenticatedHome` → `HomeScreen` →
  `DietShellScreen` (mirroring `bowelController`). New i18n keys (en + zh-Hant +
  zh base); l10n regenerated.

Frontend-only; consumes the existing backend API. No change to other tabs beyond
adding the vitals tab.

## Capabilities

### Added Capabilities

- `vitals`: record the day's health metrics — weight, body fat, and repeated
  blood-pressure, blood-glucose, and blood-oxygen readings — from a 數值 tab in the
  daily-log shell, saved to the backend, viewable per day.
