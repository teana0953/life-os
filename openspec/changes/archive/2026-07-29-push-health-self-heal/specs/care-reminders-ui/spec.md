## MODIFIED Requirements

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
