## ADDED Requirements

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
vegetable.

#### Scenario: Meals shown in eaten order
- **WHEN** the day has a breakfast eaten at 08:00 and a lunch eaten at 12:30
- **THEN** the Today section lists breakfast before lunch

#### Scenario: Per-category progress
- **WHEN** the day has a target of 12 staple and 9 staple portions logged
- **THEN** the Today section shows staple progress as 9 of 12

### Requirement: Log a food from the dictionary

The app SHALL let the user search the food dictionary, choose an item for a meal,
enter an amount as a decimal quantity of the item's unit, and save the entry. When
the chosen item has a base gram weight, the user MAY instead enter the amount in
grams; the app SHALL send the gram amount to the backend for the item and SHALL
NOT allow both a quantity and a gram amount at once.

#### Scenario: Search and log by quantity
- **WHEN** the user searches "飯", selects `飯/1碗`, enters quantity 1.5 for lunch, and saves
- **THEN** the app creates the entry via the backend and it appears under lunch in the day's log

#### Scenario: Gram entry only for items with base grams
- **WHEN** the user selects an item that has no base gram weight
- **THEN** the amount input offers unit quantity only (no gram option)

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
category against what has been logged.

#### Scenario: Set target and see remaining
- **WHEN** the user sets the staple target to 12 and has logged 9 staple portions
- **THEN** the target view shows 3 staple portions remaining
