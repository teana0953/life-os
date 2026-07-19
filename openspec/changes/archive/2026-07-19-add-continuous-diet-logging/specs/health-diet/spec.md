## ADDED Requirements

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
