# shared-widgets Specification

## Purpose
TBD - created by archiving change extract-shared-widgets. Update Purpose after archive.
## Requirements
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

#### Scenario: Card error state with a header keeps its layout

- **WHEN** the card error state is given header widgets
- **THEN** the header widgets render above the message and stay interactive,
  the message and retry control remain centered, and the card is not made
  taller by wrapping the header in an extra full-height container

#### Scenario: Disabled date field

- **WHEN** a date field is given a null tap callback
- **THEN** its control is disabled

#### Scenario: Busy bar reflects state

- **WHEN** the tracker busy bar is told it is busy
- **THEN** a progress indicator carrying the caller's key is shown; when not
  busy, no indicator is shown

### Requirement: Month picker dialog

The system SHALL provide a month picker dialog that lets a user jump to any
year and month in one interaction: a year row that steps back and forward
**and whose label opens a list of selectable years**, and a grid of the
twelve months. Controls that open something SHALL carry a visible affordance
so the user can tell they are interactive. It SHALL return the first day of the chosen
month, or nothing when dismissed. When given a first and/or last selectable
month, months outside that range and the year steps that would leave it SHALL
be disabled rather than silently doing nothing. The currently viewed month
SHALL be marked as selected by more than color alone.

#### Scenario: Jumping to a month two years back

- **WHEN** the user opens the picker on 2026-07, steps the year back twice,
  and taps March
- **THEN** the picker closes returning 2024-03-01

#### Scenario: Dismissing changes nothing

- **WHEN** the user dismisses the picker without choosing
- **THEN** nothing is returned and the caller's month is unchanged

#### Scenario: Bounds disable out-of-range choices

- **WHEN** the picker is given a last selectable month of the current month
- **THEN** later months are shown disabled, and stepping the year forward past
  it is disabled

#### Scenario: Picking a year from the list

- **WHEN** the user taps the year label and chooses a year several years away
- **THEN** the month grid shows that year, without stepping through the
  years in between

#### Scenario: Expandable controls look expandable

- **WHEN** a month label that opens the picker, or the picker's year label,
  is shown
- **THEN** it carries a visible dropdown affordance rather than looking like
  plain text

