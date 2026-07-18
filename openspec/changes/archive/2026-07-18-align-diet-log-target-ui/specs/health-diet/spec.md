## MODIFIED Requirements

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
