# Tasks — Dictionary bottom sheet + remove dictionary tab

## 1. Dictionary sheet (stateful, owns current meal)
- [ ] 1.1 New `_DictionarySheet` StatefulWidget owning `String _currentMeal`
      (seeded from the open call). Contains `_LoggingMealBar` (segment select /
      snack rename now update the sheet's `_currentMeal`, reusing the derivation +
      recompute-gate + `nextSnackName` logic lifted to the sheet's state) above
      `DictionaryScreen` (onSelectItem → `_openLogEntry(item, _currentMeal)`,
      onManualEntry → `_openManualEntry(_currentMeal)`). Tall + scrollable
      (DraggableScrollableSheet or high `initialChildSize`, list scrolls). Passed
      from the shell: dictionary + log-entry controllers AND `todayController` (its
      `dayLog` feeds `nextSnackName` for the snack renumber). Wrap the body in a
      `Scaffold` so its own `ScaffoldMessenger` can host the "added" snackbar above
      the sheet (D3).
- [ ] 1.2 `onDone` → `Navigator.of(sheetContext).pop()` (dismiss to Today).

## 2. Shell wiring: add opens the sheet, nav 3→2
- [ ] 2.1 `onAddToMeal(meal)` / `onAddSnack` → `showModalBottomSheet(
      isScrollControlled: true, builder: _DictionarySheet(initialMeal: meal-or-next-
      snack, …))` instead of `setState(_index=1)`. **Remove `_currentMeal` from the
      shell entirely** (it lives in the sheet now); convert BOTH `_openLogEntry` and
      `_openManualEntry` to take the meal as a parameter (from the sheet), not shell
      state, so neither reads removed state.
- [ ] 2.2 `IndexedStack` → two children (Today, Target); `NavigationBar` → two
      destinations (Today, Target); `_index` ∈ {0,1}. Remove the dictionary stack
      child and its destination.

## 3. Quantity sheet as second layer
- [ ] 3.1 `_openLogEntry(item, meal)` takes the meal from the dictionary sheet
      (not shell state); it already opens the quantity card as a bottom sheet, so
      it stacks over the dictionary sheet. On add it pops itself + onSaved (reload).
      **The "added" snackbar shows on the dictionary sheet's own ScaffoldMessenger**
      (sheet body wrapped in a Scaffold, D3) so it's visible above the sheet, not
      occluded behind it on the shell's messenger. The dictionary sheet remains for
      the next pick. Quantity card unchanged.

## 4. Home button on Today
- [ ] 4.1 The home `IconButton` (`Key('today-home-button')`, localized tooltip +
      semantic label) goes in `diet_shell_screen.dart`'s `_DayNavBar` / shell header
      (NOT `today_screen.dart`, which has no header) → `Navigator.of(context).pop()`
      on the shell (back to home). New ARB key for the tooltip (en + zh-Hant + zh);
      regenerate l10n.

## 5. Tests + verify
- [ ] 5.1 Widget tests: a meal's add opens a bottom sheet with logging bar +
      dictionary (not a tab switch); meal switch in-sheet updates current meal;
      picking a food opens the quantity sheet (2nd layer) at that meal; adding pops
      it, dictionary sheet remains, snackbar, 2nd pick same meal; Done pops to
      Today; nav shows only Today/Target; add-snack sets next snack number; Today's
      home button fires onGoHome. Adjust existing dictionary-tab / _index=1 / three-
      tab tests.
- [ ] 5.2 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
