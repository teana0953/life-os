## ADDED Requirements

### Requirement: Warn when reminders won't be delivered because notifications are off

The care-reminder management screen SHALL detect whether push notifications are enabled and,
when they are not, present a prompt explaining that reminders will not be delivered and offering
a way to turn notifications on. "Enabled" SHALL be treated as true when the app enabled push in
this session OR the browser notification permission is already granted (so a user who enabled
push in a previous session is not falsely warned).

#### Scenario: Notifications off shows a prompt
- **WHEN** the care-reminder management screen is shown and push notifications are not enabled
- **THEN** a prompt is shown stating reminders won't be delivered, with an action to enable notifications

#### Scenario: The prompt opens reminder settings
- **WHEN** the user taps the enable action on that prompt
- **THEN** the reminder (push) settings screen opens

#### Scenario: Notifications on shows no prompt
- **WHEN** push notifications are enabled (enabled this session or permission already granted)
- **THEN** no such prompt is shown

#### Scenario: The prompt does not disrupt the reminders list
- **WHEN** the prompt is shown
- **THEN** the care reminders list, its add action, and editing remain fully usable below it
