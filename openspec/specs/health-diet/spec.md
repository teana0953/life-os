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

The Today section SHALL show the selected day's food entries grouped by meal, with
meals and snacks ordered by their eaten-at time, and SHALL show per-category
portion progress (consumed against the day's target) for staple, meat, fruit, and
vegetable **as a per-category progress bar** (a filled track proportional to
consumed-over-target) alongside the used / target numbers. For each logged food,
the Today section SHALL show its portions across every food group it contributes
to — labeled and color-coded by category — and SHALL omit groups whose portion is
zero (so a food is never shown as a lone "0"). Each meal group SHALL be shown as a
card labeled with the meal (an emoji for the standard meals, and its localized
name) and the group's earliest eaten-at time.

#### Scenario: Meals shown in eaten order
- **WHEN** the day has a breakfast eaten at 08:00 and a lunch eaten at 12:30
- **THEN** the Today section lists breakfast before lunch

#### Scenario: Per-category progress
- **WHEN** the day has a target of 12 staple and 9 staple portions logged
- **THEN** the Today section shows staple progress as 9 of 12 with a bar filled to three-quarters

#### Scenario: A logged food shows all its portion categories
- **WHEN** a logged entry has 0 staple and 1 meat portion (e.g. 蛋/1個)
- **THEN** its row shows a "meat 1" portion pill and does not show a lone "0" staple value

#### Scenario: Meal group shows its time
- **WHEN** the earliest entry in the breakfast group was eaten at 08:10
- **THEN** the breakfast card shows the time 08:10

### Requirement: Log a food from the dictionary

The app SHALL let the user search the food dictionary, choose an item for a meal,
enter an amount as a decimal quantity of the item's unit, and save the entry. When
the chosen item has a base gram weight, the user MAY instead enter the amount in
grams; the app SHALL send the gram amount to the backend for the item and SHALL
NOT allow both a quantity and a gram amount at once. Each dictionary row SHALL
show the food's portions (as category-colored pills) and a favorite toggle. The
amount SHALL be adjusted with a −/+ stepper for unit quantity (grams remains a
numeric field), and the resulting portions SHALL be previewed as pills.

#### Scenario: Search and log by quantity
- **WHEN** the user searches "飯", selects `飯/1碗`, enters quantity 1.5 for lunch, and saves
- **THEN** the app creates the entry via the backend and it appears under lunch in the day's log

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

