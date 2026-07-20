# Rewire the diet frontend onto the meal/meal-item API

## Why

The backend diet model was rewritten from per-entry `diet-entries` to a
two-level **meal (one time) + meal-item (children, Model Y)** model, exposed by
a new API surface (`/api/meals`, `/api/meal-items`). The frontend still talks to
the retired `/api/diet-entries` endpoints (`HttpDietLogRepository`,
`DayDietLog`/`MealGroup`/`FoodEntry`), so it no longer matches the backend and
must be reconnected.

At the same time the add-food UX is being reworked (UX confirmed via mockup
artifact `a9975f47`). Today the dictionary opens as a stacked bottom sheet with a
logging bar and a second quantity sheet on top; when the on-screen keyboard is up
the sheet collapses to ~260px and the search results are pushed behind the
keyboard — a dead-end the code fights with a `visualViewport` keyboard-inset hack
(`shared/platform/keyboard_inset*.dart` / `keyboard_metrics*.dart`). Moving the
whole flow to a **pushed full-screen `FoodSearchScreen`** root-causes that: a
full-screen `Scaffold` resizes for the keyboard on its own, so the pinned search
field plus a full-page results list always have room. No viewport hack needed.

This is **PR② of 3**. PR② rewires the data layer, adds the full-screen search +
per-meal item tray, and rebuilds Today as a read-only "view" of the day's meals.
**Today's meal items are read-only in this PR.** PR③ adds in-place item editing,
per-meal time changes, and item/meal deletion on the new model.

## What Changes

- **Data layer → meal/meal-item model.** New domain `MealEntry`, `MealItem`
  (name + the derived `consumed` portions the read-only Today needs; per-unit /
  quantity / baseGrams fields are added in PR③ when editing needs them), and
  `DayMealsLog` (meals + `totals`), all parsing the new flat snake_case JSON. New
  `MealRepository`
  port and `HttpMealRepository` hitting `POST /api/meals`, `GET /api/meals?day=`,
  and `GET /api/meals/logged-days?month=`, reusing the Firebase id-token +
  `401 → reauth` convention. Remove `DayDietLog`/`MealGroup`/`FoodEntry`/
  `HttpDietLogRepository` and the log/manual/edit use cases. `GetDayMeals`
  replaces `GetDayDietLog`; `GetLoggedDays` is rewired to the meals endpoint.
- **Full-screen `FoodSearchScreen`** replaces the dictionary bottom sheet, its
  logging bar, and the quantity card. Pushed for a chosen meal; a pinned search
  field over a full-page results list; tapping a result adds it to a local
  "current meal" tray; each tray item has an amount control (−, a typable number
  field, +, unit) with a **portion/gram** toggle when the item has base grams
  (grams ÷ base grams), a live portion preview, and a running per-meal total pill.
  Completing posts the tray as one meal and returns to a refreshed Today; backing
  out without completing discards it.
- **Reusable amount widget** (`AmountStepper`): typable number + −/+ stepper +
  unit/gram toggle, matching the target-setting stepper and the empty-zero
  numeric convention. Used by the tray now; reused by PR③'s in-place edit.
- **Today rebuilt as a read-only "view"** from `GET /api/meals?day=`: four
  category progress bars (day `totals` vs the target's effective goal); every
  meal and snack **interleaved into one timeline by its meal `time`** (empty
  standard meals shown after); each card showing an emoji, meal name, the meal's
  single `time`, a per-meal total pill, and its item rows (consumed portions,
  **read-only this PR**); a round add control on each card that pushes
  `FoodSearchScreen` for that meal, and a "＋ new snack" control at the bottom.
  The header's home button is kept.
- **Removals.** The dictionary sheet host, logging bar, browse-only hint bar, the
  `KeyboardMetricsText` debug readout, `KeyboardInsetBuilder`, the
  `shared/platform/keyboard_inset*.dart` + `keyboard_metrics*.dart` files, the old
  log/manual/edit screens and the quantity card, and the browse-only dictionary
  mode — plus their tests.

## Open decision (please confirm at proposal approval)

- **PATCH/DELETE deferred to PR③.** `PATCH`/`DELETE` on `/api/meals/:id` and
  `/api/meal-items/:id` exist on the backend, but this PR's `MealRepository` /
  `HttpMealRepository` expose **only** the three methods that have callers
  (`getDayMeals`, `createMeal`, `loggedDays`). The mutation methods land in PR③
  alongside the editing UI that calls them, per the repo's no-speculative-code
  rule (CLAUDE.md §2). If you'd rather land the full adapter surface now, say so
  and the tasks/spec will include them.

## Impact

- Affected spec: `health-diet` — the add-food flow, Today's presentation, the
  read-only item constraint, and logged-days source all change; several
  bottom-sheet / quantity-card / manual-entry / keyboard-inset / in-place-edit
  requirements are removed or deferred to PR③.
- Affected code (frontend only, `lib/contexts/health/`): new `meal_entry`,
  `day_meals_log`, `meal_repository` (domain); `http_meal_repository`
  (infrastructure); `get_day_meals`, `create_meal` use cases + rewired
  `get_logged_days`; `create_meal_controller`, `food_search_screen`,
  `amount_stepper` (presentation); rewritten `today_controller`, `today_screen`,
  `diet_shell_screen`; removed `day_diet_log`/`food_entry`/`diet_log_repository`/
  `http_diet_log_repository`/`get_day_diet_log`/`log_food_from_dictionary`/
  `log_manual_entry`/`update_food_entry`/`delete_entry`/`dictionary_screen`/
  `quantity_card`/`log_entry_*`/`manual_entry_*`/`edit_entry_*`/
  `portion_form_fields`; removed `shared/platform/keyboard_inset*.dart` +
  `keyboard_metrics*.dart`. ARB copy (en + zh-Hant + zh). No backend change.
