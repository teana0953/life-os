# Design — Rewire the diet frontend onto the meal/meal-item API

## Context

The frontend diet context (`lib/contexts/health/`) is built on the retired
per-entry model: `FoodEntry`, `DayDietLog`/`MealGroup`, `HttpDietLogRepository`
(`/api/diet-entries`), and the log/manual/edit use cases. The Today section
groups a day's entries by their `meal` string and renders them in a bottom-sheet
add-food flow (`_DictionarySheet` + `_LoggingMealBar` + `QuantityCard`), which
on-device collapses to ~260px behind the keyboard and is propped up by a
`visualViewport` inset hack.

The backend now serves the **meal (one time) + meal-item (Model Y)** model. This
change reconnects the frontend to it, replaces the add-food flow with a pushed
full-screen search + per-meal item tray, and rebuilds Today as a read-only view.
Item editing, per-meal time changes, and deletion are **PR③** — items are
**read-only** here. Follow the frontend CLAUDE.md (Clean Arch/DDD layering,
`ChangeNotifier` holding a typed error, Chiikawa theme, `gen_l10n`, `TextField`,
widget tests injecting fakes, the numeric empty-zero convention).

## Backend JSON the frontend must match (source of truth)

From `life-os-backend/src/adapters/http/routes/meals.ts`:

- **`POST /api/meals`** — body `{ day, meal, time?, items: [...] }`. Each item is
  either a dictionary item `{ food_item_id, quantity? | grams? }` (quantity and
  grams mutually exclusive) or a manual item `{ name?, portions?{staple,meat,
  fruit,veg} | nutrients?{carb_g,…,kcal} }`. Upserts on `(user, day, meal)`:
  creates the meal with `time` (defaulted to now if omitted) when the slot is
  empty, else appends the items to the existing meal (time unchanged). Returns
  `201` with the created/updated meal.
- **`GET /api/meals?day=`** — `{ day, meals: [ { id, meal, time (ISO), items:[…] } ],
  totals }`. Note the day-view meal objects **omit `day`** (it's on the envelope),
  and **`totals` is a single flat object** merging nutrients + portions:
  `{ carb_g, protein_g, fat_g, sugar_g, fiber_g, kcal, staple, meat, fruit, veg }`.
- **`GET /api/meals/logged-days?month=`** — `{ days: ["YYYY-MM-DD", …] }`.
- Each **item** JSON: `{ id, food_item_id, name, photo_ref, source, unclassified,
  carb_g…kcal, staple, meat, fruit, veg, quantity, base_grams,
  consumed:{carb_g…kcal, staple, meat, fruit, veg} }` — the flat fields are
  **per-unit**; `consumed` is per-unit × quantity, derived by the backend.
- A meal returned by **`POST`** (`mealToJson`) additionally carries `day` and
  serializes each item's `consumed` via the same shape.

`GET /api/daily-target?day=` is **unchanged** and its handler already recomputes
`logged`/`remaining` server-side from the new meal items — so `DailyTarget`,
`DailyTargetWithRemaining`, `HttpDailyTargetRepository`, and the Target tab need
no change (D7).

## Decisions

### D1 — New domain: `MealEntry`, `MealItem`, `DayMealsLog`

These are **fresh DTOs** that parse the **new meals API shapes**. Do NOT reuse the
old `day_diet_log.dart` parsing: `DayDietLog`/`MealGroup`/`DayNutrientTotals`
read **camelCase** totals (`carbG`, `proteinG`, …) and a different item shape, so
reusing any of it here would silently mis-parse the new payload. The new payload's
totals and item per-unit fields are **flat snake_case**, and each item's
`consumed` is a **nested** object. All the new DTOs live in the new files below.

`domain/meal_entry.dart`:

- **`MealItem`** — the fields Today actually renders, parsed from the item JSON:
  - `id` ← `json['id']` (String)
  - `name` ← `json['name']` (String?, nullable — dictionary items may be unnamed)
  - `consumed` ← a `Portions` built from the **nested** `consumed` object's
    snake-word keys: `Portions(staple: json['consumed']['staple'], meat:
    json['consumed']['meat'], fruit: json['consumed']['fruit'], veg:
    json['consumed']['veg'])` (each `(… as num).toDouble()`). Reuses the existing
    `domain/portions.dart` `Portions`. Today shows consumed **portions** only
    (item pills + per-meal total pill) and does not render per-item nutrients this
    PR, so `consumed`'s nutrient keys and the item's own flat per-unit fields
    (`staple/meat/fruit/veg`, `carb_g…kcal`, `quantity`, `base_grams`,
    `food_item_id`, `source`, `unclassified`, `photo_ref`) are **not parsed** here
    (YAGNI — PR③'s in-place edit adds the per-unit + quantity + baseGrams fields it
    needs).
- **`MealEntry`** — parsed from a meal object:
  - `id` ← `json['id']` (String)
  - `meal` ← `json['meal']` (String — a standard-meal code `breakfast`/`lunch`/
    `dinner`, or a snack's own display name)
  - `time` ← `DateTime.parse(json['time'] as String).toUtc()` (the backend sends
    ISO-8601 UTC)
  - `items` ← `json['items']` mapped through `MealItem.fromJson`
  - The **day-view** meal objects (`GET /api/meals`) omit a per-meal `day`; the
    `POST` response meal carries one. Since the create-meal caller only needs
    success (it reloads Today via `GetDayMeals`), `MealEntry` does not model `day`
    at all — it is unused by any caller this PR.

`domain/day_meals_log.dart`:

- **`DayMealsLog`** — parsed from the `GET /api/meals` envelope:
  - `day` ← `json['day']` (String)
  - `meals` ← `json['meals']` mapped through `MealEntry.fromJson`
  - `totals` ← a **`Portions`** built directly from the **flat** `totals` object's
    snake-word keys `Portions(staple: json['totals']['staple'], meat: …['meat'],
    fruit: …['fruit'], veg: …['veg'])`. The flat `totals` object also carries the
    day's nutrient keys (`carb_g/protein_g/fat_g/sugar_g/fiber_g/kcal`) in the
    **same** object, but Today renders only portion progress, so only the four
    portion keys are read (no separate nutrient-totals type this PR).

So there is **no** `DietNutrientTotals`/`MealItemConsumed`/`DayTotals` type — the
DTOs are `MealItem`, `MealEntry`, `DayMealsLog`, and they reuse `Portions` for
both an item's `consumed` and the day's `totals`.

Times: parsed as UTC (above) and converted to local for `HH:mm` display via an
injectable `toLocal` (mirrors `today_screen`'s existing `toLocalTime` seam so
timezone is testable).

### D2 — `MealRepository` port + `HttpMealRepository`

`domain/meal_repository.dart` (this PR's surface only — see the proposal's open
decision; PATCH/DELETE are PR③):

```
abstract class MealRepository {
  Future<DayMealsLog> getDayMeals(String idToken, String day);
  Future<MealEntry> createMeal(String idToken, {
    required String day,
    required String meal,
    DateTime? time,
    required List<CreateMealItem> items,
  });
  Future<List<String>> loggedDays(String idToken, String month);
}
```

`CreateMealItem` is a small request value object (domain) with a single variant
this PR: `CreateMealItem.dictionary(foodItemId, {double? quantity, double?
grams})`. The tray adds dictionary items only, so no manual variant is defined
(CLAUDE.md §2 — no speculative code; the meals API's manual-item payload is added
back with the manual-entry UI in a later PR). `createMeal`'s `time` **is** used —
it is the meal's `time` in the `POST /api/meals` body (defaulted to now when a new
meal is created); it is not speculative.

`infrastructure/http_meal_repository.dart` implements the port against the JSON in
"Backend JSON" above, reusing the existing pattern from
`HttpDailyTargetRepository`/`HttpDietLogRepository`: `Authorization: Bearer
<idToken>`, a `_send` wrapper mapping `401 → DietReauthenticationRequired` and any
transport error / non-2xx → `DietFetchFailure` (reuse `domain/diet_exceptions.dart`).
`createMeal` serializes each `CreateMealItem` to `{ food_item_id, quantity }` or
`{ food_item_id, grams }` (never both) and expects `201`.

### D3 — `GetDayMeals` / `CreateMeal` use cases; `GetLoggedDays` rewired

- `application/get_day_meals.dart` — `GetDayMeals(MealRepository).call(idToken,
  day) → DayMealsLog`. Replaces `GetDayDietLog`.
- `application/create_meal.dart` — `CreateMeal(MealRepository).call(idToken,
  {day, meal, time?, items}) → MealEntry`.
- `application/get_logged_days.dart` — keep the use case; swap its dependency from
  `DietLogRepository` to `MealRepository` (calls `loggedDays`, now the
  `/api/meals/logged-days` endpoint). Its callers (`DietShellScreen`'s calendar)
  are unchanged.

`main.dart` wiring: construct one `HttpMealRepository`, inject it into
`GetDayMeals`, `CreateMeal`, and `GetLoggedDays`; drop the `HttpDietLogRepository`
and the removed use cases.

### D4 — `FoodSearchScreen` (full-screen) + `CreateMealController`

**Why full-screen (root-causes the keyboard dead-end).** A pushed
`MaterialPageRoute` gives a full-screen `Scaffold` that resizes itself for the
on-screen keyboard. The search field is pinned at the top; the results
`ListView` fills the rest and simply shrinks when the keyboard opens, so lower
results scroll up into view above it. No `visualViewport` inset math, no
`KeyboardInsetBuilder` — the class of bug the old `~260px` sheet fought is gone
structurally (D9 removes the hack).

**Structure.** `presentation/food_search_screen.dart`, pushed by the shell for a
target meal:

```
Scaffold(
  appBar: back + "Add to <meal>" title,
  body: Column(
    pinned search TextField,
    Expanded(results ListView — reuses DictionaryController for search/favorites),
    the current-meal tray (bottom): total pill + tray item rows,
  ),
  bottomBar/CTA: "Done (<n>)" → submit,
)
```

- **Search** reuses the existing `DictionaryController` (search results +
  favorites); each result row shows the food name, its portion pills, and a
  favorite toggle (as today). Tapping a result **adds it to the tray** (local
  state) — it does not immediately hit the backend.
- **Tray** = the "current meal": a list of `_TrayItem { FoodItem item, double
  amount, bool grams }`. Each row shows the food name, an `AmountStepper` (D5),
  the item's live portion preview pills (`previewPortionsForQuantity`, reused from
  `domain/portion_preview.dart`, with the grams→quantity conversion), and a
  remove control. The tray header shows a **running total pill** = sum of every
  tray item's previewed portions.
- **Meal identity comes from the entry point**, not an in-screen selector (the old
  logging bar is gone): the shell passes `meal` (a standard meal code, an existing
  snack group's name, or the next snack name for "＋ new snack"). There is no meal
  switch or snack rename inside the screen this PR.
- **`CreateMealController`** (`ChangeNotifier`, `presentation/create_meal_controller.dart`)
  owns the tray and submission: `add(FoodItem)`, `remove(item)`,
  `setAmount(item, amount)`, `toggleGrams(item, grams)`, and
  `submit(idToken, day)`. `submit` builds `CreateMealItem.dictionary(item.id,
  quantity | grams)` per row (grams when that row is in grams mode and the item has
  base grams), calls `CreateMeal`, and exposes a status
  `{ editing, submitting, error, needsReauth }` with a **typed** error (no
  localized string in the controller — the screen maps it in `build`). On success
  the screen pops with a result so the shell refreshes Today.
- **Discard on back.** Backing out (system back / app-bar back) without completing
  simply pops; the tray is controller-local and is reset when the shell starts a
  new search session, so nothing is saved. An optional "discard?" confirm is a
  nicety, not required by the spec.

### D5 — Reusable `AmountStepper` widget

`presentation/amount_stepper.dart` — the amount control reused by the tray now and
by PR③'s in-place item edit. Presentation-only; state lives in the caller
(`CreateMealController`).

```
AmountStepper({
  required double value,          // current amount (unit qty, or grams in grams mode)
  required ValueChanged<double> onChanged,
  required String unitLabel,      // e.g. the item's unit ("碗") or the portions word
  double step = 1,                // −/+ increment
  bool allowGrams = false,        // true when the item has base grams
  bool grams = false,             // current mode
  ValueChanged<bool>? onModeChanged, // portion/gram toggle (shown only if allowGrams)
})
```

- Layout: `−` `IconButton`, a typable numeric `TextField`, `+` `IconButton`, the
  unit label; plus a portion/gram segmented toggle when `allowGrams`. Matches the
  target-setting stepper's look (`PortionStepper`) and, critically, the **numeric
  empty-zero convention** (CLAUDE.md): the field shows `''` with `hintText: '0'`
  when `value == 0`, so the user types straight away. `−` clamps at 0.
- The widget reports the raw entered amount via `onChanged`; the caller
  (`CreateMealController`) decides whether it's a `quantity` or `grams` from the
  current mode and does the grams→quantity conversion for the **preview** only
  (the POST sends grams as-is; the backend divides by base grams).

### D6 — Today rebuilt as a read-only "view"

`today_controller.dart`: swap `GetDayDietLog` for `GetDayMeals`; keep
`GetDailyTargetWithRemaining`. `load` now stores a `DayMealsLog` + the target;
status enum unchanged (`loading/loaded/error/needsReauth`, mapped from
`DietReauthenticationRequired`/`DietFetchFailure`).

`today_screen.dart` (rewritten):

- **Four progress bars** (`CategoryProgressBar`, reused): `logged =
  dayMealsLog.totals.portions.<cat>`, `effective = target.effective.<cat>` — i.e.
  the day's meal totals against the target's effective goal (D7).
- **Timeline.** Sort **all** meals (standard + snack alike) by their single meal
  `time` ascending — the meal now carries one `time`, so this is a direct sort (no
  per-item `min` as before). A snack whose time falls between two meals renders
  between them. Ties break deterministically (breakfast < lunch < dinner < snack,
  then by name) so tests can assert an exact order.
- **Empty standard meals.** The backend only returns meals that exist. The three
  standard meals with no meal that day have no `time` to sort by, so they render
  **after** the timeline as empty cards in breakfast → lunch → dinner order, each
  still offering an add control (pushes `FoodSearchScreen` seeded to that meal).
- **Meal card** (`_MealCard`): emoji + meal name + the meal's `time` (`HH:mm`,
  local) + a **per-meal total pill** (sum of the meal's item `consumed` portions)
  + item rows. The meal name maps a **standard-meal code** (`breakfast`/`lunch`/
  `dinner`) to its emoji + localized label; **any other `meal` value is a snack
  whose value already IS its display name** (e.g. "點心", "點心2", "下午茶"), shown
  verbatim with the snack emoji. The new meal model has no `snack`/`snackLabel`
  sentinel, so there is no "unnamed snack → localized word" fallback — a snack
  seeded via `nextSnackName` already carries a real localized name. Each **item
  row** shows the item name and its `consumed` portion pills — **read-only** (no
  `onTap`, no edit sheet) this PR. A round add control (top-right of the card)
  pushes `FoodSearchScreen` for that meal.
- **"＋ new snack"** at the bottom pushes `FoodSearchScreen` seeded to
  `nextSnackName(dayLog meal names, snackWord)` (reuse `snack_naming.dart`).

### D7 — Daily target / progress source

The Target tab keeps reading `GET /api/daily-target?day=` unchanged; that handler
already recomputes `logged`/`remaining` from the new meal items, so no frontend
change is needed there. Today's progress bars read the **consumed** side from
`DayMealsLog.totals.portions` (the meals endpoint Today already loads) and the
**goal** side from `target.effective` — one fewer cross-endpoint dependency and a
faithful match to the mock's "totals vs target" bars. `target.logged`/`remaining`
remain available and identical (same server-side sum) but are used by the Target
tab, not Today.

### D8 — Shell wiring

`diet_shell_screen.dart` (rewritten): keep the day-nav header (date, prev/next,
calendar, **home button retained**), the Today/Target bottom nav, the calendar
dialog (now fed by the rewired `GetLoggedDays`), and the day/target reload on day
change. Replace `_openDictionarySheet`/`_openDictionaryBrowse`/`_openEditEntry`
and the whole `_DictionarySheet`/`_LoggingMealBar`/`_BrowseOnlyHintBar` machinery
with a single `_openFoodSearch(String meal)` that `push`es `FoodSearchScreen`
(seeding `CreateMealController` with `meal`, resetting its tray) and, on a
completed result, reloads Today + the target for the current day. The Today
callbacks map to it: `onAddToMeal(meal)`, `onAddToSnackGroup(name)`,
`onAddSnack()` (→ next snack name). The browse-from-header affordance is removed
(D9).

### D9 — Removals

- Domain: `day_diet_log.dart`, `food_entry.dart`, `diet_log_repository.dart`.
- Infrastructure: `http_diet_log_repository.dart`.
- Application: `get_day_diet_log.dart`, `log_food_from_dictionary.dart`,
  `log_manual_entry.dart`, `update_food_entry.dart`, `delete_entry.dart`.
- Presentation: `dictionary_screen.dart`, `quantity_card.dart`,
  `log_entry_screen.dart`, `log_entry_controller.dart`, `manual_entry_screen.dart`,
  `manual_entry_controller.dart`, `edit_entry_screen.dart`,
  `edit_entry_controller.dart`, `portion_form_fields.dart`; and inside
  `diet_shell_screen.dart` the `_DictionarySheet`, `_LoggingMealBar`,
  `_BrowseOnlyHintBar`, `KeyboardMetricsText` debug readout, and
  `KeyboardInsetBuilder` usage.
- Shared platform: `shared/platform/keyboard_inset.dart`, `keyboard_inset_io.dart`,
  `keyboard_inset_web.dart`, `keyboard_inset_calc.dart`, `keyboard_metrics.dart`,
  `keyboard_metrics_io.dart`, `keyboard_metrics_web.dart`.
- The `snackMealValue` const (in the removed `log_entry_controller.dart`) is not
  reintroduced: snacks are seeded with the localized snack **name** via
  `nextSnackName`, never a bare `'snack'` code, so nothing needs it. `snack_naming.dart`
  (`nextSnackName`) is kept and must not import from a removed file.
- Deferred to **PR③** (removed here, not replaced): in-place item edit / delete
  (old "Edit or delete a past food entry"), per-meal time changes, manual food
  entry UI. The home build id (#31) is untouched.
- Remove/rewrite the corresponding tests (see Testing).

## Testing

- **`HttpMealRepository`** (inject a fake `http.Client`): `getDayMeals` GETs
  `/api/meals?day=<day>` and parses the flat `totals` + per-meal (day-less) items
  + nested `consumed`; `createMeal` POSTs `/api/meals` with `{day, meal, time?,
  items}`, asserting each dictionary item serializes as `food_item_id` +
  `quantity` XOR `grams` (never both), and parses the `201` meal; `loggedDays`
  GETs `/api/meals/logged-days?month=`. `401` → `DietReauthenticationRequired`;
  non-2xx / transport error → `DietFetchFailure`. Assert method + path + body.
- **`CreateMealController`** (fake `MealRepository`): add/remove/setAmount/
  toggleGrams mutate the tray; `submit` builds the expected `CreateMealItem`s
  (grams row → `grams`, unit row → `quantity`) and calls `createMeal`;
  `DietReauthenticationRequired` → `needsReauth`, `DietFetchFailure` → `error`.
- **`FoodSearchScreen`** (widget, fakes + `l10nTestApp`): pinned search field +
  full-page results; tapping a result adds a tray row; the amount control edits
  the amount and (with base grams) toggles portion/gram, updating the preview and
  the running total pill; "Done" submits and pops with a result; back without
  completing discards. A narrow-width test (`setSurfaceSize`) asserts the layout
  does **not** need any `viewInsets`/`visualViewport` handling — the results list
  is reachable with the field pinned.
- **`AmountStepper`** (widget): −/+ step and clamp at 0; typing updates; the
  empty-zero convention (`value == 0` → empty field + `hintText: '0'`); the
  portion/gram toggle appears only when `allowGrams`.
- **`TodayController`** (fake use cases): `load` populates the `DayMealsLog` +
  target; `DietReauthenticationRequired` → `needsReauth`, `DietFetchFailure` →
  `error`.
- **`TodayScreen`** (widget): progress bars use `totals` vs `target.effective`;
  meals + snacks interleave by meal `time` (a mid-day snack renders between two
  meals); empty standard meals render after the timeline in fixed order; each card
  shows the meal `time` and a per-meal total pill; item rows show consumed portion
  pills and are **not tappable** (read-only); the card add control and "＋ new
  snack" invoke the shell callbacks with the right meal.
- Remove `diet-entries`-era tests (log/manual/edit/quantity-card/dictionary-sheet/
  keyboard-inset) and any `DayDietLog`/`FoodEntry` fixtures.
