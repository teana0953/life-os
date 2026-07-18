## MODIFIED Requirements

### Requirement: Today's diet log by meal in eaten order

The Today section SHALL show the selected day's food entries grouped by meal, with
meals and snacks ordered by their eaten-at time, and SHALL show per-category
portion progress (consumed against the day's target) for staple, meat, fruit, and
vegetable. For each logged food, the Today section SHALL show its portions across
every food group it contributes to — labeled and color-coded by category — and
SHALL omit groups whose portion is zero (so a food is never shown as a lone "0").

#### Scenario: Meals shown in eaten order
- **WHEN** the day has a breakfast eaten at 08:00 and a lunch eaten at 12:30
- **THEN** the Today section lists breakfast before lunch

#### Scenario: Per-category progress
- **WHEN** the day has a target of 12 staple and 9 staple portions logged
- **THEN** the Today section shows staple progress as 9 of 12

#### Scenario: A logged food shows all its portion categories
- **WHEN** a logged entry has 0 staple and 1 meat portion (e.g. 蛋/1個)
- **THEN** its row shows a "meat 1" portion pill and does not show a lone "0" staple value

## ADDED Requirements

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
