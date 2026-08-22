## ADDED Requirements

### Requirement: A notification tap leaves the app usable, not just on the right screen

Landing on the right screen is not the same as being able to use it. When a notification tap
brings an already-running app to the foreground, the app SHALL be **interactive**: what is on
screen SHALL respond to the user's touch without the user having to reload the page, switch to
another app and back, or wait.

This SHALL hold whether or not a destination was pending, whether or not the app navigated,
and whether or not the browser reported that the app came to the foreground. In particular,
the app SHALL NOT depend on being told it was resumed in order to become responsive again:
being brought forward without any such report is the case this requirement exists for.

#### Scenario: Foregrounded by a tap with no pending destination

- **WHEN** a notification tap brings the running app to the foreground and there is no pending
  destination to consume
- **THEN** the screen the user is looking at responds to touch immediately, exactly as it did
  before the app was backgrounded

#### Scenario: Foregrounded without a foreground lifecycle report

- **WHEN** the app is brought forward and the browser delivers no foreground lifecycle
  transition — only a visibility or focus signal, or only a worker message
- **THEN** the app still becomes responsive to touch, rather than staying on a painted but
  dead screen until the user backgrounds it and returns

#### Scenario: The user must never need the background-and-return workaround

- **WHEN** the app is painted and appears normal after a notification tap
- **THEN** touch works, and switching to another app and returning is never required to
  restore it

### Requirement: A newly deployed version never makes a running window unusable

A new version being available is background news. A window that has not reloaded since a
deploy SHALL keep working normally until the user chooses to load the new version, and
noticing a new version SHALL NOT be something the app does as part of bringing itself to the
foreground.

#### Scenario: A deploy lands while the app is open and backgrounded

- **WHEN** a new version is deployed while the app is open but backgrounded, and the user then
  taps a notification to return to it
- **THEN** the app comes forward responsive and on the correct screen, running the version it
  already had, and the user can keep using it

#### Scenario: Looking for a new version does not delay the user

- **WHEN** the app is brought to the foreground
- **THEN** whatever the app does to notice a newly deployed version does not run as part of
  that transition, and never delays or displaces the app becoming interactive

#### Scenario: The update is still offered

- **WHEN** a new version has been deployed and is ready
- **THEN** the user is still offered it in the ordinary way, and loading it remains the user's
  decision

### Requirement: Arriving at a handed-over destination never blocks the app

Getting to a handed-over destination can require dismissing whatever the user had opened on
top of it. That unwinding SHALL always terminate: the app SHALL NOT be left running an
unbounded amount of navigation work, and SHALL remain able to draw and respond to input
throughout. A screen that declines to be dismissed SHALL cost the user at most an unchanged
screen — never a frozen app.

#### Scenario: A screen that refuses to be dismissed does not freeze the app

- **WHEN** a notification hands over a destination that sits beneath a screen which refuses to
  be dismissed — for example one guarding an in-flight submission
- **THEN** the app stops unwinding, stays responsive, and leaves the user on a usable screen,
  rather than becoming unresponsive

#### Scenario: Unwinding to the destination still works in the ordinary case

- **WHEN** a notification hands over a destination that is already in the stack with ordinary
  dismissible screens above it
- **THEN** those screens are dismissed and the user arrives at the destination, and the app
  remains responsive
