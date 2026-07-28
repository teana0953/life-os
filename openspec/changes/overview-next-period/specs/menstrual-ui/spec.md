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

#### Scenario: Having recorded nothing is stated plainly
- **WHEN** no period has been recorded at all
- **THEN** the overview says so, rather than showing a placeholder or omitting the card

#### Scenario: One recorded period says what would make a prediction possible
- **WHEN** exactly one period has been recorded, so a cycle length cannot be derived
- **THEN** the overview says recording one more would make a prediction possible — a
  promise it SHALL NOT make to someone who has recorded nothing, for whom one more
  recording still yields no prediction

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

The overview SHALL report an ongoing period ahead of the next prediction when today falls
inside any recorded period — including one with no recorded end — and SHALL say which day
of it today is, while still showing the predicted next start. The day count SHALL NOT be
capped: a period left open long ago showing a large day count is the signal that it was
never closed.

#### Scenario: Today inside a period reports the day of it
- **WHEN** today falls within a recorded period
- **THEN** the overview says a period is ongoing and which day of it today is, ahead of the
  next prediction

#### Scenario: An ongoing period does not hide a prediction still ahead
- **WHEN** a period is ongoing and the predicted next start is still in the future
- **THEN** the predicted date is still shown, so someone who records starts but not ends
  is not left without the thing this card exists to show

#### Scenario: An ongoing period drops a prediction that has arrived or passed
- **WHEN** a period has been left open until its predicted next start is today or earlier
- **THEN** no predicted date is shown — labelling today's date "next expected", or a past
  one, is the same contradiction the overdue wording exists to avoid, arriving through the
  ongoing state instead. This is the resolution where the two requirements meet.

#### Scenario: An ongoing period with nothing to predict from still reads correctly
- **WHEN** the only recorded period is the ongoing one, so no next start can be predicted
- **THEN** the card reports the ongoing period alone, with no predicted date and no
  placeholder standing in for one — the state of someone recording for the first time

#### Scenario: A period that covers today wins over a later-starting one
- **WHEN** a period covering today was recorded alongside a later-starting one that does
  not cover today
- **THEN** today is reported as ongoing, so the overview and the tracker's calendar do not
  disagree about the same day

#### Scenario: A period with no end date counts as ongoing
- **WHEN** a recorded period has no end date and started on or before today
- **THEN** it is treated as ongoing

### Requirement: The overview card opens the menstrual tracker

Tapping the card SHALL open the menstrual tracker, in every state including when there is
no prediction — the state in which the user is most likely to want to go and record
something.

#### Scenario: Tapping the card opens the tracker
- **WHEN** the user taps the card
- **THEN** the menstrual tracker opens, reached through the application's own routing so a
  back control returns to the overview

#### Scenario: The shortcut works with no data
- **WHEN** no period has been recorded yet
- **THEN** the card is still shown and still opens the tracker
