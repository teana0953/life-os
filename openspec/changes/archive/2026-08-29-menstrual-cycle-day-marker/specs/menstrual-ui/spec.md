## MODIFIED Requirements

### Requirement: Mini-calendar of periods

The menstrual screen SHALL show a month calendar (Sunday-first) that marks the days belonging to each recorded period (from its start date through its end date inclusive; an open period marks from its start through today) and marks the predicted next start date with a distinct marker. The user SHALL be able to move to the previous and next month.

Each marked period day SHALL also show which day of that period it is — the period's start date is day 1 — so the length of a period can be read off the calendar without counting cells. The number SHALL be shown together with, not instead of, the day-of-month number. Days that belong to no period — including the predicted next start — SHALL NOT carry a day-of-period number. Where more than one recorded period covers the same day, the number SHALL come from the period with the latest start date among those covering it, matching how the overview card resolves the same overlap, so the two never disagree about a day. The count SHALL NOT be capped: an open period left unclosed showing a large number is the signal that it was never closed. The day cell's accessible label for a period day SHALL name the day of the period as well as the date.

#### Scenario: A recorded period is marked across its range
- **WHEN** a period runs 2026-05-01 to 2026-05-05 and the user views May 2026
- **THEN** each day from the 1st through the 5th is marked as a period day

#### Scenario: A period day shows which day of the period it is
- **WHEN** a period runs 2026-05-01 to 2026-05-05 and the user views May 2026
- **THEN** the 1st shows day 1, the 3rd shows day 3 and the 5th shows day 5, each alongside its day-of-month number

#### Scenario: An open period counts through today
- **WHEN** a period started 2026-05-01 with no end date and today is 2026-05-04
- **THEN** the 4th shows day 4, and no day after today carries a number

#### Scenario: A day belonging to no period carries no number
- **WHEN** the user views a month containing days outside every recorded period, including the predicted next start
- **THEN** those days show only their day-of-month number

#### Scenario: Overlapping periods resolve to the later start
- **WHEN** 2026-05-03 is covered both by a period starting 2026-05-01 and by one starting 2026-05-03
- **THEN** the 3rd shows day 1, from the later-starting period, and not day 3

#### Scenario: A long-unclosed period is not capped
- **WHEN** a period started 40 days ago and was never given an end date
- **THEN** today shows day 41 rather than a truncated or capped number

#### Scenario: A period day is announced with its day of the period
- **WHEN** a screen reader focuses a day that is the 3rd day of a recorded period
- **THEN** the announcement names the date and that it is day 3 of the period

#### Scenario: The predicted next start is marked
- **WHEN** the overview predicts the next start on 2026-07-24 and the user views July 2026
- **THEN** the 24th carries the predicted-next marker, distinct from a recorded period day

#### Scenario: Month navigation
- **WHEN** the user taps the next-month control
- **THEN** the calendar advances to the following month
