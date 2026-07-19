# Tasks — Add to each meal directly from Today

## 1. Today screen: fixed cards + add affordances + snack area
- [ ] 1.1 Group `dayLog.meals` into a `Map<String, MealGroup>` by meal name;
      render three fixed cards (breakfast/lunch/dinner order, always shown) looking
      up each group (may be absent). `_MealCard` handles both states: with entries
      (emoji + earliest time + editable rows + pills, unchanged) and empty (emoji +
      name + "not logged yet"). Each card carries a `Key('add-to-meal-<meal>')` add
      control → `onAddToMeal(meal)`.
- [ ] 1.2 Snack area: collect groups whose meal ∉ {breakfast,lunch,dinner} in eaten
      order; header + `Key('add-snack')` add control → `onAddSnack`; list them as
      editable meal cards.
- [ ] 1.3 Remove the FAB (`today-add-entry-fab`) and `onAddEntry`; drop the
      whole-day `today-empty-state` (emptiness is now per card). Add
      `onAddToMeal(String)` / `onAddSnack()` nullable callbacks to `TodayScreen`.

## 2. Shell wiring
- [ ] 2.1 `DietShellScreen`: `onAddToMeal(meal)` → `setState(_currentMeal = meal;
      _index = 1)`; `onAddSnack` → `setState(_currentMeal = nextSnackName(day meal
      names, loc.dietSnackBaseName); _index = 1)`. Remove the old `onAddEntry`
      wiring. Reuse the existing logging bar / continuous logging / snackbar.

## 3. Unify snack wording
- [ ] 3.1 `quantity_card.dart` + `portion_form_fields.dart`: snack meal `ChoiceChip`
      label `loc.dietAddSnack` → `loc.dietSnackBaseName`. Behavior unchanged.

## 4. i18n
- [ ] 4.1 New ARB (en + zh-Hant + zh): per-card add label, empty-meal line (reuse
      `dietDayEmpty` or a dedicated key), snack-area title, add-snack label.
      Regenerate l10n.

## 5. Tests + verify
- [ ] 5.1 Widget tests: three standard cards always shown (incl. all-empty day) in
      order; a meal with entries shows them + time; each card's add fires
      `onAddToMeal` with the right meal; snack area lists non-standard groups + add
      fires `onAddSnack`; FAB gone. Shell: add-to-meal sets bar meal + Dictionary
      tab; add-snack sets next snack name + dictionary. Wording: snack chip shows
      `dietSnackBaseName`.
- [ ] 5.2 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
