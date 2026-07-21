# Tasks — Diet in-place edit + measure axis + manual entry

TDD throughout: write the failing test first, then the code. Verify each step
with `flutter test` on the touched files and `flutter analyze` clean.

## 1. Domain: measure axis on the DTOs (TDD)
- [ ] 1.1 `domain/food_item.dart`: replace `baseGrams` with `baseAmount`
      (`double?`, from `base_amount`) **+** `measureUnit` (`String?`, from
      `measure_unit`, `'g'`|`'ml'`). → verify: parser unit tests — `base_amount`
      + `measure_unit` parsed; both null when absent.
- [ ] 1.2 `domain/meal_entry.dart`: the **only** DTO change is `baseGrams` →
      `baseAmount` (from `base_amount`) **+** `measureUnit` (from `measure_unit`).
      To display the amount and drive the inline editor, `MealItem` also reads the
      fields the response already carries — `quantity`, `food_item_id`, `source`,
      and the flat per-unit `staple/meat/fruit/veg` — keeping the nested
      `consumed`. Do **not** parse a `measure` field or a separate `portions`
      object: the response (`mealItemToJson`) has neither (`measure` is
      request-only; a manual item's portions are the flat per-unit values at
      `quantity = 1`). → verify: parser unit tests — `base_amount` + `measure_unit`
      parsed (and null when absent); a dictionary item (food_item_id + quantity)
      and a manual item (source manual, null food_item_id, flat per-unit portions)
      round-trip from the real response shape.
- [ ] 1.3 `domain/meal_repository.dart`: `CreateMealItem` — `grams` field →
      `measure`; add a `manual` factory (`name` + `Portions`, no `foodItemId`,
      no measure/quantity). Add port methods `patchMealItem`
      (`{quantity? | measure? | portions?}`), `deleteMealItem`, `patchMealTime`
      (`{time}`), `deleteMeal`. → verify: `flutter analyze` clean; the
      `dictionary`/`manual` mutual-exclusion asserts.

## 2. Infrastructure: `HttpMealRepository` mutations (TDD)
- [ ] 2.1 `infrastructure/http_meal_repository.dart`: item body `grams` →
      `measure`; manual item body `{name, portions}` (no `food_item_id`).
      → verify: fake-client tests assert `POST /api/meals` item shapes
      (dictionary `food_item_id` + `quantity` XOR `measure`; manual `name` +
      `portions`).
- [ ] 2.2 Implement the four mutations against the endpoints, reusing `_send`
      (401 → `DietReauthenticationRequired`, transport/non-2xx →
      `DietFetchFailure`): `PATCH /api/meal-items/:id`
      (`{quantity? | measure? | portions?}`), `DELETE /api/meal-items/:id`,
      `PATCH /api/meals/:id` (`{time}` ISO), `DELETE /api/meals/:id`. Map an
      owner-scope `404` to a typed not-found failure (edit of an item the user
      doesn't own). → verify: fake-client tests assert method/path/body for each;
      `401` → reauth; `404` → not-found; `204`/`200` success.

## 3. Application: use cases (TDD)
- [ ] 3.1 `create_meal` already flows the request through; ensure it carries the
      new `CreateMealItem` (measure/manual) unchanged. Add thin use cases over
      the new port methods (`EditMealItem`, `DeleteMealItem`, `ChangeMealTime`,
      `DeleteMeal`) — each one call to the repository. → verify: use-case unit
      tests with a fake `MealRepository` (args passed through).

## 4. Measure-aware `AmountStepper` (TDD)
- [ ] 4.1 `presentation/amount_stepper.dart`: the measure segment's label follows
      the food's measure unit — 公克 for `g`, 毫升 for `ml` (a new
      `measureLabel`/unit param), replacing the hard-coded `dietGramsLabel`; the
      portion segment stays 份量 and the after-field unit label stays the food's
      own unit word (碗/杯/顆) or 份, never `g`/`ml`. `_unitLabelFor` in
      `food_search_screen.dart` adjusted to match. → verify: widget tests — a
      `g` item shows 公克, a `ml` item shows 毫升; portion mode shows the unit
      word / 份, never a bare g/ml; measure mode reports the amount as a measure.

## 5. Create-meal controller + manual tray item (TDD)
- [ ] 5.1 `presentation/create_meal_controller.dart`: the tray holds manual
      items too (name + `Portions`, source manual). `submit` maps a dictionary
      row to `CreateMealItem.dictionary(... measure XOR quantity)` and a manual
      row to `CreateMealItem.manual(name, portions)`. Gram-mode field renamed to
      measure mode. → verify: controller unit tests — manual add; submit payload
      (dictionary measure vs quantity; manual name+portions); empty rows dropped.

## 6. Manual-entry form on the food search (TDD)
- [ ] 6.1 `presentation/food_search_screen.dart`: a "找不到?手動輸入"
      affordance opens a manual-entry form (a small sheet/dialog) with a name
      `TextField` + four category portion inputs (reuse the shared portion input
      + empty-zero convention); submitting adds a manual tray item previewing the
      entered portions. Completing the tray posts it (via §5/§2). → verify:
      widget tests (`l10nTestApp`, fakes) — manual entry adds a portions-only
      tray row; completing posts a manual item (no `food_item_id`); empty-zero
      portion fields.

## 7. Today inline edit + time + delete (TDD)
- [ ] 7.1 `presentation/today_controller.dart`: add `editItem` (measure |
      quantity | portions), `deleteItem`, `changeMealTime`, `deleteMeal`, each
      calling the matching use case then reloading the day; map reauth /
      not-found / failure to typed state. → verify: controller unit tests (fake
      repo) — each mutation calls the port and refreshes; reauth/not-found
      mapping.
- [ ] 7.2 `presentation/today_screen.dart`: item rows become **editable** —
      tapping an item reveals an inline `AmountStepper` (dictionary, seeded with
      the item's `quantity` in **quantity mode** — the original entry mode is not
      recoverable, so no attempt to open in measure mode; the measure toggle
      公克/毫升 shows only when the item has `baseAmount` + `measureUnit`, and
      switching lets the user type a fresh measure) or the four portion inputs
      (manual, seeded from the flat per-unit values); each item row shows its
      consumed amount and offers a delete control. A meal card gains a 🕑
      change-time control (→ time picker → `changeMealTime`) and a delete-meal
      control (→ confirmation → `deleteMeal`). → verify: widget tests — the editor
      opens in quantity mode; a quantity edit persists as `quantity`; switching to
      measure and typing persists as `measure`; a manual edit persists as
      `portions`; consumed amount shown; delete item/meal fire; change-time fires;
      delete-meal asks to confirm first.

## 8. Shell wiring (TDD)
- [ ] 8.1 `presentation/diet_shell_screen.dart` / `main.dart`: pass the new use
      cases into `TodayController`; construct the edit/delete/time use cases from
      the one `HttpMealRepository`. → verify: `flutter analyze` clean; the shell
      widget test still drives Today; app builds.

## 9. i18n
- [ ] 9.1 ARB (en + zh-Hant + zh): 毫升 (measure unit), manual-entry title +
      "找不到?手動輸入" + form labels, edit / delete-item / delete-meal /
      change-time controls + confirmation copy, and their error strings.
      Regenerate `flutter gen-l10n`. → verify: no hard-coded strings in the new
      presentation code; generated l10n committed.

## 10. Verify gate
- [ ] 10.1 `flutter analyze` clean; `flutter test` green (new + updated tests).
- [ ] 10.2 `openspec validate --strict diet-edit-and-measure` exits 0.
