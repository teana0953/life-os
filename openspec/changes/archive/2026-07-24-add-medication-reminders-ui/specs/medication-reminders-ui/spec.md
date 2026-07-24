## ADDED Requirements

### Requirement: Reach medication reminders from the health module

The health 更多 (More) tab SHALL present a medication-reminders entry that navigates to
the medication reminders screen.

#### Scenario: The More tab opens the medication reminders screen
- **WHEN** the user taps the medication-reminders entry in the 更多 tab
- **THEN** the medication reminders screen opens

### Requirement: List medication reminders with an empty state

The screen SHALL list the user's medication reminders (label, times, weekdays, enabled
state); when there are none it SHALL show an empty-state guide rather than a blank page.

#### Scenario: Existing reminders are listed
- **WHEN** the user has medication reminders
- **THEN** each is shown with its label, times, and weekdays

#### Scenario: No reminders shows guidance
- **WHEN** the user has no medication reminders
- **THEN** an empty-state guide (with a way to add one) is shown, not a blank page

### Requirement: Create and edit a medication reminder

The screen SHALL let the user add a reminder via a form (label, one or more times,
one or more weekdays, an every-N-weeks interval, an anchor date, enabled) and edit an
existing one; the form SHALL block submission until the label is non-empty and at least
one time and one weekday are chosen.

#### Scenario: The form gates submission until valid
- **WHEN** the label is empty, or no time, or no weekday is selected
- **THEN** the submit action is disabled (or blocked)
- **WHEN** a label, at least one time, and at least one weekday are provided
- **THEN** submit is enabled and creates (or updates) the reminder

#### Scenario: A saved reminder appears in the list
- **WHEN** the user submits a valid new reminder
- **THEN** it appears in the list afterward

### Requirement: Enable/disable and delete

The screen SHALL let the user toggle a reminder's enabled state and delete a reminder
(with confirmation).

#### Scenario: Toggling enable updates the reminder
- **WHEN** the user flips a reminder's enable switch
- **THEN** the reminder's enabled state is updated

#### Scenario: Delete asks for confirmation
- **WHEN** the user deletes a reminder
- **THEN** a confirmation is required, and on confirm the reminder is removed from the list

### Requirement: Set the timezone reminders use

The screen SHALL show the timezone reminders fire in (default `Asia/Taipei`) and let the
user change it, making clear reminders use this timezone.

#### Scenario: Changing the timezone is saved
- **WHEN** the user sets a valid timezone
- **THEN** it is saved
- **WHEN** the user sets an invalid timezone
- **THEN** a localized error is shown (not a crash)

### Requirement: Errors are localized, distinguishable, recoverable

Failures SHALL surface localized messages distinguishing a lifeos re-auth requirement
from a general request failure, telling the user what to do next — never a crash.

#### Scenario: A re-auth requirement is surfaced distinctly
- **WHEN** a reminders request returns lifeos 401
- **THEN** the screen surfaces a re-authentication exit distinct from a generic failure

#### Scenario: A request failure is actionable
- **WHEN** loading or a mutation fails for a non-auth reason
- **THEN** a localized, actionable error is shown and the existing list is not lost
