## ADDED Requirements

### Requirement: Menstrual tracker reached via More

The daily-log shell SHALL offer a menstrual tracker via its More overflow menu, and selecting it SHALL show the menstrual screen with an app bar back control. The menstrual screen SHALL NOT be tied to the shell's viewed day — it shows the user's whole period history and cycle statistics regardless of which day the shell is viewing.

#### Scenario: The menstrual tracker is reachable from More
- **WHEN** the user opens the More menu and selects the menstrual tracker
- **THEN** the menstrual screen is shown with a back control that returns to the More menu

### Requirement: Mini-calendar of periods

The menstrual screen SHALL show a month calendar (Sunday-first) that marks the days belonging to each recorded period (from its start date through its end date inclusive; an open period marks from its start through today) and marks the predicted next start date with a distinct marker. The user SHALL be able to move to the previous and next month.

#### Scenario: A recorded period is marked across its range
- **WHEN** a period runs 2026-05-01 to 2026-05-05 and the user views May 2026
- **THEN** each day from the 1st through the 5th is marked as a period day

#### Scenario: The predicted next start is marked
- **WHEN** the overview predicts the next start on 2026-07-24 and the user views July 2026
- **THEN** the 24th carries the predicted-next marker, distinct from a recorded period day

#### Scenario: Month navigation
- **WHEN** the user taps the next-month control
- **THEN** the calendar advances to the following month

### Requirement: Add, edit, and delete a period

The menstrual screen SHALL let the user add a period (a start date and an optional end date), edit an existing period (change its dates, or clear its end date to reopen a completed period), and delete a period. Each action SHALL take effect immediately — persisted to the backend and the overview re-read — rather than being staged behind a save control. An end date earlier than the start date SHALL be prevented.

#### Scenario: Adding a period shows it on the calendar
- **WHEN** the user adds a period starting 2026-06-01 with no end date
- **THEN** the overview is re-read and the 1st of June onward is marked as an open period

#### Scenario: Setting an end date
- **WHEN** the user edits an open period to set an end date
- **THEN** the period is now marked through that end date

#### Scenario: Reopening a completed period
- **WHEN** the user clears the end date of a completed period
- **THEN** the period becomes open again (marked from its start through today)

#### Scenario: Deleting a period
- **WHEN** the user deletes a period
- **THEN** it is removed from the calendar after the overview is re-read

### Requirement: Cycle statistics

The menstrual screen SHALL show the derived cycle statistics from the overview — the average cycle length, the average period length, and the predicted next start — and the most recent period. Each statistic SHALL display a placeholder (e.g. "—") when it is null (not enough data).

#### Scenario: Statistics are shown when available
- **WHEN** the overview reports an average cycle of 28 days and a predicted next start of 2026-07-24
- **THEN** the screen shows those values

#### Scenario: Missing statistics show a placeholder
- **WHEN** the overview reports null statistics (not enough data)
- **THEN** the screen shows a placeholder rather than a number

### Requirement: Menstrual API errors are surfaced without crashing

The menstrual screen SHALL surface a load or save failure as an error state rather than crashing, and an authentication failure (401) SHALL surface a re-authentication exit consistent with the other trackers.

#### Scenario: A load failure shows an error state
- **WHEN** loading the overview fails
- **THEN** the screen shows an error state rather than crashing
