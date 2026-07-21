# Diet in-place edit + measure axis + manual entry

## Why

This is the **final PR of the diet revamp** (PR③ of 3). PR② rewired the
frontend onto the meal/meal-item API, shipped the full-screen food search + item
tray, and rebuilt Today as a **read-only** view. Two gaps remain, and the
backend has moved underneath us:

1. **DTOs no longer match the backend.** Backend #13 replaced the item's
   `base_grams` (a single gram weight) with a two-part **measure axis**: a food
   carries `base_amount` **+** `measure_unit` (`'g'` | `'ml'`), and an item's
   amount is now sent as `measure`, not `grams`. The frontend `FoodItem` /
   `MealItem` DTOs still parse `base_grams`, and `HttpMealRepository` /
   `create_meal` still send `grams`, so they are out of sync with the shipped
   API.

2. **The amount UX reads wrong, and Today can't be edited.** Users reported that
   labelling portion counts with "g"/"ml" is confusing (「份數顯 g/ml 很怪」).
   Separately, PR② deliberately left Today's items read-only: there is still no
   way to fix a logged amount, change a meal's time, delete an item or a meal, or
   log a food that isn't in the dictionary — all of which the mockup
   (`a9975f47`) calls for.

Backend #12/#13 are live and provide the mutation surface
(`PATCH`/`DELETE /api/meals/:id`, `PATCH`/`DELETE /api/meal-items/:id`) and the
manual-item POST shape this PR consumes. This change closes the revamp.

## What Changes

- **DTOs follow the measure axis.** `FoodItem` parses `base_amount` +
  `measure_unit` (`'g'`|`'ml'`, both nullable) instead of `base_grams`.
  `MealItem` parses the extra fields Today now needs to display an amount and
  drive inline editing. `CreateMealItem` sends `measure` instead of `grams`, and
  gains a `manual` factory (`name` + `portions`, no `food_item_id`).
- **Measure-aware amount control.** `AmountStepper` labels its measure segment
  by the food's `measure_unit` — 公克 for `g`, 毫升 for `ml` — and its portion
  segment stays 份量, showing the food's own unit word (碗/杯/顆) or 份, never a
  bare "g"/"ml". Measure mode sends `measure`; portion mode sends `quantity`.
- **Today is editable in place.** Tapping an item reveals an inline amount
  control (`PATCH /api/meal-items/:id` with `measure` | `quantity` | `portions`);
  each item can be deleted (`DELETE /api/meal-items/:id`); a meal card's 🕑
  control changes the meal's time (`PATCH /api/meals/:id`); a meal can be deleted
  behind a confirmation (`DELETE /api/meals/:id`, cascade). Each item row now
  also shows its consumed amount. The controller refreshes the day after any
  edit.
- **Manual food entry.** The food search offers "找不到?手動輸入" → a form
  (name + four category portions, reusing the shared portion inputs and the
  empty-zero convention) → adds a manual item to the tray → completing POSTs it
  as a manual item (portions, no `food_item_id`).
- **i18n.** New copy for 毫升, manual entry, edit/delete/change-time controls and
  their errors.

## Impact

- **Spec:** `health-diet` — 5 ADDED requirements (in-place item edit; change meal
  time; delete item/meal; manual food entry; measure-unit g/ml input) and 3
  MODIFIED (Today's item rows editable + show amount; tray amount control
  measure-aware; complete sends measure / manual).
- **Affected code:**
  - `domain/food_item.dart` — `baseGrams` → `baseAmount` + `measureUnit`.
  - `domain/meal_entry.dart` — `MealItem` gains the fields needed to display an
    amount and edit (quantity, measure, measure_unit, base_amount, food_item_id,
    source, portions).
  - `domain/meal_repository.dart` — `CreateMealItem` measure + `manual` factory;
    new `patchMealItem` / `deleteMealItem` / `patchMealTime` / `deleteMeal` port
    methods.
  - `infrastructure/http_meal_repository.dart` — measure body; the four mutation
    endpoints (typed error / 401 → reauth / owner-scope 404).
  - `application/` — `create_meal` sends measure/manual; new edit/delete/time use
    cases (thin over the port).
  - `presentation/amount_stepper.dart` — measure-unit labels.
  - `presentation/today_screen.dart` — inline edit, amount display, 🕑 time,
    delete controls.
  - `presentation/today_controller.dart` — mutation methods + refresh.
  - `presentation/food_search_screen.dart` + `create_meal_controller.dart` —
    manual-entry affordance, form, manual tray item.
  - `l10n/app_en.arb` / `app_zh_Hant.arb` (+ `app_zh.arb`) — new copy.
