## ADDED Requirements

### Requirement: Navigate the diet log by day

The diet view SHALL let the user move between days: a header showing the viewed
day with previous/next controls and a calendar entry point. Selecting a different
day SHALL reload that day's entries and its portion target. The user MUST NOT be
able to navigate to a day after today — the "next" control SHALL be disabled when
the viewed day is today, and the calendar SHALL disable future dates.

#### Scenario: Move to the previous day
- **WHEN** the user taps the previous-day control on today's view
- **THEN** the view shows the prior day's entries and that day's target

#### Scenario: Future is blocked
- **WHEN** the viewed day is today
- **THEN** the next-day control is disabled and the calendar does not allow picking a future date

#### Scenario: Calendar marks days with entries
- **WHEN** the user opens the calendar for a month
- **THEN** days on which the user has at least one entry are visually marked, and picking a day shows that day's log

### Requirement: Edit or delete a past food entry

The diet view SHALL let the user tap a logged entry to open an editor prefilled
with the entry's name, four portion values, meal, and eaten-at time. Saving SHALL
update the entry via the backend and refresh the viewed day. The editor SHALL also
offer deleting the entry, which removes it and refreshes the viewed day. A failure
SHALL surface a localized error without losing the user's edits, and an
authentication failure SHALL route to re-authentication.

#### Scenario: Edit an entry's portions
- **WHEN** the user taps an entry, changes its staple portions, and saves
- **THEN** the entry is updated and the day's portion progress reflects the new value

#### Scenario: Delete an entry
- **WHEN** the user opens an entry's editor and confirms delete
- **THEN** the entry is removed and the day's log no longer shows it

#### Scenario: Edit prefilled from the entry
- **WHEN** the user taps an entry named "雞腿便當" with 3 staple and 3 meat portions
- **THEN** the editor opens showing that name, 3 staple, 3 meat, and the entry's meal and time

#### Scenario: Editing without changing the time keeps the entry's day
- **WHEN** the user edits an entry's portions or name but does not change its eaten-at time, then saves
- **THEN** the entry remains on the same day (its eaten-at time is not resent)
