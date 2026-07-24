# reminder-notifications-ui Specification

## Purpose
TBD - created by archiving change add-web-push-ui. Update Purpose after archive.
## Requirements
### Requirement: Reach the reminder settings from the health module

The health module's 更多 (More) tab SHALL present a reminders/notifications entry
that navigates to the reminder settings screen.

#### Scenario: The More tab opens the reminder settings screen
- **WHEN** the user taps the reminders entry in the 更多 tab
- **THEN** the reminder settings screen opens

### Requirement: Enable notifications from the settings screen

The reminder settings screen SHALL let a user on a supported, install-ready
environment enable notifications, which requests permission and, on grant, subscribes
the device to Web Push and registers the subscription with the backend.

#### Scenario: Enabling subscribes and reaches the enabled state
- **WHEN** the user is in the `idle` state and taps "Enable notifications" and grants permission
- **THEN** the device is subscribed, the subscription is sent to the backend, and the screen shows the enabled state

#### Scenario: Enabling shows progress and is not re-triggerable
- **WHEN** enabling is in progress
- **THEN** the enable control shows a loading state and cannot be triggered again

#### Scenario: Denying permission shows a recoverable message
- **WHEN** the user taps "Enable notifications" and denies the browser permission
- **THEN** the screen shows a message explaining notifications are blocked and how to re-enable them, and does not show the enabled state

### Requirement: Guide the user when the environment cannot subscribe

The screen SHALL detect and clearly handle environments where Web Push cannot be
enabled, instead of showing a dead-end prompt.

#### Scenario: iOS not installed shows an add-to-home-screen hint
- **WHEN** the user is on iOS Safari and the app is not installed to the Home Screen
- **THEN** the screen shows guidance to add the app to the Home Screen first, and does not present the enable action as usable

#### Scenario: Unsupported browser is explained
- **WHEN** the browser does not support service workers or Web Push
- **THEN** the screen explains notifications are not supported on this device, rather than failing silently

### Requirement: Send a test push once enabled

Once notifications are enabled, the screen SHALL offer a "Send test push" action that
triggers a backend test push and reports the outcome.

#### Scenario: Test push reports its result
- **WHEN** the user is in the enabled state and taps "Send test push"
- **THEN** the app requests a test push from the backend and shows the sent/failed result

#### Scenario: The test action is available only when enabled
- **WHEN** notifications are not yet enabled
- **THEN** the "Send test push" action is not available

### Requirement: Errors are localized, distinguishable, and recoverable

Failures SHALL surface localized messages that distinguish a lifeos re-auth
requirement from a general request failure, each telling the user what to do next —
not a single generic error, and never an app crash.

#### Scenario: A lifeos re-auth requirement is surfaced distinctly
- **WHEN** a push request returns lifeos 401
- **THEN** the screen surfaces a re-authentication prompt distinct from a generic failure

#### Scenario: A request failure is actionable
- **WHEN** enabling or the test push fails for a non-auth reason
- **THEN** the screen shows a localized, actionable error with the ability to retry

