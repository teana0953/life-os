# Diet mobile UX fixes: timeline ordering + narrow-screen layout

## Why

The user tested the diet module on a **phone** and hit several narrow-screen
problems on the Today view and the add-food bottom sheet, plus one ordering
request:

- Snacks live in a separate "點心" section at the bottom, divorced from the
  meal they happened around — a snack eaten at 15:00 should sit between lunch
  and dinner chronologically, not below everything.
- The Today day-navigation header (date text + calendar icon) overflows
  (RenderFlex "跑版") on narrow phone widths.
- In the add-food logging bar, the snack **rename pencil** misaligns/wraps on
  mobile, and the snack chip only reads the generic "點心" — you can't tell
  whether the current snack is "點心3" or a renamed "下午茶", so you don't know
  which snack you're logging into.

## What Changes

- **Today timeline ordering**: all meal groups that have entries — standard
  meals *and* snack groups — are ordered together by their earliest eaten-at
  time (earliest first), interleaved. Standard meals with no entries are shown
  after the logged groups as empty cards (breakfast, lunch, dinner order),
  each still able to add a food. A "start a new snack" control remains
  available. Per-category progress bars, portion pills, labels, and times are
  unchanged.
- **Day header fits narrow screens**: the date text ellipsizes as needed so
  the chip + date + calendar icon never overflow at phone widths.
- **Logging bar snack name + layout**: when the current meal is a snack, the
  bar clearly shows the current snack's name (e.g. "點心3"/"下午茶") with the
  rename control aligned next to it, and the meal controls don't overflow on
  narrow widths.
- **Minor**: an unnamed snack (stored as the bare `snack` value) shows the
  localized "點心" on Today rather than the raw English `snack`.

## Impact

- Affected spec: `health-diet` — Today ordering (MODIFIED), continuous-logging
  snack-name visibility (MODIFIED), add-to-snack wording (MODIFIED),
  narrow-screen layout (ADDED).
- Affected code: `today_screen.dart` (timeline ordering, empty-meal section,
  snack-add entry, `snack` label fallback), `diet_shell_screen.dart`
  (`_DayNavBar` date overflow, `_LoggingMealBar` snack name + layout).
  Frontend only.
- Descoped to a separate follow-up: the dictionary-sheet-keyboard fix (a
  Flutter-web-specific issue that needs on-device web verification).
