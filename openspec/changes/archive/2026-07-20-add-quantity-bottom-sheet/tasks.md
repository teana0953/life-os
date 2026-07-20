# Tasks — Quantity card as a bottom sheet

## 1. Quantity card: drop meal selection
- [ ] 1.1 Remove from `quantity_card.dart`: the meal `Wrap`/`ChoiceChip`s
      (`meal-chip-*`), the `isSnack` snack-label `TextField` block, and the
      `_snackLabelText` controller (+ init/dispose). Card keeps: food name + basis +
      unit(bowl/gram) toggle + quantity stepper (tap-to-type) + portion preview +
      eaten-at + "add to <meal>" button. Persistence unchanged (`save` still uses
      `controller.meal`/`snackLabel`). Adjust the card's own tests (drop meal-chip
      assertions).

## 2. Open as a bottom sheet
- [ ] 2.1 `diet_shell_screen.dart._openLogEntry`: replace `Navigator.push(
      LogEntryScreen full-screen)` with `showModalBottomSheet(isScrollControlled:
      true, ...)` hosting the quantity card, keyboard-aware via
      `Padding(MediaQuery.viewInsets)` + scrollable content (mirror `_openEditEntry`
      / EditEntryScreen). Remove `LogEntryScreen`'s Scaffold/AppBar (thin sheet
      body). **Pop from the sheet's own context** (like EditEntryScreen): sheet body
      pops itself on successful save then calls `onSaved`; the shell's `_onEntrySaved`
      stays pop-free (reload + snackbar only).
- [ ] 2.2 Card primary button reads "add to <meal>": resolve the session meal's
      display name (standard → `dietMeal*`, snack → `controller.snackLabel`) and add
      a `dietAddToMealButton(meal)` ARB string (en + zh-Hant + zh). Delete the now
      orphaned `dietLogEntryTitle` key (removed AppBar title). Regenerate l10n.

## 3. Tests
- [ ] 3.1 Widget tests: tapping a dictionary item opens a bottom sheet (not a pushed
      full-screen route); the sheet has no `meal-chip-*` and no snack-label; adding
      pops the sheet, dictionary still shown, "added to <meal>" snackbar, second pick
      still the same meal; keyboard viewInsets padding wraps content; quantity/gram
      conversion + preview + eaten-at + tap-to-type still work.

## 4. Verify
- [ ] 4.1 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
