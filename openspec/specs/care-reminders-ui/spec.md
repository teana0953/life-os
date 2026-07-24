# care-reminders-ui Specification

## Purpose
TBD - created by archiving change add-care-reminders-ui. Update Purpose after archive.
## Requirements
### Requirement: Reach care reminders from the health module

The health 更多 (More) tab SHALL present a care-reminders entry that navigates to the care
reminders screen.

#### Scenario: The More tab opens the care reminders screen
- **WHEN** the user taps the care/reminders entry in the 更多 tab
- **THEN** the care reminders screen opens

### Requirement: List care reminders grouped by category with an empty state

The screen SHALL list the user's care reminders grouped by category (medication, rehab,
radiotherapy care, custom), each showing its title, a schedule summary, and — for medication —
its stock; when there are none it SHALL show an empty-state guide, not a blank page.

#### Scenario: Reminders are listed by category
- **WHEN** the user has care reminders in more than one category
- **THEN** each appears under its category heading with its title and schedule summary

#### Scenario: No reminders shows guidance
- **WHEN** the user has no care reminders
- **THEN** an empty-state guide (with a way to add one) is shown

### Requirement: Create and edit a care reminder, with medication-only fields

The screen SHALL let the user add a reminder via a form (category, title, an optional
instruction note, and one or more schedules — each a time, weekdays, an every-N-weeks interval,
a start date, an optional end date, and a nag interval) and edit an existing one. Dose and stock
fields SHALL appear only for the medication category. Submission SHALL be blocked until the title
is non-empty and at least one schedule with a time is present.

#### Scenario: Medication fields appear only for medication
- **WHEN** the form's category is medication
- **THEN** dose and stock fields are shown
- **WHEN** the category is rehab, radiotherapy care, or custom
- **THEN** dose and stock fields are hidden and only the note is used

#### Scenario: The form gates submission until valid
- **WHEN** the title is empty or no schedule with a time is present
- **THEN** submit is blocked
- **WHEN** a title and at least one schedule with a time are provided
- **THEN** submit creates (or updates) the reminder

#### Scenario: Empty weekdays means every day
- **WHEN** a schedule has no weekday selected
- **THEN** it is shown as "every day" and saved with an empty weekday set

#### Scenario: A saved reminder appears in the list
- **WHEN** the user submits a valid new reminder
- **THEN** it appears under its category in the list afterward

### Requirement: Delete a care reminder

The screen SHALL let the user delete a reminder with confirmation.

#### Scenario: Delete asks for confirmation
- **WHEN** the user deletes a reminder
- **THEN** a confirmation is required, and on confirm the reminder is removed from the list

### Requirement: Errors are localized, distinguishable, and recoverable

Failures SHALL surface localized messages distinguishing a lifeos re-auth requirement from a
general request failure, telling the user what to do next — never a crash, never losing the list.

#### Scenario: A re-auth requirement is surfaced distinctly
- **WHEN** a care request returns lifeos 401
- **THEN** the screen surfaces a re-authentication exit distinct from a generic failure

#### Scenario: A request failure is actionable
- **WHEN** loading or a mutation fails for a non-auth reason
- **THEN** a localized, actionable error is shown and the existing list is not lost

