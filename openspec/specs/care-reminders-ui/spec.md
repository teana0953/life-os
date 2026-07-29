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

### Requirement: Warn when reminders won't be delivered because notifications are off

The care-reminder management screen SHALL present the shared push-health warning when reminders
cannot be delivered, using the same component and the same state as the health overview and
今日照護 — it is no longer the only screen that warns, and it no longer decides on its own
whether push is on. Unlike those two screens it SHALL warn regardless of whether the user has
care slots today, since reaching this screen already expresses intent to use reminders.

The screen SHALL distinguish "permission was turned off" from "permission has never been
requested" in its message, and SHALL NOT warn when the environment cannot support Web Push
(iOS awaiting Home Screen install, or a browser without push support): the reminder settings
screen explains that case, and "notifications are off" would be false there.

#### Scenario: Notifications off shows a prompt
- **WHEN** the care-reminder management screen is shown and notification permission was turned off
- **THEN** a prompt is shown stating reminders won't be delivered, with an action to enable notifications

#### Scenario: Never-requested permission shows the not-yet-enabled prompt
- **WHEN** the care-reminder management screen is shown and notification permission has never been requested
- **THEN** a prompt is shown stating notifications are not enabled yet, with an action to enable notifications

#### Scenario: The prompt opens reminder settings
- **WHEN** the user taps the enable action on that prompt
- **THEN** the reminder (push) settings screen opens

#### Scenario: Notifications on shows no prompt
- **WHEN** push health is fine
- **THEN** no such prompt is shown

#### Scenario: An unsupported environment shows no prompt
- **WHEN** the care-reminder management screen is shown in an environment that cannot support Web Push
- **THEN** no such prompt is shown

#### Scenario: The prompt is shown even with no care slots today
- **WHEN** the care-reminder management screen is shown, push cannot be delivered, and the user has no care slots today
- **THEN** the prompt is still shown

#### Scenario: The prompt does not disrupt the reminders list
- **WHEN** the prompt is shown
- **THEN** the care reminders list, its add action, and editing remain fully usable below it

