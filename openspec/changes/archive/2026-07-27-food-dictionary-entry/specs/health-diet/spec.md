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

**While the user is still browsing the dictionary — nothing searched, nothing in the tray —
the page SHALL NOT present recording controls**: neither a complete action nor a standing
manual-entry link, so that looking a food up does not read as the start of recording it.
**A search that comes back with nothing SHALL instead offer manual entry from its own empty
state**, as the next step the user's own search asked for rather than as a control the page
shows by default; where the standing manual-entry link is already present (any search opened
for a target meal, or a dictionary session that already has a tray), the empty state SHALL
NOT repeat it.

The results area SHALL always say what it is showing rather than going blank — in dictionary
mode it is the whole page, so a blank one is indistinguishable from a broken one. It SHALL
tell apart: the dictionary still loading; loading or searching having failed (a localized
failure message, and for an authentication failure a way to re-authenticate, since in
dictionary mode there is no other recovery exit on the page); the user having no favorites
yet; and a search that found nothing, naming the query that found nothing.

#### Scenario: Opened for a target meal
- **WHEN** the user taps the add control on the lunch card
- **THEN** the full-screen search opens titled for lunch, with a pinned search field over a full-page results list

#### Scenario: Opened as the dictionary
- **WHEN** the user opens the food dictionary from the diet screen
- **THEN** the same search page opens, identified as the dictionary rather than as adding to a meal, with the same search field and results list

#### Scenario: Browsing the dictionary shows no recording controls
- **WHEN** the dictionary is open, nothing has been searched and nothing has been added to the tray
- **THEN** neither the complete action nor the standing manual-entry link is shown

#### Scenario: An empty dictionary says so rather than showing a blank page
- **WHEN** the user opens the dictionary and has no favorite foods yet
- **THEN** the results area says there are none yet and invites a search, instead of an empty page

#### Scenario: A search that finds nothing offers manual entry
- **WHEN** the user searches the dictionary for a food that isn't there
- **THEN** the results area names the query that found nothing and offers to enter that food manually

#### Scenario: The no-results state does not duplicate an entrance that is already there
- **WHEN** a search finds nothing on a page that already shows the standing manual-entry link
- **THEN** manual entry is offered once, not twice

#### Scenario: Failing to load is distinguishable from having nothing
- **WHEN** loading the dictionary fails
- **THEN** the results area says loading failed, which is not the same as saying the user has no foods

#### Scenario: An authentication failure in the dictionary is not a dead end
- **WHEN** loading the dictionary fails because the user needs to authenticate again
- **THEN** the results area offers to re-authenticate, which in dictionary mode is the page's only recovery exit

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
chosen meal — and SHALL save nothing if the user does not choose one.** Every meal offered
SHALL stay reachable whatever the screen height or text size, and if the page is gone by the
time a choice comes back nothing SHALL be saved. On success the app
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

#### Scenario: Every meal offered can still be picked on a short screen
- **WHEN** the meal question does not fit the space it is given
- **THEN** the user can still reach and pick the last option rather than having it cut off

#### Scenario: The page going away while the meal question is open saves nothing
- **WHEN** the user is signed out while the meal question is still open, and a choice comes back afterwards
- **THEN** nothing is saved

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
