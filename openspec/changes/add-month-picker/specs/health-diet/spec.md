## ADDED Requirements

### Requirement: Diet calendar jumps to a distant month

The diet day calendar SHALL let the user reach any month in one step by
tapping its month title to open the month picker, in addition to the existing
previous/next month arrows. The picker SHALL offer the same range the arrows
already allow, so a month reachable by stepping is never unreachable by
jumping. Jumping SHALL refresh the logged-day markers for the month arrived
at, exactly as stepping does.

#### Scenario: Jumping back a year in the diet calendar

- **WHEN** the user taps the diet calendar's month title and picks a month a
  year earlier
- **THEN** the calendar shows that month's days
- **AND** that month's logged-day markers are fetched, not the previous
  month's left in place
