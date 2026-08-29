## Context

See `proposal.md` — Why. The constraints that shape the approach:

- The mini-calendar (`MenstrualCalendar`) lays out 7 `Expanded` cells per row.
  On a 320dp phone that is ~45dp per cell; each cell is a 32×32 circular
  marker inside 6dp of vertical padding, giving the 44dp row height every
  calendar in the app shares.
- The circle is not a square: at its vertical middle the usable chord is
  ~28dp, and it narrows fast above and below that.
- `isMenstrualPeriodDay` is a boolean predicate over *all* periods. It answers
  "is this a period day", and deliberately does not say *which* period — the
  new number needs that.
- `computeNextPeriodStatus` already resolves the same overlap question for the
  overview card (scan every period covering today, keep the one with the
  largest `startDate`) and counts `startDate` as day 1, uncapped.
- Widget tests cannot see the real font (see root `CLAUDE.md` — Design
  system): every glyph paints as a `fontSize` square, so no ordinary widget
  test can prove the two-line layout fits. Only
  `test/shared/theme/real_font_metrics_test.dart` loads the real `.ttf`.

## Goals / Non-Goals

**Goals:**

- Read the length of a period, and the position of any day within it, off the
  calendar without counting cells.
- Keep one source of truth for the overlap rule, so the calendar and the
  overview card cannot disagree about a day.
- Keep the calendar's row rhythm and overall height unchanged.

**Non-Goals:**

- Any change to `domain/`, `application/`, `infrastructure/`, or the backend.
- Showing a cycle-day number on non-period days (a "days since last period"
  running count) — a different feature with a different meaning.
- Changing the period / predicted-next markers themselves, or the day-tap
  behaviour.

## Decisions

### 1. Derivation: a nullable `menstrualCycleDay(day, periods, today)`

Add a function returning `int?` — the 1-based day of the period covering
`day`, or `null` when no period covers it. It scans every period, keeps the
one with the largest `startDate` among those covering `day`, and returns
`daysBetween(start, day) + 1`.

The predicate `isMenstrualPeriodDay` becomes redundant: `cycleDay != null` is
exactly the same condition, derived from the same scan. Collapse the cell's
`isPeriod` flag into the nullable number rather than computing the range twice
per cell (7×6 cells × N periods, rebuilt on every month change).

*Why the largest-start tie-break, not the earliest:* it is the rule
`computeNextPeriodStatus` already applies, and the spec's "the two never
disagree about a day" scenario is only satisfiable if both use it. The
domain function is not reused directly — it answers only about *today* and
returns a card state, not a per-date number — so the rule is duplicated in
one small function, the same way `next_period_status.dart` already duplicates
`daysBetween` to stay Flutter-free. A shared helper would have to live in
`domain/` and be parameterised over an arbitrary date; that is a bigger
change than the duplication it removes.

*Uncapped, per the spec:* an open period reading "41" is the signal it was
never closed — the same reasoning the overview card's day count already
carries.

### 2. Presentation: stacked two-line content inside the existing 32×32 circle

The marker keeps its size, shape and colours. On a period day its child
becomes a two-line `Column`:

- day-of-month in `bodySmall` (down from `bodyMedium`), tight line height;
- the cycle-day digits below it in `labelSmall`, at ~80% opacity of the same
  `onPrimary` colour.

Bare digits, no localized affix ("D3" / "第 3 天"): a word does not fit in a
28dp chord at any legible size. The meaning is carried instead by a **third
legend entry** below the grid ("small number = day of period") and by the
accessible label (decision 3).

*Text scaling:* the two lines total ~24dp at scale 1.0 and overflow the circle
past ~1.3×. Clamp the marker's `textScaler` to a 1.3 maximum
(`TextScaler.clamp(maxScaleFactor: 1.3)`) rather than letting it overflow or
letting the circle grow and break the row rhythm. This is an accessibility
trade-off taken knowingly: the number is fully available, unclamped, to a
screen reader, and the day-of-month digits remain legible at the clamp.

Alternatives considered:

- **Inline on one line ("5·3" or "5 (3)")** — four-plus glyphs at a legible
  size need ~30dp of a ~28dp chord, before CJK or any text scaling. Rejected:
  overflows at default settings on the narrowest supported phone.
- **A badge in the cell's corner, outside the circle** — cells are `Expanded`
  with only ~6dp of gutter each side, so badges from adjacent days collide;
  and a corner badge reads as a notification count, not a position in a
  sequence. Rejected.
- **Replace the date number with the cycle day on period days** — breaks the
  one thing a calendar cell is for and makes the grid unscannable when
  looking for a date. Rejected.
- **A line of text below the circle, inside a taller cell** — the clearest to
  read, but grows every row from 44dp to ~56dp, pushing the legend and the
  statistics below the fold on a phone, and desynchronising this calendar from
  the other three that share the 44dp rhythm. Rejected as costing more than
  the number is worth.
- **Colour/opacity gradient across the period instead of a number** — conveys
  position but not the actual count, which is the question being asked.
  Rejected.

### 3. Semantics: extend the existing key, do not add one

`menstrualDaySemanticPeriod` currently takes one placeholder (the date). Give
it a second (the cycle day) rather than introducing a parallel key.

Every period day has a cycle day by definition — there is no remaining state
in which the one-placeholder form would still be used — so a new key would
leave the old one dead, and two keys would invite the two forms to drift
apart. The other three semantic keys (`…Predicted`, `…Today`, plain date) are
untouched.

One genuinely new visible key is needed for the legend entry
(`menstrualLegendCycleDay`), plus the second placeholder's `description` in
`app_en.arb`.

## Risks / Trade-offs

- **The two-line layout may not fit the real font at any scale > 1.0, and no
  ordinary widget test can tell.** → Add the check to
  `test/shared/theme/real_font_metrics_test.dart`, the one file that loads the
  real `.ttf`, rather than to the menstrual widget tests where it would pass
  vacuously.
- **Clamping `textScaler` reduces the number's size for users who enlarged
  system text.** → Accepted deliberately; the unclamped number is in the
  accessible label, and the clamp applies only inside the marker, not to the
  legend or the statistics.
- **Two places now encode the largest-start overlap rule** (`domain/
  next_period_status.dart` and the calendar's derivation). → The spec pins the
  agreement with a scenario, and a unit test asserts the calendar's number for
  today matches the overview card's day count for the same overview.
- **Bare digits are ambiguous on first sight** ("is 3 a date or a day?"). →
  The legend entry, the size/weight difference, and the fact that the number
  only ever appears on a filled period day.
- **A subset font gap:** the visible affix was dropped anyway, so no new glyph
  class is introduced — digits only, all present in the bundled subset.

## Migration Plan

Not applicable — presentation-only, no persisted data, no API surface. Rollback
is reverting the change.
