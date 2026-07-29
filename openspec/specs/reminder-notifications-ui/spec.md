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

### Requirement: Keep the push subscription in sync without the user's help

The app SHALL re-register its Web Push subscription with the backend when the user's sign-in is
established, when the app returns to the foreground, and at the moment the reminder settings
screen finishes an enable attempt — whatever its outcome, because being denied changes push
health as much as being granted does — whenever the browser notification permission is already
granted. The enable trigger SHALL be edge-triggered: it fires when the reported state changes,
and SHALL NOT fire when the settings screen merely re-reports the state it is already in, so
unrelated activity on that screen (such as sending a test push) does not cause repeated,
suppression-bypassing syncs. This SHALL reuse the existing enable flow (fetch the VAPID key, subscribe, save the
subscription), which is idempotent: an already-subscribed browser returns its existing
subscription and the backend upserts by endpoint. The app SHALL NOT prompt the user, show a
progress indicator, or otherwise surface a successful sync — a drifted subscription is the
program's problem, not the user's.

The sync SHALL be driven by the sign-in state becoming established rather than by app start
alone, because restoring a persisted sign-in is asynchronous and a check at start would find no
user and never run again.

When the permission is NOT granted the app SHALL NOT make any network request for this purpose,
because subscribing cannot succeed without permission.

When the environment cannot support Web Push at all (iOS not installed to the Home Screen, or a
browser without push support) the app SHALL treat push health as not applicable and SHALL NOT
attempt a sync.

While no user is signed in the app SHALL NOT attempt a sync and SHALL leave the previously
resolved push health unchanged, so signing out does not flash a warning.

To avoid a network request on every foreground transition, a sync that succeeded less than an
hour ago SHALL suppress the next sync attempt, leaving the resolved health unchanged.
Suppression SHALL apply ONLY after a successful sync: a previously failed or permission-blocked
state SHALL always re-attempt, because the moment permission is restored is exactly when
re-subscribing matters most. A successful enable reported by the reminder settings screen SHALL
bypass suppression.

Suppression SHALL apply to the sync only. Resolving the environment, the signed-in state, and
the notification permission is local and SHALL still run on every check, so a permission that
was revoked since the last successful sync SHALL still be detected within the suppression
window — otherwise the very failure this capability exists to catch would stay hidden for an
hour.

Only one sync SHALL be in flight at a time.

#### Scenario: Returning to the foreground restores a drifted subscription
- **WHEN** the app returns to the foreground, notification permission is granted, and no sync has succeeded within the last hour
- **THEN** the app re-registers its push subscription with the backend, showing the user nothing

#### Scenario: Sign-in being established triggers the first sync
- **WHEN** the app resolves that a user is signed in, after start
- **THEN** push health is checked

#### Scenario: A denied permission costs no network request
- **WHEN** push health is checked and notification permission is not granted
- **THEN** no subscription request is sent to the backend

#### Scenario: An unsupported environment is not treated as a failure
- **WHEN** push health is checked in an environment that cannot subscribe (iOS awaiting Home Screen install, or no push support)
- **THEN** push health resolves to "not applicable" and no sync is attempted

#### Scenario: Signing out does not raise a warning
- **WHEN** push health is checked while no user is signed in
- **THEN** no sync is attempted and the previously resolved push health is left unchanged

#### Scenario: A recent success suppresses the next check
- **WHEN** a sync succeeded less than an hour ago and push health is checked again
- **THEN** no further subscription request is sent and the resolved health stays unchanged

#### Scenario: A previous failure is never suppressed
- **WHEN** the last sync failed and push health is checked again within the hour
- **THEN** the subscription request is sent again

#### Scenario: A permission revoked inside the suppression window is still caught
- **WHEN** a sync succeeded less than an hour ago, the user then turns notification permission off, and push health is checked again
- **THEN** push health resolves to permission-off and the warning appears, rather than staying on the last successful result

#### Scenario: Enabling from settings bypasses the suppression
- **WHEN** the reminder settings screen transitions into a successful enable, less than an hour after a successful sync
- **THEN** the subscription request is sent anyway

#### Scenario: An already-enabled settings screen does not re-sync
- **WHEN** the reminder settings screen reports its state again while already enabled (for example after sending a test push)
- **THEN** no additional subscription request is sent

### Requirement: Surface undeliverable push where the user actually looks

When reminders cannot be delivered, the app SHALL present a warning on the health overview
(above the today-care summary), on 今日照護 above the care-slot list and below the date header,
and on the care-reminder
management screen — the screens a reminder user actually visits — rather than only on
care-reminder management. All three SHALL use the same component and the same push-health
state, so the warning reads identically wherever it appears.

On the health overview and 今日照護 the warning SHALL be shown ONLY when the user has care slots
today. Both screens are shown to every user of the health module, including users who have never
set up a reminder; warning them that notifications are off would be noise about a delivery they
have nothing to receive. The care-reminder management screen carries no such condition, since
reaching it already expresses intent to use reminders.

The warning SHALL distinguish the two states the user can act on:

- **Notification permission was turned off**: the message SHALL state that reminders will not
  appear, and its action SHALL open the reminder (push) settings screen.
- **Notification permission has never been requested**: the message SHALL state that
  notifications are not enabled yet — NOT that they were turned off, which would be false — and
  its action SHALL open the reminder (push) settings screen.

A failed sync SHALL NOT be surfaced to the user at all. The backend subscription is still
registered and push still arrives; only the refresh failed, and the most common cause is simply
being offline. Warning there would tell the user that reminders may not arrive when they will,
and no action the user can take would clear it. The failure is retried silently on the next
check.

The app SHALL also show no warning when push health is fine, when it has not yet been
determined, or when the environment cannot support Web Push — claiming "notifications are off"
on a device that never supported them would be false, and the reminder settings screen already
explains that case.

Because the health is resolved asynchronously, every screen carrying the warning SHALL update
when push health changes, without being reopened.

Messages SHALL describe the consequence to the user (reminders will not appear) rather than the
mechanism (subscription, endpoint, permission API), SHALL always offer a next action, and SHALL
remain complete without color: the warning SHALL NOT depend on its icon or color to convey that
something is wrong.

#### Scenario: Permission off warns on the overview
- **WHEN** the health overview is shown, the user has care slots today, and notification permission was turned off
- **THEN** a warning appears above the today-care summary stating reminders will not appear, with an action that opens reminder settings

#### Scenario: Never-requested permission says so, not "turned off"
- **WHEN** push health is shown and notification permission has never been requested
- **THEN** the warning states notifications are not enabled yet, with an action that opens reminder settings

#### Scenario: Permission off warns on 今日照護
- **WHEN** the 今日照護 screen has loaded care slots for today and notification permission is not granted
- **THEN** the same warning appears above the care-slot list and below the date header, with the same action

#### Scenario: A user with no care slots today is not warned
- **WHEN** the health overview or 今日照護 is shown, notification permission is not granted, and the user has no care slots today
- **THEN** no warning is shown on that screen

#### Scenario: A failed sync is not shown to the user
- **WHEN** the device is offline, or the sync otherwise fails with permission granted
- **THEN** no warning is shown on any screen, and the sync is retried on the next check

#### Scenario: Fixing the permission clears the warning without restarting the app
- **WHEN** the user follows the warning's action to reminder settings and successfully enables notifications
- **THEN** push health is re-checked at once and the warning is gone when the user returns, without restarting the app

#### Scenario: A screen already open reflects a health change
- **WHEN** push health changes while a screen carrying the warning is open
- **THEN** that screen shows or hides the warning accordingly, without being reopened

#### Scenario: Healthy push shows no warning
- **WHEN** push health is fine
- **THEN** no warning is shown on the overview, 今日照護, or care-reminder management

#### Scenario: An undetermined or unsupported state shows no warning
- **WHEN** push health has not yet been determined, or the environment cannot support Web Push
- **THEN** no warning is shown on any of the three screens

