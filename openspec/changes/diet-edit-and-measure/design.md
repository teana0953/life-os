# Design — Diet in-place edit + measure axis + manual entry

## Context

PR② (`rewire-diet-meal-api`, archived) rewired the frontend onto the
meal/meal-item API and rebuilt Today as a read-only view; it deferred in-place
editing, meal-time changes, deletion, and manual entry to PR③, and it modelled
the item amount as a single `base_grams` gram weight. Since then backend #13
changed the amount model to a **measure axis** (`base_amount` + `measure_unit`,
`measure` on save) and #12/#13 shipped the mutation endpoints. This change is
PR③: it re-aligns the DTOs, fixes the amount-control UX, and opens Today to
editing plus adds manual entry.

## Backend surface the frontend must match (source of truth)

Food item (dictionary) now carries a measure axis:

- `base_amount` (number, nullable) — the measure of one dictionary unit.
- `measure_unit` (`'g'` | `'ml'`, nullable) — the unit of `base_amount`.

Meal-item on **save/edit** (`POST /api/meals` items, `PATCH /api/meal-items/:id`):

- dictionary: `{ food_item_id, quantity? | measure? }` (mutually exclusive;
  `measure` replaces the old `grams`).
- manual: `{ name, portions?: { staple, meat, fruit, veg } }` (or `name` +
  nutrients) — **no `food_item_id`**.

`measure` and `portions` exist **only on the request side**: the backend
converts a `measure` to a `quantity` at write time and stores a manual item's
`portions` as flat per-unit `staple/meat/fruit/veg` at `quantity = 1`. Neither
is ever stored or returned.

Meal-item in a **response** (`GET /api/meals`, POST/PATCH bodies) —
`mealItemToJson`: `id`, `food_item_id`, `name`, `source`, `unclassified`, the
flat per-unit portions `staple/meat/fruit/veg`, the flat per-unit nutrients
`carb_g…kcal`, `quantity`, **`base_amount`**, **`measure_unit`**, and a **nested
`consumed`** object. There is **no** `measure` and **no** separate `portions`
object in the response.

Mutations:

- `PATCH /api/meals/:id` body `{ time }` (ISO-8601) — changes the meal's time;
  the day is unchanged.
- `DELETE /api/meals/:id` — deletes a meal and cascades to its items.
- `PATCH /api/meal-items/:id` body `{ quantity? | measure? | portions?{staple,
  meat,fruit,veg} }` — `quantity` and `measure` mutually exclusive.
- `DELETE /api/meal-items/:id` — deletes one item.

Owner scoping: a mutation targeting an id the user doesn't own returns `404`.

## Decisions

### D1 — DTOs follow the measure axis

- `FoodItem`: drop `baseGrams`; add `baseAmount` (`double?` from `base_amount`)
  and `measureUnit` (`String?` from `measure_unit`). Kept as a raw string
  (`'g'`/`'ml'`) rather than an enum — it is only ever a display-label lookup and
  a passthrough; an enum would be speculative (CLAUDE.md §2).
- `MealItem`: PR② parsed only `id`/`name`/`consumed`, and the response shape is
  otherwise unchanged, so the **only** DTO change here is `baseGrams` →
  `baseAmount` (`double?` from `base_amount`) **+** `measureUnit` (`String?` from
  `measure_unit`). To display the consumed amount and drive the inline editor it
  also reads fields the response already carries — `quantity`, `foodItemId`,
  `source`, and the flat per-unit `staple/meat/fruit/veg` — but it does **not**
  parse a `measure` field or a separate `portions` object, because the response
  has neither (`measure` is request-only and is converted to `quantity` on write;
  a manual item's portions live in the flat per-unit fields at `quantity = 1`).
  `consumed` stays the source for the portion pills. A manual item is recognised
  by `source == 'manual'` / a null `foodItemId` and is edited by sending
  `portions` (the four flat per-unit values); a dictionary item is edited by
  sending `quantity` or `measure`.
- `CreateMealItem`: the `grams` field becomes `measure`; add a `manual` factory
  (`CreateMealItem.manual(name, portions)`) alongside the existing `dictionary`
  factory. The dictionary factory keeps the quantity-XOR-measure assert.

### D2 — Measure-aware `AmountStepper` (fixes the g/ml UX report)

The amount control has two axes the user toggles between:

- **portion mode** ("份量"): the after-field unit label is the food's own unit
  word parsed from its name (`飯/1碗` → 碗; 蛋/1個 → 個; a drink → 杯), or a
  generic 份 when the name has no unit segment. It is **never** "g"/"ml".
- **measure mode**: labelled by the food's `measure_unit` — **公克** for `g`,
  **毫升** for `ml`. The measure segment used to hard-code `dietGramsLabel`; it
  now takes a `measureLabel` (or the unit) so ml items read 毫升.

The toggle is offered only when the food has a base measure (`baseAmount != null`
&& `measureUnit != null`); otherwise the control is quantity-only. Measure mode
sends `measure`; portion mode sends `quantity`. `_unitLabelFor` in
`food_search_screen.dart` is adjusted so the portion-mode unit label never falls
back to a raw g/ml. Client preview in measure mode converts via
`quantityFromGrams`-style division by `baseAmount` (the existing
`quantityFromGrams` is generalised to `base_amount`; the divisor semantics are
identical — grams was just a measure).

### D3 — Today items editable in place (UI form)

Chosen form: **inline expansion within the meal card**, not a pushed screen or a
separate sheet. Tapping an item row toggles an inline editor beneath it:

- dictionary item → an `AmountStepper` seeded with the item's current `quantity`
  in **quantity (份) mode**. The backend does not retain how the item was
  originally entered (a `measure` was converted to `quantity` on write and no
  measure field survives on the stored item), so the editor cannot recover the
  original entry mode — it always opens in quantity mode. The measure toggle
  (公克/毫升) is offered only when the item has `baseAmount` + `measureUnit`, and
  switching to measure mode lets the user type a **fresh** measure amount.
- manual item → the four portion inputs seeded with the item's flat per-unit
  `staple/meat/fruit/veg`.

This keeps editing "就地" (in place) — the user never leaves Today, matching the
mockup and avoiding re-introducing the bottom-sheet/keyboard machinery PR②
removed. Each item row also renders a delete control and now shows its consumed
amount (e.g. "1 碗" / "80 公克") next to the portion pills.

Persisting: on commit the row calls `TodayController.editItem(item, ...)` with
exactly one of `measure` / `quantity` / `portions`, which maps to
`PATCH /api/meal-items/:id`. The controller then reloads the day so the item's
recomputed `consumed` and the meal/day totals reflect the change (the backend is
authoritative for portions; the client does not guess).

### D4 — Change a meal's time

A 🕑 control on the meal card header opens a time picker seeded with the meal's
current local time. On pick, `TodayController.changeMealTime(meal, time)` sends
`PATCH /api/meals/:id` with the new time as ISO-8601 (UTC), then reloads. Because
Today interleaves meals by `time`, the reload re-sorts the meal into its new slot.
The day is not changed (a time-only edit); this mirrors the backend's `{time}`
body which keeps the meal's day.

### D5 — Delete an item or a meal

- Delete item: a per-row control → `TodayController.deleteItem(item)` →
  `DELETE /api/meal-items/:id` → reload. No confirmation (a single item, easily
  re-added).
- Delete meal: a meal-card control → **confirmation dialog** → on confirm
  `TodayController.deleteMeal(meal)` → `DELETE /api/meals/:id` (cascade) → reload.
  Confirmation because deleting a meal discards several items at once.

### D6 — Manual food entry

The food search gains a "找不到?手動輸入" affordance (shown near the search
field / empty results). It opens a manual-entry form (a small sheet or dialog)
with:

- a name `TextField`, and
- four category portion inputs (staple/meat/fruit/veg), reusing the shared
  portion input and the **empty-zero** convention (0 → empty field + `hintText:
  '0'`).

Submitting adds a **manual tray item** to the current-meal tray: it carries the
name and the entered `Portions` and is `source: manual` with no dictionary
reference. Its tray preview is exactly the portions entered (a manual item has no
per-unit × quantity scaling — it is not a dictionary food). Completing the tray
POSTs each manual item via `CreateMealItem.manual(name, portions)` (no
`food_item_id`), alongside any dictionary items.

The tray (`CreateMealController`) is extended to hold manual items as well as
dictionary `TrayItem`s; `submit` dispatches per row type. This is the minimum to
support a mixed tray — no separate manual-only flow.

### D7 — `HttpMealRepository` mutation methods

Four new methods on the port + adapter, each reusing the existing `_send`
wrapper (`401` → `DietReauthenticationRequired`; transport error / non-2xx →
`DietFetchFailure`):

| method | endpoint | body |
| --- | --- | --- |
| `patchMealItem` | `PATCH /api/meal-items/:id` | `{quantity?}` \| `{measure?}` \| `{portions?}` |
| `deleteMealItem` | `DELETE /api/meal-items/:id` | — |
| `patchMealTime` | `PATCH /api/meals/:id` | `{time}` (ISO) |
| `deleteMeal` | `DELETE /api/meals/:id` | — |

An owner-scope `404` is mapped to a typed not-found failure (distinct from a
generic fetch failure), so the screen can surface "this entry no longer exists"
rather than crash. Success is `200`/`204` (no body required).

### D8 — Controller refresh

`TodayController` gains `editItem` / `deleteItem` / `changeMealTime` /
`deleteMeal`, each: call the use case, then `await load(idToken, day)` to refresh
from the backend (single source of truth). Reauth / not-found / failure map to
the controller's typed state the screen already renders. No optimistic local
mutation — the reload keeps the client honest and is cheap (one day's meals).

## Testing

- **DTO (domain):** `FoodItem` parses `base_amount` + `measure_unit` (and null
  when absent); `MealItem` parses a dictionary item (food_item_id +
  quantity/measure) and a manual item (source manual + portions, no
  food_item_id).
- **Infrastructure (fake `http.Client`):** assert method / path / body for
  `POST` items (dictionary `food_item_id` + `quantity` XOR `measure`; manual
  `name` + `portions`), and for each mutation
  (`PATCH`/`DELETE /api/meal-items/:id`, `PATCH`/`DELETE /api/meals/:id`); `401`
  → reauth; owner-scope `404` → not-found.
- **`AmountStepper` (widget):** a `g` food's measure segment reads 公克, a `ml`
  food's reads 毫升; portion mode shows the food's unit word / 份, never a bare
  g/ml; measure mode reports the amount as a measure.
- **`CreateMealController` (unit):** manual add; submit payload (dictionary
  measure vs quantity; manual name+portions); empty rows dropped.
- **`TodayController` (unit, fake repo):** `editItem` sends the right PATCH
  payload (measure vs quantity vs portions) and reloads; `deleteItem` /
  `deleteMeal` DELETE and reload; `changeMealTime` PATCHes `{time}` and reloads;
  reauth / not-found mapping.
- **`TodayScreen` (widget):** tapping an item reveals the inline editor and a
  change persists with the right payload; the consumed amount is shown; delete
  item / delete meal fire (delete-meal asks to confirm first); 🕑 opens a time
  picker and persists.
- **`FoodSearchScreen` (widget):** "找不到?手動輸入" opens the form; a manual
  submit adds a portions-only tray item; completing posts a manual item without a
  `food_item_id`; portion fields follow empty-zero.
