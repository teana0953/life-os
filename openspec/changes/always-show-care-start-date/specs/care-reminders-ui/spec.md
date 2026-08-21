## MODIFIED Requirements

### Requirement: List care reminders grouped by category with an empty state

The screen SHALL list the user's care reminders grouped by category (medication, rehab,
radiotherapy care, custom), each showing its title, a schedule summary, and — for medication —
its stock; when there are none it SHALL show an empty-state guide, not a blank page. Each
schedule's summary SHALL include its start date regardless of the schedule's every-N-weeks
interval, so a start date the user set in the form is visible in the list they set it from.

#### Scenario: Reminders are listed by category
- **WHEN** the user has care reminders in more than one category
- **THEN** each appears under its category heading with its title and schedule summary

#### Scenario: No reminders shows guidance
- **WHEN** the user has no care reminders
- **THEN** an empty-state guide (with a way to add one) is shown

#### Scenario: The summary shows the start date on a plain daily or weekly schedule
- **WHEN** a listed reminder has a schedule whose every-N-weeks interval is 1
- **THEN** that schedule's summary includes its start date, and still omits the
  every-N-weeks suffix

### Requirement: Create and edit a care reminder, with medication-only fields

The screen SHALL let the user add a reminder via a form (category, title, an optional
instruction note, and one or more schedules — each a time, weekdays, an every-N-weeks interval,
a start date, an optional end date, and a nag interval) and edit an existing one. The start
date SHALL be visible and editable for every schedule regardless of its every-N-weeks interval,
because the backend treats the start date as an activation gate for every schedule (a schedule
never fires before its start date, whatever its interval). Dose and stock fields SHALL appear
only for the medication category. Submission SHALL be blocked until the title is non-empty and
at least one schedule with a time is present.

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

#### Scenario: The start date is offered on a plain daily or weekly schedule
- **WHEN** a schedule's every-N-weeks interval is 1
- **THEN** its start date is shown, above the end-date control, with the same label and
  date-picker affordance a longer-interval schedule gets

#### Scenario: A start date chosen on an interval-1 schedule is what gets saved
- **WHEN** the user picks a future start date on a schedule whose every-N-weeks interval is 1
  and submits the form
- **THEN** the schedule is saved with the picked date as its start date, not with today's date

#### Scenario: A saved reminder appears in the list
- **WHEN** the user submits a valid new reminder
- **THEN** it appears under its category in the list afterward
