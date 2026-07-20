# Design — Quantity card as a bottom sheet

## Context

`diet_shell_screen.dart._openLogEntry(item)` currently `Navigator.push`es a
full-screen `LogEntryScreen` (Scaffold + AppBar) hosting `QuantityCard`; on save it
runs `onSaved` (reload + snackbar) and pops. The edit flow already uses a bottom
sheet: `_openEditEntry` calls `showModalBottomSheet(isScrollControlled: true,
builder: EditEntryScreen)` (PR #14). `QuantityCard` currently includes meal
`ChoiceChip`s + a snack-label `TextField` (`_snackLabelText`), but the meal is
already set by the session `_currentMeal` (passed via `start(item, meal:, snackLabel:)`
by `_openLogEntry`, per PR #20/#22). Follow the frontend CLAUDE.md.

## Decisions

### D1 — Open the quantity card as a bottom sheet

`_openLogEntry` switches from `Navigator.push(LogEntryScreen)` to
`showModalBottomSheet(context, isScrollControlled: true, builder: …)` — same shape
as `_openEditEntry`. The sheet body is the `QuantityCard` (post-D2) wrapped so the
keyboard doesn't cover it: `Padding(padding: MediaQuery.of(context).viewInsets)`
around a scrollable content column (mirror how EditEntryScreen handles it). The
full-screen `LogEntryScreen` (Scaffold/AppBar) is removed; the sheet body is a thin
widget owning the `QuantityCard`. **Pop is the sheet's own responsibility, from the
sheet's own context** — mirror `EditEntryScreen`: on a successful save the sheet
body calls `Navigator.of(context).pop()` where `context` is inside the sheet, then
invokes the passed `onSaved`. The shell's `_onEntrySaved` stays **pop-free** (only
reload + snackbar) — it must NOT also pop, or it would target the root navigator's
topmost route by accident. So: sheet body pops itself + calls onSaved; shell
onSaved just reloads + shows the "added to <meal>" snackbar. The dictionary, never
covered, is right there for the next pick.

The card's primary button reads **"add to \<meal\>"** (was "save"): the sheet
resolves the session meal's display name (standard meals via `dietMeal*`, a snack
via `controller.snackLabel`) and uses a new `dietAddToMealButton(meal)` ARB string.
The now-unused `dietLogEntryTitle` ARB key (the removed AppBar title) is deleted
(orphan from this change).

### D2 — Drop the meal selection from the card

Remove from `QuantityCard`: the meal `Wrap` of `ChoiceChip`s
(`meal-chip-breakfast/lunch/dinner/snack`), the `isSnack` snack-label `TextField`
block, and the `_snackLabelText` controller (+ its init/dispose). The card no
longer lets the user change the meal — the entry's meal comes wholly from the
session (`controller.meal` / `controller.snackLabel`, seeded by `start`). `save`
already uses `controller.meal`/`snackLabel`, so nothing about persistence changes;
only the in-card UI to edit them is gone. To change a single entry's meal the user
switches the logging bar before picking (or edits the entry afterward). The
remaining card: food name + basis + unit(bowl/gram) toggle + quantity stepper
(tap-to-type kept) + portion preview + eaten-at time + the "add to <meal>" button.

### D3 — Add dismisses the sheet; continuous logging preserved

The add button saves via the controller; on success the sheet pops and `onSaved`
(reload + snackbar) runs — `_currentMeal` is unchanged (still the session meal), so
the next pick opens a fresh sheet in the same meal. The logging bar and its "Done"
(return to Today) are untouched. Manual entry (`ManualEntryScreen`) stays
full-screen this change (follow-up). The edit sheet stays separate (no merge).

## Testing

- Widget (fake controllers/repos, `l10nTestApp`, pinned clock):
  - tapping a dictionary item opens a **bottom sheet** (not a pushed full-screen
    route) — assert the sheet content is present and it's a modal sheet.
  - the sheet has **no meal chips** (`meal-chip-*` findsNothing) and no snack-label
    field; it shows name/basis/unit/stepper/preview/time/add.
  - adding pops the sheet, the dictionary is still shown, and the "added to <meal>"
    snackbar appears; `_currentMeal` unchanged so a second pick is the same meal.
  - keyboard: the sheet content sits above `viewInsets` (structural assertion that
    the padding wraps the content).
  - quantity/gram conversion, preview scaling, eaten-at edit, and tap-to-type
    number editing still work (regression, moved into the sheet).
- Controller: unchanged — `LogEntryController.start(meal:, snackLabel:)` still seeds
  the session meal; `save` uses it.
