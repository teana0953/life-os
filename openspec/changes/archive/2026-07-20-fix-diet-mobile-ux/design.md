# Design — Diet mobile UX fixes

## Context

Post-#27, the Today view (`today_screen.dart`) renders (loaded): 4
`CategoryProgressBar`s → the three standard meals as **fixed cards** in
`_standardMeals` order (always shown, `mealsByName[meal]` may be null =
empty) → a "點心" section title + add-snack button → the snack-group cards
(`dayLog.meals` where `!_isStandardMeal`). Add-food happens in a bottom sheet
(`_DictionarySheet` in `diet_shell_screen.dart`) hosting `_LoggingMealBar`
(the current-meal chips + snack rename pencil) over `DictionaryScreen`
(search + results). The day header is `_DayNavBar` (Mascot + title + a
date-navigation Row + dictionary/home buttons). All established styles/keys
(`_MealCard`, `add-to-meal-<meal>`, `add-to-snack-<name>`, `add-snack`,
`logging-meal-*`) stay. The user is on a phone; several of these overflow or
hide content at narrow widths. Follow the frontend CLAUDE.md.

## Decisions

### D1 — Today timeline: interleave snacks with meals by eaten-at

`today_screen.dart`'s loaded body sorts **all groups that have entries**
(standard meals + snack groups) together by `_earliestEatenAt` ascending
(earliest first), rendered as `_MealCard`s in that single order — a 15:00
snack falls between a 12:30 lunch and a 19:00 dinner. **Empty** standard
meals (in `dayLog` there is no group, so no eaten-at) are rendered *after*
the logged groups as empty `_MealCard`s in fixed breakfast→lunch→dinner
order, each keeping its `add-to-meal-<meal>` control. This keeps ordering
deterministic (logged groups strictly by time, empties by the canonical meal
order at the end) so widget tests can assert the sequence.

- Sort stability: sort by `(earliestEatenAt, _standardMealsRank)` — if two
  groups share an eaten-at, the standard-meal rank (breakfast<lunch<dinner<
  snack) breaks the tie deterministically; snack groups tie-break by name.
- The "start a new snack" affordance (`add-snack` → `onAddSnack`) moves to a
  slim control shown with the empty-meals section (or just below the logged
  list when all meals have entries), so "new snack" is always reachable; the
  per-group "add to this snack" (`add-to-snack-<name>`, #27) stays on each
  snack card. Both callbacks and keys are unchanged.
- `_mealLabel` gains a `snackMealValue` (`'snack'`) → localized
  `dietSnackBaseName` fallback so a bare unnamed snack reads "點心", not the
  raw English `snack`. (Named snacks already carry their display name as the
  group `meal`.)

### D2 — Day header date never overflows

In `_DayNavBar`, the inner date Row (`Row(mainAxisSize: min)` inside the
`Expanded` InkWell) has a plain `Text(dateText)` that can exceed the available
width at phone sizes (Mascot + two trailing IconButtons + two chevron
IconButtons leave little room) → RenderFlex overflow. Wrap `Text(dateText)`
in `Flexible(child: Text(…, overflow: TextOverflow.ellipsis, maxLines: 1))`
so it ellipsizes instead of overflowing; the calendar icon stays visible. No
behavior change — tapping the row still opens the calendar.

### D3 — Logging bar snack name + no overflow

`_LoggingMealBar`: the four meal `ChoiceChip`s live in a `Wrap` (already
wraps, no horizontal overflow); the problem is the snack **rename pencil**, a
default 48px `IconButton` that misaligns with ~32px chips and can wrap alone.
When a snack is selected, render the current snack name + rename affordance as
one coherent unit: show `currentMealLabel` (the actual "點心3"/"下午茶", not
the generic chip label) with a compact, chip-height edit control next to it
(e.g. an `InputChip`/`ActionChip`-style pill or a `visualDensity`-compact
`IconButton` sized to the chips), kept in the same `Wrap` run so it never
overflows. Keep keys `logging-meal-chip-snack`,
`logging-meal-bar-rename-button`, and the rename field/confirm/cancel keys.
The rename `TextField` already prefills `currentMealLabel` — unchanged.

## Testing

- Widget (fake controllers/repos, `l10nTestApp`, pinned clock; narrow surface
  via `tester.binding.setSurfaceSize` + `addTearDown` reset):
  - Today: a day with breakfast 08:00, snack "點心2" 10:30, lunch 12:30,
    snack 15:00, dinner 19:00 renders the cards in that eaten-at order;
    empty standard meals appear after the logged ones and still expose their
    add control; the new-snack control is present.
  - Today: an unnamed snack group (`meal: 'snack'`) shows the localized "點心".
  - Day header at a narrow width (e.g. 320px) shows no overflow and the
    calendar icon is still present.
  - Logging bar with a snack selected shows the current snack's name and the
    rename control together, no overflow at a narrow width; renaming still
    works via the existing keys.

> Descoped: the dictionary-sheet-keyboard fix (originally D2) was removed from
> this change — it is a Flutter-web-specific issue (no keyboard `viewInsets` on
> web; the browser uses the visual viewport) that can't be verified without
> on-device web testing. Tracked as a separate follow-up.
