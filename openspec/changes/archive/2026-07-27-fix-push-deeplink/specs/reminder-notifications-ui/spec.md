## ADDED Requirements

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
