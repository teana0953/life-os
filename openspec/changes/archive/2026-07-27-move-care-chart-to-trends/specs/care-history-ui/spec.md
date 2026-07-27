## ADDED Requirements

### Requirement: A care history screen listing past care records

The app SHALL provide a care history screen, reachable from the care management and Today care
screens, that presents a selectable period (e.g. 7 / 30 / 90 days) as a **list** of the period's
care slots grouped by day. The screen SHALL handle empty, loading, and re-auth states without
crashing, and SHALL offer navigation back into the care context (Today care and care management)
so it is not a dead-end leaf.

#### Scenario: Reaching the history screen
- **WHEN** the user taps the history entry on the care management or Today care screen
- **THEN** the care history screen opens

#### Scenario: The list groups slots by day
- **WHEN** the screen has loaded data
- **THEN** each day that has care slots is a group listing that day's slots with their time, title, and status

#### Scenario: Days with nothing scheduled are omitted
- **WHEN** the period contains days with no scheduled care
- **THEN** those days are not rendered as groups

#### Scenario: The screen has no chart mode
- **WHEN** the care history screen is shown
- **THEN** no list/chart mode switch is offered — adherence visualization lives on the health trends tab

#### Scenario: Leaving the history screen for the care context
- **WHEN** the user opens the screen's overflow menu
- **THEN** entries to the Today care screen and the care management screen are offered

#### Scenario: Switching the period reloads without blanking
- **WHEN** the user changes the period
- **THEN** the screen reloads care records for the corresponding date range (ending today, inclusive), keeping the current content visible with a progress indicator rather than dropping to a full-page spinner

#### Scenario: Empty, loading, and auth states
- **WHEN** every day in the period has no scheduled care, or the first load is in flight, or the request needs re-auth
- **THEN** the screen shows an empty guide, a loading state, or a re-auth exit respectively

#### Scenario: The empty state offers a longer period
- **WHEN** the period is empty and a longer period is available
- **THEN** the empty state offers widening the period, which reloads at the next longer period rather than leaving the user with no action

#### Scenario: The longest period's empty state offers no widening
- **WHEN** the period is empty and already the longest available
- **THEN** no widen action is offered

## REMOVED Requirements

### Requirement: A care history screen with list and chart modes

**Reason**: Split in two. The list half is restated as "A care history screen listing past care
records" (above); the chart half moved to the health trends tab as the new `care-adherence-trend`
capability, so that "reviewing" lives in one place and the history screen is solely for browsing
and correcting individual records.

**Migration**: The heatmap, its headline summary, and its legend are rendered by the care
adherence card on the trends tab. No data shape or backend contract changed — the card reads the
same `/api/care/range` records the history list does.
