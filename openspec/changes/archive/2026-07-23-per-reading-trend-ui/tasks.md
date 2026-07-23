# Tasks

TDD throughout. `flutter analyze` + `flutter test` + `bash scripts/lint-actions.sh`.
Colors via Theme; strings via ARB (en+zh_Hant+zh, gen-l10n, commit generated).
Frontend-only.

- [x] 1. `vitals_day.dart`: add `GlucoseMealContext` enum (wire fasting/pre_meal/
      post_meal) + `mealContext` on `GlucoseReading` (fromJson/toJson `meal_context`,
      sentinel copyWith so it can set AND clear).
- [x] 2. `vitals_series.dart`: `SeriesPoint` gains `time` + `mealContext` (parsed
      from `meal_context`).
- [x] 3. `trend_card.dart`: time-axis x = day offset + fraction-of-day; glucose view
      splits by context into 4 coloured lines + per-context legend; keeps the glucose
      70–140 band + its legend (both legends can show); multi-line semantics.
- [x] 4. `vitals_screen.dart`: replace the free-text 餐前/餐後 quick-picks with a
      structured 空腹/餐前/餐後 `ChoiceChip` picker (tap selected → clear); remove the
      now-unused `_QuickPick`.
- [x] 5. i18n: add the four `glucoseContext*` keys (en+zh_Hant+zh); remove the unused
      `vitalsGlucoseBeforeMeal`/`AfterMeal`; regenerate.
- [x] 6. Tests: fromJson time/context; glucose-by-context view (lines + both legends);
      picker sets/clears context on save. Gates green.
