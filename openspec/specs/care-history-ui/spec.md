# care-history-ui Specification

## Purpose
TBD - created by archiving change add-care-history-ui. Update Purpose after archive.
## Requirements
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
- **THEN** each day that has care slots is a group listing that day's slots with their time, title, and status

#### Scenario: List mode omits days with nothing scheduled
- **WHEN** the period contains days with no scheduled care
- **THEN** those days are not rendered as groups in list mode, while the chart still shows a cell for them

#### Scenario: Chart mode summarizes adherence
- **WHEN** the user switches to chart mode
- **THEN** a headline summary (adherence rate, days with a dose taken, missed count) and a per-day heatmap are shown

#### Scenario: The heatmap colors each day by state
- **WHEN** chart mode is shown
- **THEN** each day is a cell colored full (all slots done), partial (some done), missed (scheduled but none done), or no-schedule (nothing scheduled)

#### Scenario: Switching the period reloads without blanking
- **WHEN** the user changes the period
- **THEN** the screen reloads care records for the corresponding date range (ending today, inclusive) in the current mode, keeping the current content visible with a progress indicator rather than dropping to a full-page spinner

#### Scenario: Empty, loading, and auth states
- **WHEN** every day in the period has no scheduled care, or the first load is in flight, or the request needs re-auth
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

#### Scenario: A reload failing after a successful edit still keeps the list
- **WHEN** the edit itself succeeds but the follow-up refresh fails for a non-auth reason
- **THEN** the list is kept (the edit already happened) with a localized error, rather than dropping to an error state

#### Scenario: A missed record can be corrected
- **WHEN** the user edits a slot recorded as missed
- **THEN** it can be set to done or skipped (missed is derived, never chosen)

