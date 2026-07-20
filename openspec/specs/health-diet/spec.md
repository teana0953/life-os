# health-diet Specification

## Purpose
TBD - created by archiving change add-health-diet. Update Purpose after archive.
## Requirements
### Requirement: Diet module entry from home

The app SHALL let an authenticated user open the diet module from the home
"健康" space tile, presenting a shell with Today, Dictionary, and Target sections.

#### Scenario: Open diet from home
- **WHEN** an authenticated user taps the "健康" tile on the home screen
- **THEN** the app navigates to the diet shell showing the Today section

### Requirement: Today's diet log by meal in eaten order

The Today section SHALL show the three standard meals — breakfast, lunch, dinner —
as fixed cards in that order, always visible even when a meal has no entries, and
SHALL show a snack area collecting the day's snack groups (any meal that is not one
of the three standard meals) ordered by their eaten-at time. It SHALL show
per-category portion progress (consumed against the day's target) for staple,
meat, fruit, and vegetable **as a per-category progress bar** (a filled track
proportional to consumed-over-target) alongside the used / target numbers. For
each logged food, the Today section SHALL show its portions across every food
group it contributes to — labeled and color-coded by category — and SHALL omit
groups whose portion is zero (so a food is never shown as a lone "0"). A meal card
with entries SHALL be labeled with the meal (an emoji for the standard meals, and
its localized name) and the group's earliest eaten-at time; an empty meal card
SHALL show the meal and an empty indication. Each meal card SHALL offer a way to
add a food into that meal, and the snack area SHALL offer a way to start a new
snack, without leaving to re-select the meal.

#### Scenario: Standard meals always shown in order
- **WHEN** the day has only a lunch entry
- **THEN** the Today section still shows breakfast, lunch, and dinner cards in that order, with breakfast and dinner empty

#### Scenario: Per-category progress
- **WHEN** the day has a target of 12 staple and 9 staple portions logged
- **THEN** the Today section shows staple progress as 9 of 12 with a bar filled to three-quarters

#### Scenario: A logged food shows all its portion categories
- **WHEN** a logged entry has 0 staple and 1 meat portion (e.g. 蛋/1個)
- **THEN** its row shows a "meat 1" portion pill and does not show a lone "0" staple value

#### Scenario: Meal card shows its time
- **WHEN** the earliest entry in the breakfast group was eaten at 08:10
- **THEN** the breakfast card shows the time 08:10

#### Scenario: Add a food into a specific meal from Today
- **WHEN** the user taps the add control on the lunch card
- **THEN** the logging flow opens with the current meal set to lunch, ready to pick a food, without the user re-selecting the meal

#### Scenario: Snack area lists snacks and can add one
- **WHEN** the day has snack groups (e.g. "點心", "下午茶")
- **THEN** they appear in the snack area (not among the standard meal cards), which offers an add-snack control that starts a new snack session

### Requirement: Log a food from the dictionary

The app SHALL let the user search the food dictionary, choose an item, enter an
amount as a decimal quantity of the item's unit, and save the entry into the
current logging session's meal. The item's amount SHALL be entered in a **bottom
sheet** that opens over the dictionary (the dictionary stays visible), rather than a
full-screen page; the meal SHALL be taken from the current session (set by the
logging bar or the per-meal add), so the amount sheet does not itself offer a meal
selection. Adding SHALL dismiss the sheet and leave the dictionary in place so the
user can pick another food into the same meal. When the chosen item has a base gram
weight, the user MAY instead enter the amount in grams; the app SHALL send the gram
amount to the backend for the item and SHALL NOT allow both a quantity and a gram
amount at once. Each dictionary row SHALL show the food's portions (as
category-colored pills) and a favorite toggle. The amount SHALL be adjusted with a
−/+ stepper for unit quantity (grams remains a numeric field), and the resulting
portions SHALL be previewed as pills.

#### Scenario: Search and log by quantity into the session meal
- **WHEN** the current meal is lunch and the user searches "飯", selects `飯/1碗`, enters quantity 1.5, and adds
- **THEN** the app creates the entry via the backend and it appears under lunch in the day's log

#### Scenario: Amount entered in a bottom sheet over the dictionary
- **WHEN** the user taps a dictionary item to log it
- **THEN** the quantity entry opens as a bottom sheet with the dictionary still visible, and adding dismisses the sheet without leaving the dictionary

#### Scenario: The amount sheet has no meal selection
- **WHEN** the quantity bottom sheet is open
- **THEN** it shows the amount, preview, time, and add controls but no meal chooser (the meal is the session's)

#### Scenario: Gram entry only for items with base grams
- **WHEN** the user selects an item that has no base gram weight
- **THEN** the amount input offers unit quantity only (no gram option)

#### Scenario: Dictionary row shows portions
- **WHEN** the dictionary lists `飯/1碗` (4 staple portions)
- **THEN** that row shows a "staple 4" portion pill

### Requirement: Portion preview before saving

The quantity card SHALL show the resulting portions as the user enters the amount,
computed on the client as the dictionary item's portions × quantity (a gram amount
first converted to a quantity via the item's base grams), without a backend
round-trip. The saved entry's stored values SHALL come from the backend response.

#### Scenario: Preview scales with quantity
- **WHEN** the user picks `飯/1碗` (4 staple portions) and sets quantity 1.5
- **THEN** the quantity card previews 6 staple portions

#### Scenario: Gram amount previews via base grams
- **WHEN** the user picks `飯/50g` (base grams 50, 1 staple portion) and enters 33 grams
- **THEN** the quantity card previews approximately 0.66 staple portions

### Requirement: Settable eaten-at time

When logging an entry the app SHALL default the eaten-at time to now and SHALL let
the user change it before saving.

#### Scenario: Eaten-at defaults to now and can be changed
- **WHEN** the user opens the quantity card
- **THEN** the eaten-at time defaults to the current time and the user can set a different time before saving

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

### Requirement: Manual food entry

The app SHALL let the user log a food that is not in the dictionary by entering an
optional name and portions per food group (staple / meat / fruit / vegetable,
decimals allowed) for a meal, with a settable eaten-at time that defaults to now.
The manual-entry path SHALL be reachable from the dictionary/logging flow. A save
SHALL create the entry via the backend's manual path and SHALL refresh Today.

#### Scenario: Log a manual entry
- **WHEN** the user opens manual entry, enters 2 staple and 1 meat portion for lunch, and saves
- **THEN** the app creates the entry via the backend and it appears under lunch in the day's log

#### Scenario: Manual entry reachable from the logging flow
- **WHEN** the user is in the dictionary/logging flow and cannot find the food
- **THEN** a manual-entry entry point is available

#### Scenario: Eaten-at defaults to now and is settable
- **WHEN** the user opens manual entry
- **THEN** the eaten-at time defaults to now and can be changed before saving

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

### Requirement: Edit or delete a past food entry

The diet view SHALL let the user tap a logged entry to open an editor prefilled
with the entry's name, four portion values, meal, and eaten-at time. Saving SHALL
update the entry via the backend and refresh the viewed day. The editor SHALL also
offer deleting the entry, which removes it and refreshes the viewed day. A failure
SHALL surface a localized error without losing the user's edits, and an
authentication failure SHALL route to re-authentication.

#### Scenario: Edit an entry's portions
- **WHEN** the user taps an entry, changes its staple portions, and saves
- **THEN** the entry is updated and the day's portion progress reflects the new value

#### Scenario: Delete an entry
- **WHEN** the user opens an entry's editor and confirms delete
- **THEN** the entry is removed and the day's log no longer shows it

#### Scenario: Edit prefilled from the entry
- **WHEN** the user taps an entry named "雞腿便當" with 3 staple and 3 meat portions
- **THEN** the editor opens showing that name, 3 staple, 3 meat, and the entry's meal and time

#### Scenario: Editing without changing the time keeps the entry's day
- **WHEN** the user edits an entry's portions or name but does not change its eaten-at time, then saves
- **THEN** the entry remains on the same day (its eaten-at time is not resent)

### Requirement: Continuous logging into a current meal

The dictionary screen SHALL present a current-meal control (breakfast, lunch,
dinner, or snack) and a way to finish. When the user picks a food to log, the
entry's meal SHALL default to the current meal rather than always breakfast.
After saving an entry, the app SHALL show a localized confirmation, keep the
current meal unchanged, and remain on the dictionary so the user can log another
food into the same meal. Finishing SHALL return to the Today view.

#### Scenario: Picking a food defaults to the current meal
- **WHEN** the current meal is lunch and the user picks a dictionary item to log
- **THEN** the quantity card opens with lunch selected, not breakfast

#### Scenario: Saving keeps the meal and confirms
- **WHEN** the user saves a food while the current meal is lunch
- **THEN** the app shows a localized "added to lunch" confirmation and the current meal stays lunch so the next pick is still lunch

#### Scenario: Finishing returns to Today
- **WHEN** the user taps Done on the logging bar
- **THEN** the app returns to the Today view

### Requirement: Snack auto-numbering

When the current meal is switched to snack, the app SHALL default the snack group
name to the next name in the day's snack series: the first snack of the day uses
the base snack word, and each subsequent new snack session uses the base word
followed by an incrementing number. All foods logged within one session SHALL
share that one snack name (one group); the number SHALL only advance when a new
snack session is started after the day already contains that snack group. The
user SHALL be able to rename the current snack session. Renamed snack groups
(names not in the snack series) SHALL NOT affect the numbering.

#### Scenario: First snack of the day
- **WHEN** the day has no snack groups and the user switches to snack
- **THEN** the snack name defaults to the base snack word (no number)

#### Scenario: Second snack session numbers up
- **WHEN** the day already has a snack group with the base word and the user starts a new snack session
- **THEN** the snack name defaults to the base word followed by "2"

#### Scenario: Same session shares one group
- **WHEN** the user logs several foods within one snack session
- **THEN** they all share the same snack name and appear in one group

#### Scenario: Renamed snack ignored by numbering
- **WHEN** an existing snack group has been renamed to a custom name and the user starts a new snack session
- **THEN** the custom-named group is not counted toward the snack numbering

