## MODIFIED Requirements

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
