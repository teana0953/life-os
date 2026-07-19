# Tasks — Continuous diet logging + snack auto-numbering

## 1. Snack-numbering helper (TDD)
- [ ] 1.1 Pure `nextSnackName(List<String> mealNames, String snackWord)` returning
      the next snack-series name (base word → "…2" → "…3", via max+1). Unit tests:
      no snacks → base; bare snack → "…2"; bare+"…2" → "…3"; only "…2" → "…3"
      (max+1, no collision); renamed "下午茶" ignored; standard meals ignored.

## 2. Controller start() takes the current meal
- [ ] 2.1 `LogEntryController.start` + `ManualEntryController.start` accept a
      `meal` (and `snackLabel`) param, seeding the card from it instead of
      hard-resetting to breakfast. Keep a sensible default so existing callers/
      tests still compile. Unit tests: start(meal:'lunch') → meal == lunch;
      start(meal: snackMealValue, snackLabel:'點心2') → isSnack + label seeded.

## 3. Logging meal bar + shell session state
- [ ] 3.1 `_LoggingMealBar` widget: meal segmented control (breakfast/lunch/
      dinner/snack) bound to a current meal + a "Done" button + a snack rename
      affordance. Theme colors, ARB strings.
- [ ] 3.2 `DietShellScreen`: add `String _currentMeal`; wrap the Dictionary tab as
      `Column(_LoggingMealBar, Expanded(DictionaryScreen))`. Segment change updates
      `_currentMeal`; snack name is recomputed via `nextSnackName(dayLog meal
      names, snackWord)` **only on a real non-snack→snack transition** (ignore
      re-taps on the already-selected snack, so a batch isn't split); rename sets
      `_currentMeal` to the typed name; "Done" → `setState(_index=0)`.

## 4. Seed picks + save feedback
- [ ] 4.1 `_openLogEntry`/`_openManualEntry` pass the current meal to `start` via
      the D5 seam (standard → `meal:'lunch'`; snack → `meal: snackMealValue,
      snackLabel: <snack name>`). onSaved: reload Today + show a localized
      "Added to <meal>" SnackBar (ScaffoldMessenger) + DO NOT change `_currentMeal`.
      Manual entry kept consistent (defaults to current meal, same snack seam).

## 5. i18n
- [ ] 5.1 ARB (en + zh-Hant + zh): "Logging to {meal}", "Done", "Added to {meal}",
      base snack word, rename label. Regenerate l10n.

## 6. Widget tests + verify
- [ ] 6.1 Widget tests (fake controllers/repos, l10nTestApp, pinned clock):
      segment change seeds meal; pick defaults to current meal; save shows snackbar
      + keeps meal so a 2nd pick is still that meal; Done → Today; snack shows
      numbered default; rename updates session name.
- [ ] 6.2 `bash scripts/lint-actions.sh`, `flutter analyze`, `flutter test` green.
