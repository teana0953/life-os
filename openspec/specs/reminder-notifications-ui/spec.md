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

### Requirement: Tapping a care notification opens 今日照護

Tapping a care push notification SHALL open the 今日照護 screen, whether the app was closed
or already running, and SHALL NOT depend on the notification's URL surviving the platform's
app-launch path. The destination SHALL be handed over through same-origin storage written
when the notification is tapped and consumed by the app once it is ready to navigate.

An existing app window SHALL be brought to the foreground **without being navigated by the
service worker**, so the page the user was on remains in the history stack.

#### Scenario: Cold start reaches 今日照護
- **WHEN** the app is not running and the user taps a care notification
- **THEN** the app starts and 今日照護 is shown

#### Scenario: A backgrounded app reaches 今日照護 without losing its current page
- **WHEN** the app is running in the background on some other screen and the user taps a
  care notification
- **THEN** the app is brought to the foreground and 今日照護 is shown, with the screen the
  user was on still beneath it in the history stack

#### Scenario: A foregrounded app reaches 今日照護
- **WHEN** the app is already in the foreground showing some other screen and the user taps
  a care notification displayed over it
- **THEN** 今日照護 is shown, with the screen the user was on still beneath it in the history
  stack — the app does not sit unchanged waiting for a later foreground transition

#### Scenario: Signing in first still reaches the destination
- **WHEN** the user taps a care notification while signed out, and then signs in
- **THEN** 今日照護 is shown after sign-in completes

### Requirement: 今日照護 opened from a notification can be navigated back from

A 今日照護 screen opened from a notification SHALL be stacked on top of the app's existing
screen rather than replacing it, so it presents a back affordance and returns the user to
where they were — matching how 今日照護 behaves when opened from the overview card.

#### Scenario: A back arrow is present
- **WHEN** 今日照護 has been opened by tapping a care notification
- **THEN** the screen shows a back affordance, and using it returns to the screen beneath —
  the home screen on a cold start, or the screen the user was on when already running

#### Scenario: The transition screens are never left underneath
- **WHEN** a destination is pending while the app is on a splash, auth-error, or sign-in
  screen
- **THEN** it is left unconsumed and the navigation happens once the app has settled on a
  real screen, so 今日照護 is never stacked on top of a transition screen

### Requirement: A stale or duplicate hand-over never hijacks navigation

The handed-over destination SHALL be discarded rather than acted on when it is no longer
relevant, and SHALL NOT stack duplicate screens. When the app is already showing the
destination, the hand-over SHALL refresh what that screen shows instead of stacking a
second copy. It SHALL be cleared when read, whether or not it is acted on, so it is
consumed exactly once.

#### Scenario: An expired hand-over is ignored
- **WHEN** the app opens more than five minutes after a notification tap wrote a destination
  (for example the user opens the app on their own the next day)
- **THEN** no notification-driven navigation happens and the app opens where it normally
  would

#### Scenario: Already on the destination does not stack a second copy
- **WHEN** a destination is consumed while the app is already showing 今日照護
- **THEN** no additional 今日照護 screen is pushed, and the 今日照護 already on screen
  reloads its checklist rather than staying as it was when the screen opened — so a
  reminder tapped from 今日照護 itself, including one tapped the next morning, shows
  today's slots and records against today

#### Scenario: A consumed hand-over does not repeat
- **WHEN** a destination has been consumed once and the app is later brought back to the
  foreground
- **THEN** it does not navigate again

#### Scenario: A failed hand-over is silent
- **WHEN** the destination cannot be read
- **THEN** the app opens normally with no error message, leaving the in-app entries to 今日照護
  as the way in

