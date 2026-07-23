# health-calendar-card Specification

## Purpose
TBD - created by archiving change health-calendar-card. Update Purpose after archive.
## Requirements
### Requirement: The dashboard shows a monthly record calendar with adherence rings

The dashboard SHALL show a health-calendar card for the current month: a calendar marking each day that has any tracker entry, and three adherence rings — the month's logging rate, the month's diet-adherence rate, and the weight-goal achievement rate. The card SHALL load the current month using the user's local date as "today", show a loading state then the content, show an error state with a retry on a non-auth failure, and defer a 401 to the dashboard's re-authentication exit. A ring with no rate SHALL show an empty ring and no percentage.

#### Scenario: The card shows dots for logged days and three rings
- **WHEN** the month summary loads with logged days and rates
- **THEN** the calendar marks each logged day and the three rings show the logging, diet, and weight rates

#### Scenario: A null rate shows no false number
- **WHEN** a rate is null (e.g. no days elapsed, or the weight goal isn't set)
- **THEN** that ring shows an empty ring and no percentage

#### Scenario: A load failure offers a retry
- **WHEN** loading the month summary fails (not a 401)
- **THEN** the card shows an error message and a retry control that reloads it

