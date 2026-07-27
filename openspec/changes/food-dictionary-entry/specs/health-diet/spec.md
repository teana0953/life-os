## MODIFIED Requirements

### Requirement: Add foods into a meal via a full-screen search

Adding food into a meal SHALL happen in a full-screen food search page pushed
over the diet shell, not in a bottom sheet. The page SHALL be opened either **for a
target meal** chosen by the caller (a standard meal from a meal card's add control, an
existing snack from its "add to this snack" control, or the next snack from the
start-a-new-snack control) — in which case it SHALL show that target meal in its header
("Add to <meal>") — **or with no target meal, as the food dictionary**, in which case it
SHALL identify itself as the dictionary instead. It SHALL have a back control, SHALL pin a
search field at the top and fill the rest of the page with the search results list; each
result row SHALL show the food's portions (as category-colored pills) and a favorite
toggle. Tapping a result SHALL add it to the page's local current-meal tray rather than
immediately saving it, so the user can add several foods before completing. Backing out of
the page without completing SHALL discard the tray (nothing is saved). The page SHALL NOT
offer an in-page meal switch or snack rename; when opened for a target meal that meal is
fixed by the caller, and when opened as the dictionary the meal is asked for once at
completion (see "Complete the tray to save the meal").

**When opened as the dictionary with an empty tray, the page SHALL NOT present recording
controls** — neither a complete action nor the manual-entry link — so that looking a food
up does not read as the start of recording it.

#### Scenario: Opened for a target meal
- **WHEN** the user taps the add control on the lunch card
- **THEN** the full-screen search opens titled for lunch, with a pinned search field over a full-page results list

#### Scenario: Opened as the dictionary
- **WHEN** the user opens the food dictionary from the diet screen
- **THEN** the same search page opens, identified as the dictionary rather than as adding to a meal, with the same search field and results list

#### Scenario: Browsing the dictionary shows no recording controls
- **WHEN** the dictionary is open and nothing has been added to the tray
- **THEN** neither the complete action nor the manual-entry link is shown

#### Scenario: Tapping a result adds it to the tray, not the backend
- **WHEN** the user searches "飯", taps `飯/1碗` in the results
- **THEN** that food is added to the current-meal tray on the page and no entry is created on the backend yet

#### Scenario: Choosing a food in the dictionary reveals the recording controls
- **WHEN** the user adds a food to the tray while browsing the dictionary
- **THEN** the tray and the complete action appear, so the intent to record is the user's own rather than the page's default

#### Scenario: Backing out discards the tray
- **WHEN** the user has added foods to the tray and then taps back without completing
- **THEN** the page closes and nothing is saved for that meal

### Requirement: Complete the tray to save the meal

The full-screen food search SHALL offer a complete action that saves the whole
tray as one meal for the target day and meal via the backend meals API, sending
each dictionary tray item as either a unit quantity or a measure amount (never
both), and each manually-entered tray item as its name and portions (no
dictionary reference). **When the page was opened as the dictionary, with no target meal,
completing SHALL first ask which meal the tray belongs to — the whole tray going to the one
chosen meal — and SHALL save nothing if the user does not choose one.** On success the app
SHALL close the page and refresh the Today view so the new meal appears. The meal's `time`
SHALL default to now for a newly created meal; adding items to a meal slot that already
exists SHALL append them to that meal. A failure SHALL surface a localized error without
losing the tray, and an authentication failure SHALL route to re-authentication.

#### Scenario: Complete saves the tray as a meal and refreshes Today
- **WHEN** the target meal is lunch and the user completes a tray of two foods
- **THEN** the app creates the lunch meal with those two items via the meals API, closes the search, and Today shows the lunch card with them

#### Scenario: Completing from the dictionary asks which meal
- **WHEN** the user completes a tray built in the dictionary
- **THEN** the app asks which meal it belongs to before saving, and saves the whole tray to the meal chosen

#### Scenario: Declining to choose a meal saves nothing
- **WHEN** the user dismisses the meal choice without picking one
- **THEN** nothing is saved and the tray is still there

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

## ADDED Requirements

### Requirement: The food dictionary can be reached without choosing a meal first

The diet screen SHALL offer a way to open the food dictionary directly, without first
choosing which meal a food would go into, so that looking up what a food counts as does not
require committing to record it.

#### Scenario: The dictionary opens from the diet screen
- **WHEN** the user is on the diet screen and uses the dictionary entry
- **THEN** the food dictionary opens, showing search and the user's favorites

#### Scenario: A looked-up food shows what it counts as
- **WHEN** the user searches or looks at their favorites in the dictionary
- **THEN** each food shows its portion amounts, which is what the user came to find out

#### Scenario: Favorites can be managed from the dictionary
- **WHEN** the user is in the dictionary
- **THEN** they can add or remove a food from their favorites

#### Scenario: The day being viewed is the day recorded
- **WHEN** the user opens the dictionary while viewing a past day and records something from it
- **THEN** it is recorded against the day they were viewing, not today

#### Scenario: A dictionary session starts clean
- **WHEN** the user abandons a per-meal search with items still in the tray, and then opens the dictionary
- **THEN** the dictionary opens with nothing in the tray, showing no recording controls
