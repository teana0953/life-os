# Design — Diet UX follow-ups

## Context

Post-#25: adding food is a dictionary bottom sheet (`_DictionarySheet`, owns
`_currentMeal`, hosts `_LoggingMealBar` + `DictionaryScreen`) opened by
`_openDictionarySheet(String initialMeal)`; picking a food opens the quantity
sheet as a second layer (`_openLogEntry(item, meal)`), its snackbar routed through
the sheet's own `GlobalKey<ScaffoldMessengerState>`. `_openManualEntry` already
takes the meal from the sheet but still `Navigator.push`es a full-screen
`ManualEntryScreen`. Today's snack area (`today_screen.dart`) shows snack groups
with a top-level `onAddSnack` (new snack) but no per-group add. `_dietSheetCornerRadius`
(shared, #26) and the diet-sheet style are established. Follow the frontend
CLAUDE.md.

## Decisions

### D1 — Manual entry as a bottom sheet (second layer)

`_openManualEntry(meal)` switches from `Navigator.push(MaterialPageRoute(
ManualEntryScreen))` to `showModalBottomSheet(isScrollControlled: true,
showDragHandle: true, clipBehavior: Clip.antiAlias, shape: rounded top
_dietSheetCornerRadius, builder: …)` — the shared diet-sheet style, opened from the
dictionary sheet (its "can't find it? manual entry" affordance), so it stacks as a
second layer over the dictionary sheet like the quantity sheet does.
`ManualEntryScreen` drops its full-screen `Scaffold`/`AppBar` for a thin sheet body
(`SafeArea → Padding(viewInsets) → SingleChildScrollView → the form`), mirroring
`LogEntryScreen`/`EditEntryScreen`. On save it pops itself and calls `onSaved`; the
"added" snackbar is shown on the dictionary sheet's messenger (the shell passes the
same `_onEntrySaved`/messenger path used for `_openLogEntry`). `ManualEntryController`
save logic is unchanged.

### D2 — Add to an existing snack group

Today's snack-group card gains an "add to this snack" control
(`Key('add-to-snack-<name>')`) → a new `onAddToSnackGroup(String snackName)`
callback. The shell wires it to `_openDictionarySheet(snackName)` — the dictionary
sheet seeded with that exact snack name as `_currentMeal`, so foods logged there
join **that** snack group (no renumber, no new group). This coexists with the
snack area's existing `onAddSnack` (which seeds `nextSnackName`, a new group).
`today_screen.dart`'s snack-group rendering adds the control (mirroring the
standard meal card's add-to-meal).

### D3 — Browse-only dictionary from Today's header

Today's header (`_DayNavBar` in the shell, beside the home button) gains a
"food dictionary" `IconButton` (`Key('open-dictionary-button')`, localized
tooltip) → a new `_openDictionaryBrowse()` that opens the dictionary sheet in a
**browse-only** variant:

- `_openDictionarySheet` / `_DictionarySheet` gain a `browseOnly` flag (default
  false). When true: **no `_LoggingMealBar`** (no meal/session). There is no
  logging session, so browse mode has **no `_currentMeal`** — `initialMeal` is
  irrelevant; open it via a dedicated `_openDictionaryBrowse()` that doesn't seed a
  meal. The hosted `DictionaryScreen` gets `browseOnly: true` **and
  `onManualEntry: null`** — critically, the "can't find it? manual entry" affordance
  must be suppressed too (it's gated by `onManualEntry != null`, not by browseOnly),
  else browse mode would still expose a logging path, violating "browse without
  logging".
- `DictionaryScreen` gains `browseOnly` (default false): when true, a row tap does
  **not** call `onSelectItem` (no logging) — the row still shows its portion pills
  and the favorite ♥ toggle still works (row `onTap` and the trailing favorite
  `IconButton` are already separate, so gating only the row tap is safe). Tapping a
  row does nothing beyond what's already visible (there is no food-detail screen —
  browse mode is search + list + favorites, not a detail view). When false (the
  add-food session), current behavior is unchanged.
- Because a browse-mode row looks identical to a logging-mode row but its tap is
  inert, the sheet shows a slim hint banner (`Key('browse-only-hint')`,
  localized `dietBrowseOnlyHint`) in the slot the logging bar occupies in logging
  mode — "browsing only, tap ♥ to favorite, log from a meal's ＋" — so the dead
  tap doesn't read as broken (uiux follow-up).
- Same shared sheet style + `FractionallySizedBox(0.9)` height cap (content is the
  full-bleed `DictionaryScreen`, like the logging dictionary sheet).

## Testing

- Widget (fake controllers/repos, `l10nTestApp`, pinned clock):
  - manual entry opens as a **bottom sheet** (not a pushed route) from the
    dictionary sheet, with drag handle + rounded shape; saving pops it + shows the
    snackbar on the dictionary sheet.
  - a snack group's "add to this snack" opens the dictionary sheet seeded to that
    snack name (assert the logging bar shows that name, and it does NOT increment
    to the next number); the top-level "add snack" still seeds the next number.
  - the header's food-dictionary button opens a browse-only sheet: no logging bar,
    tapping a row does not log (no quantity sheet opens) but the favorite toggle
    still works.
