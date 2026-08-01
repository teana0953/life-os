## ADDED Requirements

### Requirement: Diet calendar jumps to a distant month

The diet day calendar SHALL let the user reach any past month in one step by
tapping its month title to open the month picker, in addition to the existing
previous/next month arrows. Future months SHALL NOT be selectable.

#### Scenario: Jumping back a year in the diet calendar

- **WHEN** the user taps the diet calendar's month title and picks a month a
  year earlier
- **THEN** the calendar shows that month's days

#### Scenario: Future months are not offered

- **WHEN** the picker is opened from the diet calendar
- **THEN** months after the current one are disabled
