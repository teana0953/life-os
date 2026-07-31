## ADDED Requirements

### Requirement: Month grid helper

The system SHALL provide a `monthWeeks(DateTime month)` helper returning the
month's day numbers laid out as whole weeks, Sunday first, padded with nulls
before the first day and after the last so every week has seven entries.

#### Scenario: Month starting on Sunday needs no leading padding

- **WHEN** the month's first day falls on a Sunday
- **THEN** the first week starts with day 1 and has no leading nulls

#### Scenario: February in a leap year

- **WHEN** the month is February of a leap year
- **THEN** the grid contains days 1 through 29, and every week has exactly
  seven entries with only nulls outside that range

### Requirement: Shared presentational widgets

The system SHALL provide reusable widgets whose identifying keys, copy, and
spacing are supplied by the caller, so that adopting them changes no
existing screen's behavior or test keys: a date field (label, formatted
value or placeholder, tap target that may be disabled), a card error state
with a retry action (optional header, configurable spacing), a card loading
state, and a tracker busy bar.

#### Scenario: Caller-supplied keys are used

- **WHEN** a widget is given its identifying keys
- **THEN** those exact keys appear in the widget tree, so screens keep the
  keys they had before adopting the shared widget

#### Scenario: Retry action fires

- **WHEN** the retry control of the card error state is tapped
- **THEN** the caller's retry callback runs

#### Scenario: Disabled date field

- **WHEN** a date field is given a null tap callback
- **THEN** its control is disabled

#### Scenario: Busy bar reflects state

- **WHEN** the tracker busy bar is told it is busy
- **THEN** a progress indicator carrying the caller's key is shown; when not
  busy, no indicator is shown
