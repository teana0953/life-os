# Tasks — Rewire the diet frontend onto the meal/meal-item API

## 1. Domain: meal model + DTO parsing (TDD)
- [ ] 1.1 `domain/meal_entry.dart` — **fresh DTOs for the new flat snake_case
      shapes; do NOT reuse the old `day_diet_log.dart` camelCase parsing.**
      `MealItem` parses `id`, `name` (nullable), and `consumed` as a `Portions`
      from the **nested** `consumed` object (`staple/meat/fruit/veg`); the item's
      flat per-unit fields + `quantity`/`base_grams` are not parsed this PR (PR③).
      `MealEntry` parses `id`, `meal`, `time` (ISO string →
      `DateTime.parse(...).toUtc()`), and `items` via `MealItem.fromJson`; no
      `day` field (unused by callers). Unit tests: nested `consumed` → `Portions`;
      ISO `time` → UTC `DateTime`; null `name`; a snack `meal` value kept verbatim.
      → verify: `flutter test` on the parser.
- [ ] 1.2 `domain/day_meals_log.dart`: `DayMealsLog` parses `day`, `meals`
      (`MealEntry.fromJson`), and `totals` as a `Portions` from the **flat**
      snake_case `totals` object's four portion keys (the nutrient keys in the same
      object are not read this PR). No separate totals type. Unit test: flat
      snake_case `totals` → `Portions`; meals parsed. → verify: parser test.
- [ ] 1.3 `domain/meal_repository.dart`: `MealRepository` port (`getDayMeals`,
      `createMeal` with a `time` param used as the POST body's meal time,
      `loggedDays`) + `CreateMealItem` request VO with a single `dictionary`
      factory (`foodItemId` + `quantity` XOR `grams`) — no `manual` factory and no
      PATCH/DELETE this PR (CLAUDE.md §2). → verify: `flutter analyze` clean.

## 2. Infrastructure: `HttpMealRepository` (TDD)
- [ ] 2.1 `infrastructure/http_meal_repository.dart` implementing the port against
      the meals API, reusing the Bearer-token + `_send` (401 → reauth, else
      failure) pattern. Inject `http.Client`. → verify: unit tests (fake client)
      assert method/path/body: `GET /api/meals?day=`, `POST /api/meals`
      (`{day,meal,time?,items}`, dictionary item → `food_item_id` + `quantity`
      XOR `grams`), `GET /api/meals/logged-days?month=`; `201`/`200` parse; `401`
      → `DietReauthenticationRequired`; non-2xx/transport → `DietFetchFailure`.

## 3. Application: use cases (TDD)
- [ ] 3.1 `application/get_day_meals.dart` (`GetDayMeals`) + `application/create_meal.dart`
      (`CreateMeal`), each thin over `MealRepository`. Rewire
      `application/get_logged_days.dart` to depend on `MealRepository`.
      → verify: use-case unit tests with a fake `MealRepository`.

## 4. Reusable amount widget (TDD)
- [ ] 4.1 `presentation/amount_stepper.dart` (`AmountStepper`): −/+ stepper +
      typable numeric field + unit label + portion/gram toggle (only when
      `allowGrams`). Empty-zero convention (`value == 0` → empty + `hintText:'0'`),
      clamp at 0. Theme colors, ARB strings. → verify: widget tests (step/clamp/
      type/empty-zero/toggle-visibility).

## 5. Create-meal controller (TDD)
- [ ] 5.1 `presentation/create_meal_controller.dart` (`CreateMealController`):
      tray state (add/remove/setAmount/toggleGrams), `submit(idToken, day)`
      building `CreateMealItem`s (grams row → `grams`, else `quantity`) via
      `CreateMeal`; status `{editing,submitting,error,needsReauth}` holding a
      **typed** error. → verify: controller unit tests (fake repo): tray mutation;
      submit payload; reauth/failure mapping.

## 6. FoodSearchScreen (TDD)
- [ ] 6.1 `presentation/food_search_screen.dart`: full-screen `Scaffold`, app-bar
      back + "Add to <meal>" title, pinned search `TextField`, full-page results
      `ListView` (reuse `DictionaryController` for search/favorites; result rows
      show portion pills + favorite toggle), and the current-meal tray (running
      total pill + rows using `AmountStepper` + live `previewPortionsForQuantity`
      pills + remove). "Done" → `controller.submit` → pop with result. Back
      discards. → verify: widget tests (fakes, `l10nTestApp`): add-to-tray;
      amount/gram edit updates preview + total; submit pops; narrow-width layout
      needs no `viewInsets` hack.

## 7. Today rewired to the meals API (TDD)
- [ ] 7.1 `presentation/today_controller.dart`: use `GetDayMeals` (+ keep
      `GetDailyTargetWithRemaining`); store `DayMealsLog` + target; map reauth/
      failure. → verify: controller unit tests.
- [ ] 7.2 `presentation/today_screen.dart` rewrite: four progress bars (`totals`
      vs `target.effective`); all meals+snacks sorted into one timeline by meal
      `time` (empty standard meals after, in fixed order); each card = emoji +
      meal name (standard code → localized label; a snack shown by its own `meal`
      value verbatim) + meal `time` + per-meal total
      pill + item rows showing `consumed` portion pills, **read-only** (no tap);
      round per-card add control; "＋ new snack" seeded via `nextSnackName`.
      → verify: widget tests: interleave order; empty-meal placement; time + total
      pill shown; items not tappable; add callbacks fire with the right meal.

## 8. Shell wiring (TDD)
- [ ] 8.1 `presentation/diet_shell_screen.dart`: keep day-nav header (incl. home
      button), Today/Target nav, calendar (rewired `GetLoggedDays`), day/target
      reload. Replace all bottom-sheet machinery with `_openFoodSearch(String
      meal)` that `push`es `FoodSearchScreen` (seed + reset `CreateMealController`)
      and reloads Today + target on a completed result. Wire `onAddToMeal`,
      `onAddToSnackGroup`, `onAddSnack`. Remove the browse-from-header affordance.
      → verify: widget test: tapping a card's add pushes the search screen for
      that meal; completing refreshes Today.
- [ ] 8.2 `main.dart`: build one `HttpMealRepository`; inject into `GetDayMeals`,
      `CreateMeal`, `GetLoggedDays`; construct `CreateMealController`; drop
      `HttpDietLogRepository` + removed use cases/controllers. → verify:
      `flutter analyze` + app builds.

## 9. Removals + test cleanup
- [ ] 9.1 Delete domain `day_diet_log.dart`/`food_entry.dart`/`diet_log_repository.dart`;
      infrastructure `http_diet_log_repository.dart`; application
      `get_day_diet_log.dart`/`log_food_from_dictionary.dart`/`log_manual_entry.dart`/
      `update_food_entry.dart`/`delete_entry.dart`; presentation
      `dictionary_screen.dart`/`quantity_card.dart`/`log_entry_*`/`manual_entry_*`/
      `edit_entry_*`/`portion_form_fields.dart`; and `shared/platform/keyboard_inset*.dart`
      + `keyboard_metrics*.dart`. Remove the `_DictionarySheet`/`_LoggingMealBar`/
      `_BrowseOnlyHintBar`/`KeyboardMetricsText`/`KeyboardInsetBuilder` code.
- [ ] 9.2 Delete/rewrite the corresponding tests (diet-entries repo, log/manual/
      edit controllers + screens, quantity card, dictionary sheet, keyboard inset,
      `DayDietLog`/`FoodEntry` fixtures). Ensure `snack_naming.dart` no longer
      imports a removed file. → verify: `flutter analyze` reports no unused imports
      / dangling references.

## 10. i18n
- [ ] 10.1 ARB (en + zh-Hant + zh): "Add to {meal}" title, search hint, "Done
      ({count})", tray total label, remove-item label, portion/gram toggle labels,
      "＋ new snack", any new error copy; remove now-unused logging-bar / browse /
      manual-entry / quantity-card keys. Regenerate `flutter gen-l10n`. → verify:
      no hard-coded strings in new presentation code; generated l10n committed.

## 11. Verify gate
- [ ] 11.1 `flutter analyze` clean; `flutter test` green (new + rewritten tests).
- [ ] 11.2 `openspec validate --strict rewire-diet-meal-api` exits 0.
