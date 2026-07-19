# Design — Add to each meal directly from Today

## Context

`today_screen.dart` (loaded branch) is a `ListView`: four `CategoryProgressBar`s,
then either a `today-empty-state` or the `dayLog.meals` mapped to `_MealCard`s (in
eaten order). A generic FAB (`today-add-entry-fab`) calls `onAddEntry`, which the
shell wires to `setState(_index = 1)` (switch to Dictionary). PR #20 already built
the dictionary logging bar + `_currentMeal` session state + continuous logging +
"added" snackbar + `nextSnackName`; this change adds the entry points on Today and
reuses all of that. Meal grouping is by exact `meal` string; snacks store their
display name ("點心", "點心2", "下午茶"). Follow the frontend CLAUDE.md.

## Decisions

### D1 — Today: fixed breakfast/lunch/dinner cards + snack area, no FAB

The loaded body becomes: the four progress bars (unchanged), then **three fixed
meal cards in `breakfast, lunch, dinner` order** (always shown), then a **snack
area**. A helper groups `dayLog.meals` into `Map<String, MealGroup>` by meal name;
the three standard cards look up their group (possibly absent). The snack area
collects every group whose meal is **not** one of the three standard meals (the
snack series and renames) in eaten order.

A single `_MealCard` renders both states:
- **With entries**: today's look — emoji + earliest eaten-at time + entry rows
  (tappable to edit via `onEditEntry`) + portion pills, unchanged.
- **Empty**: the meal's emoji + name + a "not logged yet" line.
- Both carry a **"＋ add"** control (`Key('add-to-meal-<meal>')`) → `onAddToMeal(meal)`.

The snack area has a header + **"＋ add snack"** (`Key('add-snack')`) →
`onAddSnack`, and lists the snack groups as cards (each also tappable-to-edit; a
snack card's add re-enters that same snack name is out of scope — add-snack always
starts a new session).

The **generic FAB and `onAddEntry` are removed**. The old full-screen
`today-empty-state` (whole-day empty) is dropped — emptiness is now per card, so a
brand-new day simply shows three empty meal cards + an empty snack area, each
inviting an add. `dietDayEmpty` may be reused as a per-card "not logged yet" line
or replaced with a dedicated key.

`TodayScreen` gains `onAddToMeal(String)` and `onAddSnack()` callbacks (nullable,
mirroring `onEditEntry`); `signOut` and the error/reauth states are untouched.

### D2 — Shell wiring: add-to-meal / add-snack set the current meal + switch tab

`DietShellScreen` wires the Today tab's new callbacks:
- `onAddToMeal(meal)` → `setState(_currentMeal = meal; _index = 1)` — the logging
  bar (built from `_currentMeal`) now shows that meal, and the dictionary is
  focused, so the user picks a food straight into it. Reuses the D5 seam/segment
  logic from PR #20 unchanged.
- `onAddSnack()` → `setState(_currentMeal = nextSnackName(<day's meal names>,
  loc.dietSnackBaseName); _index = 1)` — starts the next snack session, same as
  switching the bar to snack, then focuses the dictionary.

No new route; both just set `_currentMeal` and select the dictionary tab. The
"Done" button on the logging bar still returns to Today (`_index = 0`).

### D3 — Unify snack wording

In `quantity_card.dart` and `portion_form_fields.dart`, the snack meal `ChoiceChip`
label changes from `loc.dietAddSnack` ("新增點心") to `loc.dietSnackBaseName`
("點心"). Behavior (selecting `snackMealValue`, showing the snack-label field) is
unchanged — only the chip text. `dietAddSnack` stays defined (harmless if unused
elsewhere); no key is deleted.

### D4 — i18n

New ARB (en + zh-Hant + zh): the per-card add label (e.g. `dietAddToMeal` "＋ Add"),
the empty-meal line if a dedicated key is preferred over reusing `dietDayEmpty`,
the snack-area title (e.g. `dietSnackAreaTitle` "Snacks"/"點心"), and the add-snack
label (`dietAddSnackButton` "＋ Add snack"). No hard-coded strings; regenerate l10n.

## Testing

- Widget (fake controllers/repos, `l10nTestApp`, pinned clock):
  - three standard meal cards always render (breakfast/lunch/dinner), in that
    order, even on an all-empty day; a meal with entries shows them + time.
  - tapping a card's add fires `onAddToMeal` with that meal (assert per card).
  - the snack area lists non-standard-meal groups (e.g. "點心", "下午茶") and its
    add fires `onAddSnack`; standard meals are not in the snack area.
  - the FAB is gone (`today-add-entry-fab` findsNothing).
- Shell: `onAddToMeal('lunch')` sets the logging bar to lunch and shows the
  Dictionary tab; `onAddSnack` sets the next snack name and shows the dictionary.
- Wording: the snack chip in the quantity card / manual form shows
  `dietSnackBaseName`, not `dietAddSnack`.
