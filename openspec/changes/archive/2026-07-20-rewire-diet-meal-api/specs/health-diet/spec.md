## MODIFIED Requirements

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
portions.
For each of the meal's items the card SHALL show the item's consumed portions
across every food group it contributes to — labeled and color-coded by category,
omitting groups whose portion is zero — and in this state the item rows SHALL be
**read-only** (not tappable to edit). An empty meal card SHALL show the meal and
an empty indication. Each meal card SHALL offer a way to add a food into that
meal, and the Today section SHALL offer a way to start a new snack, without
leaving to re-select the meal.

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

#### Scenario: An item shows all its consumed portion categories, read-only
- **WHEN** a meal item consumes 0 staple and 1 meat portion (e.g. 蛋/1個)
- **THEN** its row shows a "meat 1" portion pill, does not show a lone "0" staple value, and is not tappable to edit

#### Scenario: Add a food into a specific meal from Today
- **WHEN** the user taps the add control on the lunch card
- **THEN** the full-screen food search opens with the target meal set to lunch, ready to pick a food, without the user re-selecting the meal

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
above it.

#### Scenario: Day header does not overflow on a narrow screen
- **WHEN** the diet shell is shown at a narrow phone width and the date label is long
- **THEN** the header shows the (possibly ellipsized) date and the calendar affordance with no layout overflow

#### Scenario: Search results stay reachable above the keyboard
- **WHEN** the user focuses the food search's search field at a narrow phone width and the on-screen keyboard is shown
- **THEN** the results list shrinks so its lower rows can be scrolled up into view above the keyboard, while the search field stays pinned at the top, with no viewport-inset workaround

## ADDED Requirements

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
far. Each tray item SHALL have an amount control combining a −/+ stepper with a
typable numeric field for the unit quantity (following the empty-zero numeric
convention: an amount of zero shows an empty field with a "0" hint) and the item's
unit. When the item has a base gram weight the tray item SHALL also offer a
portion/gram toggle; in gram mode the amount is entered in grams and converted to
a quantity via the item's base grams. Each tray item SHALL preview its resulting
portions as category-colored pills, computed on the client as the item's per-unit
portions × the effective quantity (a gram amount first converted via base grams),
without a backend round-trip. The tray SHALL show a running total pill summing all
tray items' previewed portions. A tray item SHALL be removable.

#### Scenario: Amount stepper and typable field
- **WHEN** the user sets a tray item's quantity to 1.5 via the field or the +/− stepper
- **THEN** the item's amount reads 1.5 and its portion preview scales accordingly

#### Scenario: Preview scales with quantity
- **WHEN** a tray item is `飯/1碗` (4 staple portions) with quantity 1.5
- **THEN** its preview shows 6 staple portions

#### Scenario: Gram entry only for items with base grams, converted via base grams
- **WHEN** the user picks `飯/50g` (base grams 50, 1 staple portion) and enters 33 grams in gram mode
- **THEN** the preview shows approximately 0.66 staple portions, and an item with no base gram weight offers unit quantity only (no gram toggle)

#### Scenario: Running total across the tray
- **WHEN** the tray has two items previewing 6 and 2 staple portions
- **THEN** the tray total pill shows 8 staple portions

### Requirement: Complete the tray to save the meal

The full-screen food search SHALL offer a complete action that saves the whole
tray as one meal for the target day and meal via the backend meals API, sending
each tray item as either a dictionary item quantity or a gram amount (never both).
On success the app SHALL close the page and refresh the Today view so the new meal
appears. The meal's `time` SHALL default to now for a newly created meal; adding
items to a meal slot that already exists SHALL append them to that meal. A failure
SHALL surface a localized error without losing the tray, and an authentication
failure SHALL route to re-authentication.

#### Scenario: Complete saves the tray as a meal and refreshes Today
- **WHEN** the target meal is lunch and the user completes a tray of two foods
- **THEN** the app creates the lunch meal with those two items via the meals API, closes the search, and Today shows the lunch card with them

#### Scenario: Adding to an existing meal appends
- **WHEN** the day already has a lunch meal and the user completes a search targeting lunch with one more food
- **THEN** the food is appended to the existing lunch meal rather than creating a second lunch card

#### Scenario: Auth failure routes to re-authentication
- **WHEN** completing the tray fails with an authentication error
- **THEN** the app routes to re-authentication and the tray's contents are not lost

## REMOVED Requirements

### Requirement: Log a food from the dictionary

**Reason**: Superseded by the full-screen food search + item tray. Amount entry
moves from a per-item bottom sheet over the dictionary to the tray's amount
control; the search and add flow is covered by "Add foods into a meal via a
full-screen search" and "Build the meal in an item tray with adjustable amounts".

**Migration**: Amount, gram entry, per-item portion pills, and the favorite toggle
are provided by the new full-screen search and tray requirements.

### Requirement: Portion preview before saving

**Reason**: The client-side portion preview now lives on each tray item, folded
into "Build the meal in an item tray with adjustable amounts". There is no longer a
standalone quantity card.

**Migration**: The same client-side "per-unit × quantity (grams via base grams)"
preview is specified for tray items.

### Requirement: Settable eaten-at time

**Reason**: Entries no longer carry an individual eaten-at time; a meal carries a
single `time`, defaulted to now on creation. User-settable meal time is deferred
to PR③ (per-meal time changes).

**Migration**: "Complete the tray to save the meal" defaults the new meal's `time`
to now; changing a meal's time is a PR③ capability.

### Requirement: Manual food entry

**Reason**: No manual-entry UI in this PR. The meals API still accepts manual
items (name + portions or nutrients), but a manual-entry surface is deferred; this
PR's tray adds dictionary items only.

**Migration**: Deferred; the meals API still accepts manual items, so a
manual-entry surface (and the request payload for it) returns in a later PR.

### Requirement: Manual entry in a bottom sheet

**Reason**: The bottom-sheet add-food flow is removed entirely (replaced by the
full-screen search), and manual entry has no UI in this PR (see "Manual food
entry").

**Migration**: Deferred with manual entry.

### Requirement: Edit or delete a past food entry

**Reason**: Today's item rows are read-only in this PR. In-place item editing and
deletion on the new meal/meal-item model are PR③.

**Migration**: Tapping an item to edit, and deleting entries, return in PR③ against
`PATCH`/`DELETE /api/meal-items/:id`.

### Requirement: Continuous logging into a current meal

**Reason**: Superseded by the full-screen search. The target meal is fixed by the
entry point (no in-flow logging bar or meal switch), and a whole tray is saved at
once instead of one entry at a time with a stay-and-keep-picking bar.

**Migration**: Adding several foods into one meal is covered by the tray in "Build
the meal in an item tray with adjustable amounts" and "Complete the tray to save
the meal".

### Requirement: Add food via a dictionary bottom sheet

**Reason**: Superseded by the full-screen food search, which root-causes the
keyboard-collapse problem the bottom sheet fought. The bottom navigation already
excludes a dictionary tab.

**Migration**: The dictionary is reached only via the full-screen search opened
from a meal card / snack control, per "Add foods into a meal via a full-screen
search".

### Requirement: Browse the dictionary from Today

**Reason**: The browse-only dictionary sheet is removed; the only dictionary
surface is the full-screen search opened to add food into a meal. Favorites remain
available inside that search.

**Migration**: Favoriting and browsing the food list happen within the full-screen
search.
