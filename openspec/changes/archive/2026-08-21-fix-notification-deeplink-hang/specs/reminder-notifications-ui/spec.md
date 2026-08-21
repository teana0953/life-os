## MODIFIED Requirements

### Requirement: Tapping a care notification opens 今日照護

Tapping a push notification SHALL open the screen **that notification is about**, whether the
app was closed or already running, and SHALL NOT depend on the notification's URL surviving the
platform's app-launch path. The destination SHALL be decided when the notification is shown,
carried on the notification itself, handed over through same-origin storage when the
notification is tapped, and consumed by the app once it is ready to navigate.

A notification that carries no destination of its own SHALL NOT be treated as if it were a care
reminder. Tapping it SHALL bring the app to the foreground and leave it where it normally
opens, rather than navigating to a screen unrelated to what the notification said.

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

#### Scenario: A notification that is not a care reminder does not land on 今日照護
- **WHEN** the user taps a notification that is not a care reminder (for example a budget
  alert or a test push) and that carries no destination of its own
- **THEN** the app comes to the foreground and stays where it normally opens — 今日照護 is
  **not** opened, because it is not what that notification was about

#### Scenario: Two notifications about different things go to different places
- **WHEN** two notifications carrying different destinations are shown, and the user taps
  the second one
- **THEN** the app opens the destination that belongs to the notification the user tapped,
  not the one belonging to the other notification

### Requirement: A stale or duplicate hand-over never hijacks navigation

The handed-over destination SHALL be discarded rather than acted on when it is no longer
relevant, and SHALL NOT stack duplicate screens. When the app is already showing the
destination, the hand-over SHALL refresh what that screen shows instead of stacking a
second copy. Repeated hand-overs for the same destination SHALL NOT grow the history stack:
after any number of notification taps, one back returns the user to the screen they were on
before the first tap. It SHALL be cleared when read, whether or not it is acted on, so it is
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

#### Scenario: Many taps do not bury the screen the user was on
- **WHEN** the user taps several notifications in a row while the app is running, including
  ones whose destinations differ from each other
- **THEN** returning to the screen they were on before the first tap takes a single back —
  the notification destinations do not accumulate as a stack of screens to walk out of

#### Scenario: A consumed hand-over does not repeat
- **WHEN** a destination has been consumed once and the app is later brought back to the
  foreground
- **THEN** it does not navigate again

#### Scenario: A failed hand-over is silent
- **WHEN** the destination cannot be read
- **THEN** the app opens normally with no error message, leaving the in-app entries to 今日照護
  as the way in

## ADDED Requirements

### Requirement: An unrecognized destination never becomes a dead end

The service worker that writes a hand-over deliberately outlives app updates, so the version
that writes a destination can differ from the version that reads it. The app SHALL therefore
treat a handed-over destination it does not recognize as **no hand-over at all**: it SHALL
open where it normally would, with the user's ordinary screen and its ordinary controls, and
SHALL NOT replace what is on screen with an error or not-found page.

#### Scenario: A destination this app version does not have is ignored
- **WHEN** the handed-over destination does not correspond to any screen in the running app
  version
- **THEN** the app opens normally on its usual screen, no not-found page is shown, and no
  error is surfaced to the user

#### Scenario: A malformed destination is ignored
- **WHEN** the handed-over destination is empty, or is not in the form the app navigates by
- **THEN** the app opens normally on its usual screen and nothing is navigated

### Requirement: A notification tap is never swallowed by an unfinished earlier attempt

Reading and acting on a hand-over involves work that can fail to finish — same-origin storage
that never answers, a request that never returns. A single unfinished attempt SHALL NOT
disable notification navigation for the rest of the session: a later notification tap SHALL
always be able to start a fresh attempt, and any wait that blocks it SHALL have a bounded end.

#### Scenario: A hand-over read that never answers does not disable later taps
- **WHEN** an attempt to read a pending destination never completes, and the user then taps
  another notification
- **THEN** the later tap is acted on — it is not silently dropped because the earlier attempt
  is still considered in flight

#### Scenario: Tapping again always sends a fresh request
- **WHEN** the user taps a notification for a destination the app is already showing, while an
  earlier load for that screen has not returned
- **THEN** a new attempt to refresh that screen is made rather than being discarded, so
  tapping again is a way out of a stuck screen rather than a no-op

### Requirement: A foregrounded hand-over does not depend on a single browser signal

Bringing an already-running app to the foreground does not reliably produce either a
foreground lifecycle transition or a service-worker message on the web. Consuming a pending
destination SHALL NOT depend on any single one of those signals: whenever the app becomes
visible to the user, a pending destination SHALL be consumed.

#### Scenario: The app is brought to the foreground with no message and no lifecycle change
- **WHEN** a notification tap brings an already-running app to the foreground without
  delivering a service-worker message and without a foreground lifecycle transition
- **THEN** the pending destination is still consumed and the app navigates to it, rather than
  leaving the user on whatever page happened to be open
