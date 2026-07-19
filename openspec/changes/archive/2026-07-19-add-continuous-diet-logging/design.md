# Design — Continuous diet logging + snack auto-numbering

## Context

`DietShellScreen` hosts the diet tabs in an `IndexedStack` (Today / Dictionary /
Target) and owns `_day`, the controllers, and `_openLogEntry`/`_openManualEntry`
(which `push` a full-screen quantity card). `LogEntryController.start(item)`
hard-resets `meal = 'breakfast'`; the quantity card has its own meal chips
(breakfast/lunch/dinner/snack + a custom snack label). `getDayDietLog` groups a
day's entries by the exact `meal` string. Follow the frontend CLAUDE.md.

## Decisions

### D1 — A "current meal" session state on the shell

`DietShellScreen` gains `String _currentMeal` (session state, default
`'breakfast'`). The Dictionary tab is wrapped like the Today tab —
`Column(_LoggingMealBar(...), Expanded(DictionaryScreen(...)))` — with a new
`_LoggingMealBar` on top: a meal segmented control (breakfast/lunch/dinner/snack)
and a "Done" button. Because a snack's `_currentMeal` is a display name ("點心2")
that is NOT one of the four segment values, the **selected segment is derived**,
not equal to `_currentMeal`: `_currentMeal ∈ {breakfast, lunch, dinner}` selects
that segment, otherwise the snack segment is selected (any non-standard name is a
snack). This same "is `_currentMeal` a snack?" test (name not in the three
standard meals) is reused by D5's recompute gate. Changing the segment updates
`_currentMeal` (for snack, see D5); "Done" switches back to the Today tab
(`setState(_index = 0)`). Colors/shapes from theme, strings from ARB.

### D2 — start() takes the current meal (stop hard-resetting to breakfast)

`LogEntryController.start` and `ManualEntryController.start` gain a
`String meal` (and, for snack, `String snackLabel`) parameter, seeding the card
from the session instead of `'breakfast'`. `DietShellScreen._openLogEntry` /
`_openManualEntry` pass the current meal via the **D5 seam** — a standard meal as
`start(meal: 'lunch')`; a snack as `start(meal: snackMealValue, snackLabel:
<snack name>)` (never the bare snack name as `meal`). `eatenAt` still defaults to
`now` per entry (independent times are correct). The quantity card's own meal
chips still let the user override for that one entry, but the session default is
the current meal.

### D3 — Save feedback, stay on the dictionary, keep the meal

The quantity card / manual entry still saves and `pop`s back to the dictionary
(current behavior). The shell's `onSaved` callback additionally shows a localized
"Added to <meal>" `SnackBar` (via `ScaffoldMessenger`) and reloads Today's data.
`_currentMeal` is NOT changed on save, so the next pick stays in the same meal —
the user keeps picking. (The meal-label text for the snackbar is resolved in the
screen from the meal value: standard meals localize via existing keys; a snack
group name like "點心2"/"下午茶" is shown as-is.)

### D4 — "Done" returns to Today

The `_LoggingMealBar`'s "Done" button calls back to the shell to switch to the
Today tab. No new route; just `setState(_index = 0)`. (The bottom nav already lets
the user leave; "Done" is the explicit in-context exit after a batch.)

### D5 — Snack auto-numbering (stored via the existing snack-label mechanism)

**Storage model.** A snack group's `meal` value is its display name — the base
snack word or that word + a number ("點心", "點心2", …) or a rename ("下午茶").
This reuses the card's existing snack path: the quantity card / manual entry
store `meal = (meal == snackMealValue && snackLabel.isNotEmpty) ? snackLabel :
meal`. So the shell always supplies a **non-empty snack label** (the numbered
default or the rename), which means snacks are always stored under that name and
the label-less `'snack'` code is never newly produced. The session therefore
never emits a bare `'snack'`; any pre-existing `'snack'` rows are legacy edge
data (see below).

**Card seam (fixes the isSnack break).** `_currentMeal` for a snack holds the
snack *name* ("點心2"), but the shared meal chips compute `isSnack == snackMealValue`.
So the shell hands snacks to the controllers as **`start(meal: snackMealValue,
snackLabel: <the snack name>)`** — never `start(meal: '點心2')`. That keeps the
snack chip highlighted, prefills the (editable) snack-label field with "點心2",
and the card stores `meal = '點心2'`. Standard meals pass `start(meal: 'lunch')`
with no label. Same for manual entry.

**Numbering.** `nextSnackName(List<String> mealNames, String snackWord)`:
- Snack series = names matching `^<snackWord>(\d+)?$` (localized `snackWord`,
  e.g. "點心"/"點心2"); a rename ("下午茶") and standard meals are ignored.
- `maxN` = max number among them (bare "<snackWord>" = 1, "<snackWord>k" = k);
  none → empty.
- Result: empty → "<snackWord>" (no number); else "<snackWord>{maxN + 1}". Using
  max+1 (not count) avoids colliding with an existing group after a deletion.

Pure and widget-independent, so unit-testable.

**Recompute gate (fixes the mid-batch re-increment).** `nextSnackName` is called
**only on a real transition into snack** — the meal-segment handler recomputes the
snack name only when the newly-selected segment is snack AND the previous
`_currentMeal` was not a snack (ignore re-taps on the already-selected snack). A
whole session keeps that one name (in `_currentMeal`, which D3 does not change on
save), so every pick lands in one group even though a save reloads Today and adds
the group to `dayLog`. The number only advances the next time the user leaves and
re-enters snack.

**Rename.** A small ✎ next to the snack segment opens an inline field; confirming
sets `_currentMeal` to the typed name (still handed to the card as
`meal=snackMealValue, snackLabel=<typed name>`).

**`snackWord` / locale.** `snackWord` is a dedicated new ARB key for the snack
base word (NOT the `dietAddSnack` chip copy). The stored value is the display
name, so numbering keys off the current locale's word; a mid-session language
switch is an accepted edge (single-user app, one language in practice). Legacy
`'snack'`-code rows (from before this change) don't match the localized series and
so don't participate in numbering — acceptable given how few exist; `today_screen`
already renders `'snack'` as-is and this change doesn't regress that.

### D6 — i18n

New ARB (en + zh-Hant + zh): logging-bar "Logging to {meal}", "Done", snackbar
"Added to {meal}", a **dedicated snack base-word key** (per D5 — e.g.
`dietSnackBaseName` = "點心"/"Snack"; do NOT reuse `dietAddSnack` "新增點心"/"Add
snack", which would produce "新增點心2"), and the rename affordance label. No
hard-coded strings; regenerate l10n.

## Testing

- `nextSnackName` unit tests: no snacks → base word; one bare snack → "…2";
  bare + "…2" → "…3"; only "…2" present (bare deleted) → "…3" (max+1, no
  collision); a renamed group ("下午茶") is ignored; standard meals ignored.
- Controller: `start(meal: 'lunch')` seeds meal = lunch (not breakfast);
  snack start seeds the snack label.
- Widget (fake controllers/repos, `l10nTestApp`, pinned clock): switching the bar
  segment updates the seeded meal; picking a food opens the card defaulted to the
  current meal; saving shows the "Added to <meal>" snackbar and keeps the meal so
  a second pick is still that meal; "Done" returns to Today; switching to snack
  shows the numbered default; rename updates the session name.
