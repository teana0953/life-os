# Tasks — Diet mobile UX fixes

## 1. Today timeline ordering
- [ ] 1.1 `today_screen.dart` loaded body: build a single ordered list of
      meal groups that HAVE entries (standard + snack), sorted by
      `_earliestEatenAt` ascending, tie-broken deterministically by
      `_standardMeals` rank then name. Render each as a `_MealCard` in that
      order. Empty standard meals (no group) render AFTER, as empty
      `_MealCard`s in breakfast→lunch→dinner order, each keeping its
      `add-to-meal-<meal>` control. Snack-group cards keep `add-to-snack-<name>`
      (#27). Keep the "start a new snack" (`add-snack` → `onAddSnack`) control
      reachable (with the empty-meal section / below the logged list). Category
      progress bars unchanged at top.
- [ ] 1.2 `_mealLabel`: add a `snackMealValue` (`'snack'`) → `dietSnackBaseName`
      case so an unnamed snack group shows "點心", not the raw `snack`. If the
      old snack-section title (`dietSnackAreaTitle`) is left unused by the
      timeline layout, remove the orphan ARB key + regenerate.
- [ ] 1.3 Widget tests: mixed day (breakfast 08:00 / snack "點心2" 10:30 /
      lunch 12:30 / snack 15:00 / dinner 19:00) renders in that eaten-at order;
      empty standard meals appear after logged groups and still expose add;
      new-snack control present; unnamed `snack` group shows "點心".

## 2. Day header no overflow
- [ ] 2.1 `diet_shell_screen.dart` `_DayNavBar`: wrap the `Text(dateText)` in
      `Flexible(child: Text(…, maxLines: 1, overflow: TextOverflow.ellipsis))`
      so the chip + date + calendar icon never overflow at phone widths; the
      calendar icon stays visible; tapping still opens the calendar.
- [ ] 2.2 Widget test at a narrow surface (e.g. 320px) asserts no overflow
      (no exception) and the calendar icon + day-nav-label are present.

## 3. Logging bar snack name + no overflow
- [ ] 3.1 `_LoggingMealBar`: when snack is selected, show the current snack
      name (`currentMealLabel`, the actual "點心3"/"下午茶") with a
      chip-height rename control aligned next to it, all inside the existing
      `Wrap` run so it doesn't overflow or wrap the pencil alone on mobile.
      Keep keys `logging-meal-chip-snack`, `logging-meal-bar-rename-button`,
      `-field`, `-confirm`, `-cancel`. Rename `TextField` prefill unchanged.
- [ ] 3.2 Widget test at a narrow surface: snack selected shows the current
      snack name and the rename control together, no overflow; rename via the
      existing keys still works.

## 4. Verify
- [ ] 4.1 New/updated copy (if any) added to `app_en.arb` + `app_zh_Hant.arb`
      + `app_zh.arb` with a description, `flutter gen-l10n` regenerated.
- [ ] 4.2 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test`
      all green.

> Note: a fourth mobile issue — the add-food dictionary sheet's search results
> being covered by the on-screen keyboard — was descoped from this change. It is
> a Flutter-web-specific problem (web reports no `viewInsets` for the keyboard;
> it uses the browser visual viewport) that can't be verified without on-device
> web testing, and is tracked as a separate follow-up.
