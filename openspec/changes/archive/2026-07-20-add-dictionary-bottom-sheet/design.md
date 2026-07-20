# Design — Dictionary bottom sheet + remove dictionary tab

## Context

`DietShellScreen` is an `IndexedStack` of three screens (Today / Dictionary /
Target) with a `NavigationBar`. The Dictionary screen is
`Column(_LoggingMealBar(onDone: _index=0), DictionaryScreen(onSelectItem:
_openLogEntry, onManualEntry:))`. Today's per-meal add wires `onAddToMeal(meal) =>
setState(_currentMeal = meal; _index = 1)` (and `onAddSnack` similarly).
`_currentMeal` is **shell state**, read by `_LoggingMealBar`; `_openLogEntry` (PR
#24) already opens the quantity card as a bottom sheet. Home pushes DietShell via
`Navigator.push`; DietShell has no AppBar/back UI. Follow the frontend CLAUDE.md.

## Decisions

### D1 — A stateful dictionary sheet (the meal switch lives in the sheet now)

`onAddToMeal`/`onAddSnack` no longer switch tabs; they call
`showModalBottomSheet(isScrollControlled: true, builder: …)` opening a new
`_DictionarySheet` widget with the initial meal (a standard meal, or
`_nextSnackNameForDay()` for snack).

**Key move:** `_currentMeal` was shell state that the logging bar read and
`_openLogEntry` used. A `showModalBottomSheet` builder does **not** rebuild on the
shell's `setState` (it's a separate route), so the current-meal state moves **into**
`_DictionarySheet` (a `StatefulWidget` owning `String _currentMeal`, seeded from the
open call). Inside it: the `_LoggingMealBar` (its segment select / snack rename now
update the sheet's `_currentMeal`, reusing the same derivation + recompute-gate +
`nextSnackName` logic, lifted to operate on the sheet's state) above the
`DictionaryScreen`. The sheet is tall and scrollable (`DraggableScrollableSheet` or
a high `initialChildSize` with the list scrollable). Picking a food calls
`_openLogEntry(item, _currentMeal)` (see D3). The dictionary + log-entry
controllers are passed in from the shell (unchanged instances); **`todayController`
is also passed** because the snack renumber (`nextSnackName` on a non-snack→snack
switch) reads `todayController.dayLog` for the day's existing snack groups (there is
no snack controller — `nextSnackName` is a pure function). `_currentMeal` is
removed from shell state entirely — it now lives only in `_DictionarySheet`; the
open call seeds it (standard meal, or `_nextSnackNameForDay(todayController.dayLog)`
for snack).

### D2 — Two-tab navigation

The `IndexedStack` drops to two children (Today, Target); `NavigationBar` to two
destinations (Today, Target). `_index` now spans {0,1}. The dictionary screen is no
longer a stack child — it's only ever shown as the sheet.

### D3 — Quantity sheet as a second layer

Inside the dictionary sheet, `onSelectItem` runs the existing `_openLogEntry` —
which `showModalBottomSheet`s the quantity card — so it stacks as a **second sheet**
over the dictionary sheet. On add, the quantity sheet pops itself (its own context,
already the case) and fires `onSaved`. `_openLogEntry` takes the current meal from
the dictionary sheet's `_currentMeal` (passed in), not shell state. `_openManualEntry`
(reachable from the dictionary sheet) **also** takes the meal from the sheet, not
shell state — both are converted since `_currentMeal` leaves the shell (D1). The
quantity card is unchanged.

**Snackbar must not be occluded by the dictionary sheet.** The shell's
`_onEntrySaved` shows the "added" SnackBar via the shell `ScaffoldMessenger`, whose
Scaffold sits *under* the open modal dictionary sheet — so the SnackBar would paint
behind the sheet, invisible (and a naive `find` test would still pass). Fix: wrap
the dictionary sheet's body in its own `Scaffold` and route the "added"
confirmation through **that** sheet's `ScaffoldMessenger` (or a `ScaffoldMessenger`
wrapping the sheet content), so it shows above the sheet. So the save path becomes:
quantity sheet pops → reload Today → show the "added to <meal>" SnackBar on the
dictionary sheet's messenger (not the shell's). The dictionary sheet, underneath the
now-popped quantity sheet, is right there for the next pick. A widget test asserts
the SnackBar is under the dictionary sheet's Scaffold, not the shell's.

### D4 — "Done" pops the dictionary sheet

`_LoggingMealBar.onDone` changes from `setState(_index = 0)` to
`Navigator.of(sheetContext).pop()` — dismissing the dictionary sheet returns to
Today (which was always underneath). No tab index involved.

### D5 — Home button in the day-nav header

The mascot/day header actually lives in **`diet_shell_screen.dart`** (the `_DayNavBar`
in the shell wrapper), not `today_screen.dart` (whose body is a ListView with no
header). So the home `IconButton` (`Key('today-home-button')`, localized tooltip,
semantic label) goes in `_DayNavBar` / the shell header, calling `Navigator.of(
context).pop()` on the shell to return to home "your spaces" (DietShell was pushed
from home via `MaterialPageRoute`). Theme colors, no hard-coding.

### D6 — Manual entry from the sheet

The dictionary sheet's `onManualEntry` still opens the full-screen
`ManualEntryScreen` (`Navigator.push`) — reachable from the sheet; keeping it
full-screen this change (sheet-ifying it is a follow-up). Editing an entry
(`onEditEntry` from Today) keeps its own edit sheet, unrelated to this sheet.

### i18n

New ARB (en + zh-Hant + zh): the home-button tooltip/label. No hard-coded strings.

## Testing

- Widget (fake controllers/repos, `l10nTestApp`, pinned clock):
  - tapping a meal's add opens a **bottom sheet** containing the logging bar +
    dictionary (not a tab switch; `find.byType(BottomSheet)` + dictionary content).
  - the meal switch inside the sheet updates the sheet's current meal; picking a
    food opens the quantity sheet (second layer) seeded to that meal; adding pops
    the quantity sheet, the dictionary sheet remains, snackbar shown, a second pick
    is still the same meal.
  - "Done" pops the dictionary sheet back to Today.
  - bottom navigation shows only Today and Target (no Dictionary destination).
  - add-snack opens the sheet with the next snack number.
  - Today's home button fires `onGoHome` (assert the callback / that it pops).
