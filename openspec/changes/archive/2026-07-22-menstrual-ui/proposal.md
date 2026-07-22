## Why

The backend now persists menstrual periods and derives cycle statistics
(`/api/menstrual`, life-os-backend PR #21). Users need a UI to record their
periods and see their cycle at a glance. This is the second tracker to live in
the daily-log shell's **更多 (More)** overflow menu (after exercise), and — unlike
the day-keyed trackers — it is **not tied to the shell's viewed day**: a menstrual
record is a period (a date range), and the screen shows the whole history as a
mini-calendar plus cycle statistics.

## What Changes

- **New `menstrual` context** (`lib/contexts/menstrual/`): `MenstrualPeriod {id,
  startDate, endDate?}`, `MenstrualStats {averageCycleDays?, averagePeriodDays?,
  predictedNextStart?}`, `MenstrualOverview {periods, stats, lastPeriod}` +
  `MenstrualRepository` port + typed exceptions (reauth/fetch, mirroring the
  exercise context); `GetMenstrualOverview`, `AddPeriod`, `UpdatePeriod`,
  `DeletePeriod` use cases; `HttpMenstrualRepository`; `MenstrualController` +
  `MenstrualScreen`.
- **Immediate add/edit/delete** (mirrors `WaterController._apply`): each mutation
  POSTs/PATCHes/DELETEs and re-reads the overview — not draft-then-save. PATCH is
  a partial update (only changed fields; `end_date: null` clears the end date to
  reopen a completed period).
- **`MenstrualScreen` UI** (a **mini-calendar** as the primary view): a month
  grid (Sunday-first, mirroring the diet calendar's rendering) that marks each
  period's days (start→end inclusive) and the predicted next start with a
  distinct marker; month prev/next navigation. Tapping a day opens an add/edit
  flow (a start date, an optional end date; clearing the end date reopens the
  period; delete). Plus a statistics card (average cycle length, average period
  length, predicted next start — each shown as "—" when null) and the most recent
  period. Reuses `LedgeCard`, `AsyncStateScaffold`.
- **更多 menu tile**: `_MoreMenuScreen` (in `diet_shell_screen.dart`) gains a
  **生理期** tile that pushes `MenstrualScreen` with an `AppBar` back button
  (mirroring the exercise/更多 pattern). The shell loads `menstrualController`
  **once** in `_load(token)` (day-independent — NOT in `_reloadCurrentDay`, since
  changing the viewed day does not affect periods).
- **DI** threaded `main.dart` → `App` → `_AuthenticatedHome` → `HomeScreen` →
  `DietShellScreen` (mirroring `exerciseController`). New i18n keys (en + zh-Hant
  + zh base); l10n regenerated.

Frontend-only; consumes the existing backend API. No behavior change to the other
tabs or trackers beyond adding the 生理期 tile to 更多.

## Capabilities

### Added Capabilities

- `menstrual-ui`: record menstrual periods and view the cycle — a mini-calendar
  marking period days and the predicted next start, plus average cycle/period
  length and the last period — from a 生理期 screen reached via the daily-log
  shell's 更多 overflow, saved to the backend. Add / edit (including reopening a
  completed period) / delete a period.
