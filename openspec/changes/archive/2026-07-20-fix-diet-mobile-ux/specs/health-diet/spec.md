## MODIFIED Requirements

### Requirement: Today's diet log by meal in eaten order

The Today section SHALL order all meal groups that have entries — the standard
meals (breakfast, lunch, dinner) and snack groups (any meal that is not one of
the three standard meals) alike — together by their earliest eaten-at time,
earliest first, so a snack eaten between two meals appears between them.
Standard meals with no entries SHALL be shown after the logged groups as empty
cards in breakfast, lunch, dinner order. It SHALL show per-category portion
progress (consumed against the day's target) for staple, meat, fruit, and
vegetable **as a per-category progress bar** (a filled track proportional to
consumed-over-target) alongside the used / target numbers. For each logged
food, the Today section SHALL show its portions across every food group it
contributes to — labeled and color-coded by category — and SHALL omit groups
whose portion is zero (so a food is never shown as a lone "0"). A meal card
with entries SHALL be labeled with the meal (an emoji for the standard meals,
and its localized name — an unnamed snack showing the localized snack word
rather than a raw internal value) and the group's earliest eaten-at time; an
empty meal card SHALL show the meal and an empty indication. Each meal card
SHALL offer a way to add a food into that meal, and the Today section SHALL
offer a way to start a new snack, without leaving to re-select the meal.

#### Scenario: Logged meals and snacks ordered by time
- **WHEN** the day has breakfast at 08:00, a snack "點心2" at 10:30, lunch at 12:30, a snack at 15:00, and dinner at 19:00
- **THEN** the Today section shows those cards in that eaten-at order, with the 10:30 and 15:00 snacks interleaved between the meals

#### Scenario: Empty standard meals shown after logged groups
- **WHEN** the day has only a lunch entry
- **THEN** the Today section shows the lunch card, then empty breakfast and dinner cards after it, each still offering a way to add a food into that meal

#### Scenario: Unnamed snack shows the localized snack word
- **WHEN** a snack group was logged without a custom name (the bare snack value)
- **THEN** its card is labeled with the localized snack word, not a raw internal value

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

#### Scenario: Start a new snack from Today
- **WHEN** the user taps the start-a-new-snack control
- **THEN** a new snack session starts with the next snack name

### Requirement: Continuous logging into a current meal

The dictionary screen SHALL present a current-meal control (breakfast, lunch,
dinner, or snack) and a way to finish. When the user picks a food to log, the
entry's meal SHALL default to the current meal rather than always breakfast.
When the current meal is a snack, the current-meal control SHALL show the
current snack group's name (e.g. "點心3" or a renamed "下午茶"), not a generic
snack label, so the user can see which snack they are logging into, with the
rename control shown next to that name. After saving an entry, the app SHALL
show a localized confirmation, keep the current meal unchanged, and remain on
the dictionary so the user can log another food into the same meal. Finishing
SHALL return to the Today view.

#### Scenario: Picking a food defaults to the current meal
- **WHEN** the current meal is lunch and the user picks a dictionary item to log
- **THEN** the quantity card opens with lunch selected, not breakfast

#### Scenario: Snack session shows its name
- **WHEN** the current meal is a snack named "點心3"
- **THEN** the logging bar shows "點心3" (not just a generic snack label) with the rename control next to it

#### Scenario: Saving keeps the meal and confirms
- **WHEN** the user saves a food while the current meal is lunch
- **THEN** the app shows a localized "added to lunch" confirmation and the current meal stays lunch so the next pick is still lunch

#### Scenario: Finishing returns to Today
- **WHEN** the user taps Done on the logging bar
- **THEN** the app returns to the Today view

### Requirement: Add to an existing snack group

Each snack group shown on the day SHALL offer a way to add another food into
**that** snack group (continuing it), distinct from starting a new snack. Using it
SHALL open the add-food flow with the meal set to that snack group's name, so
foods logged there join the same group without incrementing the snack number.

#### Scenario: Continue an existing snack
- **WHEN** the day has a snack group "點心2" and the user taps its "add to this snack" control
- **THEN** the add-food flow opens with the current meal set to "點心2" (not the next number), so the food joins that group

#### Scenario: New snack still increments
- **WHEN** the user instead uses the Today section's start-a-new-snack control
- **THEN** the current meal is seeded to the next snack name (a new group)

## ADDED Requirements

### Requirement: Diet surfaces fit narrow (mobile) screens

The diet surfaces SHALL remain usable at narrow phone widths without clipping
content or overflowing their layout. Specifically: the Today day-navigation
header SHALL show the date and calendar affordance without a layout overflow at
narrow widths (ellipsizing the date text as needed); and the add-food logging
bar's meal controls (including the snack name and rename control) SHALL not
overflow at narrow widths.

#### Scenario: Day header does not overflow on a narrow screen
- **WHEN** the diet shell is shown at a narrow phone width and the date label is long
- **THEN** the header shows the (possibly ellipsized) date and the calendar affordance with no layout overflow

#### Scenario: Logging bar fits a narrow screen
- **WHEN** the logging bar is shown with a snack selected at a narrow phone width
- **THEN** the current snack name and the rename control are shown together without a layout overflow
