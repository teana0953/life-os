## ADDED Requirements

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
