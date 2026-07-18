## MODIFIED Requirements

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

### Requirement: Daily portion target

The app SHALL let the user view and set the day's per-category portion targets
(staple, meat, fruit, vegetable) and SHALL show the remaining portions for each
category against what has been logged. Targets SHALL be adjustable via
increment/decrement steppers per category.

#### Scenario: Set target and see remaining
- **WHEN** the user sets the staple target to 12 and has logged 9 staple portions
- **THEN** the target view shows 3 staple portions remaining

#### Scenario: Adjust a target with the stepper
- **WHEN** the user taps the staple increment control
- **THEN** the staple target increases by one step and the draft reflects the new value
