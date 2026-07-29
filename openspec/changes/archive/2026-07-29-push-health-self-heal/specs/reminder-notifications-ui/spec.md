## ADDED Requirements

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
