# health-calendar-card Specification

## Purpose
TBD - created by archiving change health-calendar-card. Update Purpose after archive.
## Requirements
### Requirement: The dashboard shows a monthly record calendar with adherence rings

The dashboard SHALL show a health-calendar card for the current month: a calendar marking each day that has any tracker entry, and three adherence rings — the month's logging rate, the month's diet-adherence rate, and the weight-goal achievement rate. The card SHALL load the current month using the user's local date as "today", show a loading state then the content, defer a 401 to the dashboard's re-authentication exit, and on a non-auth failure show an error with a retry when it has no content to show, or keep the content it has and say it could not be refreshed when it does. A ring with no rate SHALL show an empty ring and no percentage.

#### Scenario: The card shows dots for logged days and three rings
- **WHEN** the month summary loads with logged days and rates
- **THEN** the calendar marks each logged day and the three rings show the logging, diet, and weight rates

#### Scenario: A null rate shows no false number
- **WHEN** a rate is null (e.g. no days elapsed, or the weight goal isn't set)
- **THEN** that ring shows an empty ring and no percentage

#### Scenario: A load failure offers a retry
- **WHEN** loading the month summary fails (not a 401) and no month has loaded yet
- **THEN** the card shows an error message and a retry control that reloads it

#### Scenario: A failed refresh keeps the month it already drew
- **WHEN** loading fails (not a 401) after a month has already been drawn
- **THEN** the calendar and its rings stay on screen, reported as not refreshed, with a retry —
  a failed automatic refresh does not remove the largest card on the overview

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

