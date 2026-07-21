# health-diet Specification

## Purpose
TBD - created by archiving change add-health-diet. Update Purpose after archive.
## Requirements
### Requirement: Diet module entry from home

The app SHALL let an authenticated user open the diet module from the home
"健康" space tile, presenting a shell with Today and Target sections.

#### Scenario: Open diet from home
- **WHEN** an authenticated user taps the "健康" tile on the home screen
- **THEN** the app navigates to the diet shell showing the Today section

### Requirement: Today's diet log by meal in eaten order

The Today section SHALL read the day's meals from the meals API and present each
meal as a card. It SHALL order all meals that exist — the standard meals
(breakfast, lunch, dinner) and snacks alike — together by each meal's single
eaten-at `time`, earliest first, so a snack eaten between two meals appears
between them. Standard meals that have no meal for the day SHALL be shown after
the ordered meals as empty cards in breakfast, lunch, dinner order. It SHALL show
per-category portion progress — staple, meat, fruit, and vegetable — as a
per-category progress bar (a filled track proportional to consumed-over-target),
where consumed is the day's meal portion totals and target is the day's effective
target, alongside the used / target numbers. A meal card SHALL be labeled with
the meal — an emoji plus a localized name for the standard meals, and the snack's
own name (which a snack meal already carries as its `meal` value) for a snack — and
the meal's `time`, and SHALL show a total pill summing the meal's consumed
portions. A meal card SHALL also offer a control to change the meal's time and a
control to delete the whole meal behind a confirmation.
For each of the meal's items the card SHALL show the item's consumed portions
across every food group it contributes to — labeled and color-coded by category,
omitting groups whose portion is zero — together with the item's consumed amount
(its measure or quantity). The item rows SHALL be **editable**: tapping an item
reveals an inline amount control to adjust it, and each item offers a way to
delete it. An empty meal card SHALL show the meal and an empty indication. Each
meal card SHALL offer a way to add a food into that meal, and the Today section
SHALL offer a way to start a new snack, without leaving to re-select the meal.

#### Scenario: Meals and snacks ordered by meal time
- **WHEN** the day has breakfast at 08:00, a snack "點心2" at 10:30, lunch at 12:30, a snack at 15:00, and dinner at 19:00
- **THEN** the Today section shows those cards in that eaten-at order, with the 10:30 and 15:00 snacks interleaved between the meals

#### Scenario: Empty standard meals shown after existing meals
- **WHEN** the day has only a lunch meal
- **THEN** the Today section shows the lunch card, then empty breakfast and dinner cards after it, each still offering a way to add a food into that meal

#### Scenario: Snack card labeled with the snack's own name
- **WHEN** the day has a snack meal named "點心2"
- **THEN** its card is labeled "點心2" (the snack's own name), with the snack emoji

#### Scenario: Per-category progress from day totals
- **WHEN** the day has an effective target of 12 staple and the day's meal totals are 9 staple portions
- **THEN** the Today section shows staple progress as 9 of 12 with a bar filled to three-quarters

#### Scenario: Meal card shows its time and total
- **WHEN** a breakfast meal has time 08:10 and its items consume 4 staple and 1 meat portions in total
- **THEN** the breakfast card shows the time 08:10 and a total pill of 4 staple and 1 meat

#### Scenario: An item shows its consumed portions and amount, and is editable
- **WHEN** a meal item consumes 0 staple and 1 meat portion (e.g. 蛋/1個)
- **THEN** its row shows a "meat 1" portion pill, does not show a lone "0" staple value, shows its consumed amount, and is tappable to edit in place

#### Scenario: Add a food into a specific meal from Today
- **WHEN** the user taps the add control on the lunch card
- **THEN** the full-screen food search opens with the target meal set to lunch, ready to pick a food, without the user re-selecting the meal

### Requirement: Meals and snacks

The app SHALL offer the three standard meals (breakfast, lunch, dinner) and SHALL
let the user add a snack entry with its own label in addition to them.

#### Scenario: Add a snack
- **WHEN** the user chooses to add a snack and logs a food to it
- **THEN** the snack appears in the day's log ordered by its eaten-at time alongside the standard meals

### Requirement: Favorite dictionary items

The app SHALL let the user mark and unmark dictionary items as favorites and view
their favorites while logging.

#### Scenario: Favorite appears in favorites list
- **WHEN** the user favorites a dictionary item and opens the favorites view
- **THEN** that item appears in the favorites list

### Requirement: Daily portion target

The app SHALL let the user view and set the day's per-category portion targets
(staple, meat, fruit, vegetable) and SHALL show the remaining portions for each
category against what has been logged. Targets SHALL be adjustable via
increment/decrement steppers per category, each labeled with a category color
icon. Remaining SHALL be shown per category as a bar (filled by
consumed-against-target) alongside the remaining number.

#### Scenario: Set target and see remaining
- **WHEN** the user sets the staple target to 12 and has logged 9 staple portions
- **THEN** the target view shows 3 staple portions remaining

#### Scenario: Adjust a target with the stepper
- **WHEN** the user taps the staple increment control
- **THEN** the staple target increases by one step and the draft reflects the new value

### Requirement: Navigate the diet log by day

The diet view SHALL let the user move between days: a header showing the viewed
day with previous/next controls and a calendar entry point. Selecting a different
day SHALL reload that day's entries and its portion target. The user MUST NOT be
able to navigate to a day after today — the "next" control SHALL be disabled when
the viewed day is today, and the calendar SHALL disable future dates.

#### Scenario: Move to the previous day
- **WHEN** the user taps the previous-day control on today's view
- **THEN** the view shows the prior day's entries and that day's target

#### Scenario: Future is blocked
- **WHEN** the viewed day is today
- **THEN** the next-day control is disabled and the calendar does not allow picking a future date

#### Scenario: Calendar marks days with entries
- **WHEN** the user opens the calendar for a month
- **THEN** days on which the user has at least one entry are visually marked, and picking a day shows that day's log

### Requirement: Snack auto-numbering

When the user starts a new snack from Today, the app SHALL seed the new snack's
name to the next name in the day's snack series: the first snack of the day uses
the base snack word, and each subsequent new snack uses the base word followed by
an incrementing number. All foods added into one snack session SHALL share that
one snack name (one meal); the number SHALL only advance when a new snack is
started after the day already contains that snack. Renamed snacks (names not in
the snack series) SHALL NOT affect the numbering.

#### Scenario: First snack of the day
- **WHEN** the day has no snacks and the user starts a new snack
- **THEN** the snack name defaults to the base snack word (no number)

#### Scenario: Second snack numbers up
- **WHEN** the day already has a snack with the base word and the user starts a new snack
- **THEN** the snack name defaults to the base word followed by "2"

#### Scenario: Same session shares one meal
- **WHEN** the user adds several foods into one snack session before completing
- **THEN** they all share the same snack name and appear in one meal

#### Scenario: Renamed snack ignored by numbering
- **WHEN** an existing snack has a custom name and the user starts a new snack
- **THEN** the custom-named snack is not counted toward the snack numbering

### Requirement: Return to home from the diet module

The diet module SHALL offer a visible control to return to the home "your spaces"
screen, since the module is opened from home. Activating it SHALL return to home.

#### Scenario: Home button returns to home
- **WHEN** the user taps the home control in the Today header
- **THEN** the app returns to the home "your spaces" screen

### Requirement: Add to an existing snack group

Each snack card shown on the day SHALL offer a way to add another food into
**that** snack (continuing it), distinct from starting a new snack. Using it SHALL
open the full-screen food search with the target meal set to that snack's name, so
foods added there join the same snack without incrementing the snack number.

#### Scenario: Continue an existing snack
- **WHEN** the day has a snack "點心2" and the user taps its "add to this snack" control
- **THEN** the food search opens with the target meal set to "點心2" (not the next number), so the food joins that snack

#### Scenario: New snack still increments
- **WHEN** the user instead uses the Today section's start-a-new-snack control
- **THEN** the target meal is seeded to the next snack name (a new snack)

### Requirement: Diet surfaces fit narrow (mobile) screens

The diet surfaces SHALL remain usable at narrow phone widths without clipping
content or overflowing their layout. Specifically: the Today day-navigation header
SHALL show the date and calendar affordance without a layout overflow at narrow
widths (ellipsizing the date text as needed); and the full-screen food search
SHALL keep its search results reachable above the on-screen keyboard when the
search field is focused, without any visual-viewport keyboard-inset workaround —
being a full-screen page, its scaffold resizes for the keyboard so the pinned
search field stays at the top and the results list shrinks to remain scrollable
above it. The amount control (the −/field/+ stepper with its unit label and
portion/measure toggle, in both the food-search tray and Today's in-place item
editor) SHALL have a layout that is stable across a portion/measure mode toggle —
the mode toggle keeps a fixed position and the number of lines does not change
when the mode is switched — and SHALL NOT overflow at narrow phone widths
(320dp/360dp) in either supported locale, ellipsizing the after-field unit label
as needed rather than overflowing.

#### Scenario: Day header does not overflow on a narrow screen
- **WHEN** the diet shell is shown at a narrow phone width and the date label is long
- **THEN** the header shows the (possibly ellipsized) date and the calendar affordance with no layout overflow

#### Scenario: Search results stay reachable above the keyboard
- **WHEN** the user focuses the food search's search field at a narrow phone width and the on-screen keyboard is shown
- **THEN** the results list shrinks so its lower rows can be scrolled up into view above the keyboard, while the search field stays pinned at the top, with no viewport-inset workaround

#### Scenario: The amount control does not reflow when the mode is toggled
- **WHEN** the user toggles a tray or in-place amount control between portion (份量) and measure (顆/公克/毫升) mode
- **THEN** the portion/measure toggle stays in the same position and the control keeps the same number of lines, only the after-field unit label changing with the mode

#### Scenario: The amount control does not overflow on a narrow screen in either locale
- **WHEN** a gram or household amount control is shown at 320dp or 360dp width, in English or Traditional Chinese, in either portion or measure mode
- **THEN** the control renders with no layout overflow, the after-field unit label ellipsizing if there is not enough room

### Requirement: Add foods into a meal via a full-screen search

Adding food into a meal SHALL happen in a full-screen food search page pushed
over the diet shell, not in a bottom sheet. The page SHALL be opened for a target
meal chosen by the caller (a standard meal from a meal card's add control, an
existing snack from its "add to this snack" control, or the next snack from the
start-a-new-snack control), and SHALL show that target meal in its header
("Add to <meal>") with a back control. It SHALL pin a search field at the top and
fill the rest of the page with the search results list; each result row SHALL show
the food's portions (as category-colored pills) and a favorite toggle. Tapping a
result SHALL add it to the page's local current-meal tray rather than immediately
saving it, so the user can add several foods before completing. Backing out of the
page without completing SHALL discard the tray (nothing is saved). The page SHALL
NOT offer an in-page meal switch or snack rename (the meal is fixed by the
caller).

#### Scenario: Opened for a target meal
- **WHEN** the user taps the add control on the lunch card
- **THEN** the full-screen search opens titled for lunch, with a pinned search field over a full-page results list

#### Scenario: Tapping a result adds it to the tray, not the backend
- **WHEN** the user searches "飯", taps `飯/1碗` in the results
- **THEN** that food is added to the current-meal tray on the page and no entry is created on the backend yet

#### Scenario: Backing out discards the tray
- **WHEN** the user has added foods to the tray and then taps back without completing
- **THEN** the page closes and nothing is saved for that meal

### Requirement: Build the meal in an item tray with adjustable amounts

The full-screen food search SHALL show a current-meal tray of the foods added so
far. Each dictionary tray item SHALL have an amount control combining a −/+
stepper with a typable numeric field (following the empty-zero numeric
convention: an amount of zero shows an empty field with a "0" hint) and a unit
label. The amount control's portion side SHALL always be labeled 份 (a generic
portion word, not a word scraped from the food name). When the item has a defined
base measure the tray item SHALL also offer a portion/measure toggle whose
measure side is labeled by the item's own `measure_unit` — 公克 for a gram item,
毫升 for a millilitre item, and the unit word itself for a household-unit item
(顆/碗/杯), never a bare "g"/"ml"; in measure mode the amount is entered in that
measure unit and converted to a quantity via the item's base amount. Because
household-unit foods now carry a base measure, they too offer this toggle (enter
by 份 or by 顆/碗/杯); only a food with no base measure at all offers unit
quantity (份) only. Each tray item SHALL preview its resulting portions as
category-colored pills, computed on the client as the item's per-unit portions ×
the effective quantity (a measure amount first converted via the base amount),
without a backend round-trip; a manually-entered tray item previews the portions
the user entered directly. The tray SHALL show a running total pill summing all
tray items' previewed portions. A tray item SHALL be removable.

#### Scenario: Amount stepper and typable field
- **WHEN** the user sets a tray item's quantity to 1.5 via the field or the +/− stepper
- **THEN** the item's amount reads 1.5 and its portion preview scales accordingly

#### Scenario: Preview scales with quantity
- **WHEN** a tray item is `飯/1碗` (4 staple portions) with quantity 1.5
- **THEN** its preview shows 6 staple portions

#### Scenario: The after-field unit label reads 份, not a scraped unit word
- **WHEN** the user views any tray item's amount control in portion mode
- **THEN** the unit label after the number field reads 份, regardless of the food's name or unit (the mode-toggle button keeps its own label 份量)

#### Scenario: A gram item labels its measure side 公克
- **WHEN** the user picks `飯/50g` (measure unit g, base amount 50, 1 staple portion) and enters 33 in measure mode
- **THEN** the measure side is labeled 公克 and the preview shows approximately 0.66 staple portions

#### Scenario: A household-unit item can be entered by its unit
- **WHEN** the user picks `櫻桃/9顆` (measure unit 顆, base amount 9, 1 fruit portion) and enters 18 in measure mode
- **THEN** the measure side is labeled 顆, the amount is entered directly, and the preview shows 2 fruit portions

#### Scenario: A food with no base measure offers 份 only
- **WHEN** the user picks a food with no base measure (e.g. 熟肉/掌心大)
- **THEN** the tray item offers a portion quantity in 份 only, with no portion/measure toggle

#### Scenario: Running total across the tray
- **WHEN** the tray has two items previewing 6 and 2 staple portions
- **THEN** the tray total pill shows 8 staple portions

### Requirement: Complete the tray to save the meal

The full-screen food search SHALL offer a complete action that saves the whole
tray as one meal for the target day and meal via the backend meals API, sending
each dictionary tray item as either a unit quantity or a measure amount (never
both), and each manually-entered tray item as its name and portions (no
dictionary reference). On success the app SHALL close the page and refresh the
Today view so the new meal appears. The meal's `time` SHALL default to now for a
newly created meal; adding items to a meal slot that already exists SHALL append
them to that meal. A failure SHALL surface a localized error without losing the
tray, and an authentication failure SHALL route to re-authentication.

#### Scenario: Complete saves the tray as a meal and refreshes Today
- **WHEN** the target meal is lunch and the user completes a tray of two foods
- **THEN** the app creates the lunch meal with those two items via the meals API, closes the search, and Today shows the lunch card with them

#### Scenario: A measure-mode item is sent as a measure amount
- **WHEN** the tray has a `飯/50g` item entered as 33 in measure mode and the user completes it
- **THEN** the app sends that item with `measure: 33` and no `quantity`

#### Scenario: A manual item is sent without a dictionary id
- **WHEN** the tray has a manually-entered item and the user completes it
- **THEN** the app sends that item with its name and portions and no `food_item_id`

#### Scenario: Adding to an existing meal appends
- **WHEN** the day already has a lunch meal and the user completes a search targeting lunch with one more food
- **THEN** the food is appended to the existing lunch meal rather than creating a second lunch card

#### Scenario: Auth failure routes to re-authentication
- **WHEN** completing the tray fails with an authentication error
- **THEN** the app routes to re-authentication and the tray's contents are not lost

### Requirement: Edit a logged item's amount in place

The Today section SHALL let the user edit a logged meal item in place, without
leaving Today. Tapping an item SHALL reveal an inline amount control — the same
portion/measure-aware stepper used when building a meal for a dictionary item, or
the four category portion inputs for a manually-entered item — seeded with the
item's current amount. Committing a change SHALL persist it via
`PATCH /api/meal-items/:id`, sending `quantity` for a unit amount, `measure` for
a measure amount (the two mutually exclusive), or `portions` for a manual item,
and SHALL then refresh the day so the item's recomputed consumed portions and the
meal and day totals reflect the change. An authentication failure SHALL route to
re-authentication; editing an item the user does not own SHALL surface a
not-found error without crashing the view.

#### Scenario: Adjust a dictionary item's quantity
- **WHEN** the user taps a logged `飯/1碗` item and sets its quantity to 2
- **THEN** the app sends `PATCH /api/meal-items/:id` with `{quantity: 2}` and Today refreshes showing the item's doubled portions

#### Scenario: Adjust an item by switching to measure mode
- **WHEN** the user opens the editor (which defaults to quantity mode), switches to measure mode, and types 80 公克
- **THEN** the app sends `PATCH /api/meal-items/:id` with `{measure: 80}` and no `quantity`, and Today refreshes

#### Scenario: Adjust a manual item's portions
- **WHEN** the user edits a manual item's staple portions to 3
- **THEN** the app sends `PATCH /api/meal-items/:id` with `{portions: {staple: 3, ...}}` and Today refreshes

### Requirement: Change a meal's time

Each meal card SHALL offer a control to change the meal's eaten-at time. Using it
SHALL let the user pick a new time and SHALL persist it via `PATCH /api/meals/:id`
with the new time as an ISO-8601 string, keeping the meal on the same day, and
SHALL then refresh the day so the meal re-sorts into the timeline by its new time.
An authentication failure SHALL route to re-authentication.

#### Scenario: Changing time re-sorts the timeline
- **WHEN** the user changes a lunch meal's time from 12:30 to 09:00
- **THEN** the app sends `PATCH /api/meals/:id` with the new time and Today refreshes with the meal re-sorted earlier in the timeline

#### Scenario: Changing time keeps the meal on its day
- **WHEN** the user changes a meal's time on the viewed day
- **THEN** the meal stays on that day — only its time changes

### Requirement: Delete a logged item or a whole meal

The Today section SHALL let the user delete a single logged item and delete a
whole meal. Deleting an item SHALL call `DELETE /api/meal-items/:id`; deleting a
meal SHALL call `DELETE /api/meals/:id` (which cascades to its items) and SHALL
be confirmed by the user first. On success the app SHALL refresh the day so the
removed item or meal disappears and the totals update. An authentication failure
SHALL route to re-authentication.

#### Scenario: Delete a single item
- **WHEN** the user deletes one item from a meal that has several
- **THEN** the app calls `DELETE /api/meal-items/:id` and Today refreshes without that item, the meal's other items intact

#### Scenario: Delete a whole meal after confirming
- **WHEN** the user chooses to delete a meal and confirms
- **THEN** the app calls `DELETE /api/meals/:id` and Today refreshes without that meal

#### Scenario: Deleting a meal asks for confirmation first
- **WHEN** the user taps the delete control on a meal card
- **THEN** the app asks the user to confirm before calling the backend, and dismissing the confirmation deletes nothing

### Requirement: Add a food by manual entry

The full-screen food search SHALL offer a "not found? enter manually" affordance
that opens a manual-entry form for a food that is not in the dictionary. The form
SHALL collect a name and the four category portions (staple, meat, fruit,
vegetable) using the shared portion inputs and the empty-zero numeric convention
(a zero portion shows an empty field with a "0" hint). Submitting the form SHALL
add a manual item to the current-meal tray — marked as manually sourced, carrying
no dictionary reference — previewing exactly the portions entered. Completing the
tray SHALL save each manual item via the meals API as a manual item, its name and
portions, with no `food_item_id`.

#### Scenario: Manual entry adds a portions-only tray item
- **WHEN** the user opens manual entry, names a food and sets 1 staple and 1 meat portion, and adds it
- **THEN** a manual tray item appears previewing 1 staple and 1 meat, with no dictionary reference

#### Scenario: Completing saves a manual item without a dictionary id
- **WHEN** the tray has a manual item and the user completes it
- **THEN** the app posts that item to the meals API with its name and portions and no `food_item_id`

#### Scenario: Manual portions use the empty-zero convention
- **WHEN** the user opens manual entry with all portions at zero
- **THEN** each portion field shows an empty input with a "0" hint rather than a literal "0"

### Requirement: Measure-unit (g/ml) amount input

Amount entry for a dictionary food SHALL adapt to the food's measure unit, which
the food carries as `measure_unit` (`g` or `ml`) alongside its `base_amount`.
When the food defines a base measure, the amount control SHALL offer a
portion/measure toggle whose measure side is labeled by that unit — 公克 for `g`
and 毫升 for `ml` — and whose portion side SHALL show the food's own unit word
(e.g. 碗/杯/顆) or a generic portion word, never a bare "g"/"ml". In measure mode
the entered number SHALL be treated as an amount in that unit and sent to the
backend as `measure`; in portion mode it SHALL be sent as `quantity`. A food
without a base measure SHALL offer unit quantity only (no toggle).

#### Scenario: A gram food labels its measure side 公克
- **WHEN** the user builds a tray with `飯/50g` (measure unit g) and switches to measure mode
- **THEN** the measure side reads 公克 and the entered amount is sent as `measure`

#### Scenario: A millilitre food labels its measure side 毫升
- **WHEN** the food's measure unit is ml (e.g. 牛奶/240ml)
- **THEN** the amount control's measure side reads 毫升, not a bare "ml"

#### Scenario: Portion mode never shows a raw g/ml
- **WHEN** the amount control is in portion mode for any food
- **THEN** it shows the food's unit word or a generic portion word, never "g" or "ml"

