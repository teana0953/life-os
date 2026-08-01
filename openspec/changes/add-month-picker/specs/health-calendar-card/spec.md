## ADDED Requirements

### Requirement: Record calendar shows past months

The dashboard's record calendar SHALL let the user view months other than the
current one: previous/next month arrows plus a tappable month title that opens
the month picker. It SHALL open on the current month. A response for a month
the user has since navigated away from SHALL NOT overwrite the month now on
screen.

#### Scenario: Viewing last month's records

- **WHEN** the user steps the record calendar back one month
- **THEN** that month's logged-day dots and its title are shown

#### Scenario: Jumping to a month a year back

- **WHEN** the user taps the record calendar's month title and picks a month a
  year earlier
- **THEN** that month's records are fetched and shown

#### Scenario: A stale month response is discarded

- **WHEN** the user switches months twice quickly and the first month's
  response arrives after the second's
- **THEN** the calendar shows the second month's records
