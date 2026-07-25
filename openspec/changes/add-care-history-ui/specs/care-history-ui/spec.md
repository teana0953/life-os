## ADDED Requirements

### Requirement: A care history screen with list and chart modes

The app SHALL provide a care history screen, reachable from the care management and Today care
screens, that presents a selectable period (e.g. 7 / 30 / 90 days) in two switchable modes: a
**list** of the period's care slots grouped by day, and a **chart** summarizing adherence. The
screen SHALL handle empty, loading, and re-auth states without crashing.

#### Scenario: Reaching the history screen
- **WHEN** the user taps the history entry on the care management or Today care screen
- **THEN** the care history screen opens

#### Scenario: List mode groups slots by day
- **WHEN** the screen is in list mode with loaded data
- **THEN** each day in the period is a group listing that day's care slots with their time, title, and status

#### Scenario: Chart mode summarizes adherence
- **WHEN** the user switches to chart mode
- **THEN** a headline summary (adherence rate, days with a dose taken, missed count) and a per-day heatmap are shown

#### Scenario: The heatmap colors each day by state
- **WHEN** chart mode is shown
- **THEN** each day is a cell colored full (all slots done), partial (some done), missed (scheduled but none done), or no-schedule (nothing scheduled)

#### Scenario: Switching the period reloads
- **WHEN** the user changes the period
- **THEN** the screen reloads care records for the corresponding date range in the current mode

#### Scenario: Empty, loading, and auth states
- **WHEN** the period has no care records, or data is loading, or the request needs re-auth
- **THEN** the screen shows an empty guide, a loading state, or a re-auth exit respectively

### Requirement: Edit a past care record from the history list

The care history screen SHALL let the user change a listed slot's outcome to done or skipped. The
change SHALL be sent to the backend and reflected in the list without dropping the screen to a
full-page loading state; a failure SHALL keep the list and surface a localized error.

#### Scenario: Editing a slot updates it
- **WHEN** the user picks a new outcome (done or skipped) for a listed slot
- **THEN** the record is updated and the list reflects the new status

#### Scenario: Editing does not blank the screen
- **WHEN** an edit is in flight
- **THEN** the list stays visible (no full-page loading state)

#### Scenario: A failed edit is surfaced and keeps the list
- **WHEN** an edit fails for a non-auth reason
- **THEN** a localized error is surfaced and the existing list is kept

#### Scenario: A missed record can be corrected
- **WHEN** the user edits a slot recorded as missed
- **THEN** it can be set to done or skipped
