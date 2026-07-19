# View diet history and edit past entries

## Why

The diet UI only shows *today*. The user wants to look back at any past day and
fix a past entry (wrong portions, name, meal, or time). The backend already
supports this (per-day fetch, a month's logged days, PATCH-update, delete); the
frontend needs the navigation and editing UI. UX was confirmed via mockup
(artifact a14939c4): a per-day screen with date navigation + a calendar, and a
bottom-sheet editor reusing the manual-entry fields.

## What Changes

- **Day navigation**: the Today screen becomes a per-day screen — a header with
  `‹ date ›` and a calendar button. Changing the day reloads that day's log and
  target (the target carries forward per the backend). Future days are blocked
  (the `›` arrow stops at today; the calendar disables future dates).
- **Calendar with markers**: the calendar marks days that have at least one
  entry (via the new `logged-days?month=` endpoint) and jumps to a picked day.
- **Edit a past entry**: tapping an entry opens a bottom sheet prefilled with its
  name, four portion values, meal, and eaten-at time. Saving PATCH-updates the
  entry; a delete action removes it. Either refreshes the current day.
- Repository/use cases gain `updateEntry` (PATCH) and `loggedDays` (GET).

## Impact

- Affected spec: `health-diet` — new day-navigation and edit requirements.
- Affected code: `DietLogRepository` + `HttpDietLogRepository` (two methods),
  new use cases, `DietShellScreen` (mutable day + nav + calendar), `TodayScreen`
  (tappable entries), a new edit controller + bottom-sheet, shared portion-form
  widget, ARB copy. No backend change (endpoints already merged).
