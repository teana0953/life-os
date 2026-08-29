## Why

The menstrual mini-calendar marks which days belong to a period, but not *which
day of the period* each one is. To answer "how long has this been running?" or
"which day was the heaviest?" the user has to count filled circles by hand, or
leave the calendar and read the overview card — which only ever reports the
count for **today**, and only while a period is ongoing. The information the
calendar already has (each period's start date) is one derivation away from the
number the user is counting for.

## What Changes

- Each period day in the menstrual mini-calendar shows its **cycle day number**
  (day of the period, `startDate` = day 1) alongside the existing date number,
  inside the same 32×32 circular marker.
- Non-period days (plain days, today, the predicted next start) are unchanged —
  they carry no cycle-day number, because they belong to no period.
- Where overlapping periods both cover a day, the number comes from the period
  with the **largest `startDate` among those covering that day** — the same
  tie-break `computeNextPeriodStatus` already applies, so the calendar and the
  overview card cannot disagree about the same day.
- The day cell's accessibility label for a period day names the cycle day, so a
  screen-reader user gets the number the sighted user reads.
- No backend change: the number is derived on the client from the periods
  already in `MenstrualOverview`.

## Capabilities

### New Capabilities

_None._

### Modified Capabilities

- `menstrual-ui`: the "Mini-calendar of periods" requirement gains the
  obligation to show, on each period day, which day of that period it is —
  including the overlap tie-break and the accessible-label obligation.

## Impact

- `lib/contexts/menstrual/presentation/menstrual_calendar.dart` — a new
  derivation (cycle day for a date) replacing/extending the existing
  `isMenstrualPeriodDay` call site, and the `_MenstrualDayCell` layout inside
  the 32×32 marker.
- `lib/l10n/app_en.arb`, `lib/l10n/app_zh_Hant.arb` (+ regenerated
  `lib/l10n/generated/`) — the cycle-day accessible label, and any visible
  cycle-day affix.
- `test/contexts/menstrual/` — unit tests for the derivation and widget tests
  for the cell rendering and semantics.
- No change to `domain/`, `application/`, `infrastructure/`, or the backend
  API.
