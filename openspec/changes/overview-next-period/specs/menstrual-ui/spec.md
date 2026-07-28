## ADDED Requirements

### Requirement: The overview shows when the next period is due

The health overview SHALL show the predicted next period and how it relates to today, so
the user does not have to open the tracker to find out. The card SHALL be present whether
or not a prediction exists, because it is also the way into the tracker.

#### Scenario: A future prediction shows the date and the wait
- **WHEN** the predicted next start is later than today
- **THEN** the overview shows that date together with how many days away it is

#### Scenario: A prediction for today says so
- **WHEN** the predicted next start is today
- **THEN** the overview says it is expected today rather than showing a zero-day countdown

#### Scenario: Too little data to predict is stated, not hidden
- **WHEN** there is no prediction yet (fewer than two recorded periods)
- **THEN** the overview says a prediction is not possible yet and what would make it
  possible, rather than showing a placeholder or omitting the card

### Requirement: A prediction that has passed is reported as overdue

The overview SHALL say when the expected date has passed and by how much, rather than
presenting a past date as if it were upcoming, and SHALL NOT roll the prediction forward to
manufacture a future one. The prediction is the last recorded start plus the average cycle
and is not clamped to the future, so it falls into the past whenever recording has lapsed.

#### Scenario: An expected date in the past is called out
- **WHEN** the predicted next start is earlier than today
- **THEN** the overview shows that it is overdue, and by how many days

#### Scenario: The prediction is not advanced to the next cycle
- **WHEN** the predicted next start is well in the past
- **THEN** the date shown is still the predicted one, not one silently advanced by whole
  cycles to land in the future

### Requirement: An ongoing period takes precedence over the prediction

The overview SHALL report an ongoing period instead of the next prediction when today falls
inside the most recent recorded one — including a period with no recorded end — and SHALL
say which day of it today is. The day count SHALL NOT be capped: a period left open long
ago showing a large day count is the signal that it was never closed.

#### Scenario: Today inside a period reports the day of it
- **WHEN** today falls within the most recent recorded period
- **THEN** the overview says a period is ongoing and which day of it today is, instead of
  the next prediction

#### Scenario: A period with no end date counts as ongoing
- **WHEN** the most recent recorded period has no end date and started before today
- **THEN** it is treated as ongoing

### Requirement: The overview card opens the menstrual tracker

Tapping the card SHALL open the menstrual tracker, in every state including when there is
no prediction — the state in which the user is most likely to want to go and record
something.

#### Scenario: Tapping the card opens the tracker
- **WHEN** the user taps the card
- **THEN** the menstrual tracker opens

#### Scenario: The shortcut works with no data
- **WHEN** no period has been recorded yet
- **THEN** the card is still shown and still opens the tracker
