## MODIFIED Requirements

### Requirement: A notification tap leaves the app usable, not just on the right screen

Landing on the right screen is not the same as being able to use it. When a notification tap
brings an already-running app to the foreground, the app SHALL be **interactive**: what is on
screen SHALL respond to the user's touch without the user having to reload the page, switch to
another app and back, or wait.

This SHALL hold whether or not a destination was pending, whether or not the app navigated,
and whether or not the browser reported that the app came to the foreground. In particular,
the app SHALL NOT depend on being told it was resumed in order to become responsive again:
being brought forward without any such report is the case this requirement exists for.

Being interactive is a **sustained** state, not a single repaint. On being brought forward the
app SHALL restore itself to the same foreground condition it is in during ordinary use, so
that every subsequent change of state — a tap, a load completing, a timer — is drawn as it
happens. Producing one frame and then going quiet again does NOT satisfy this requirement: to
the user that is indistinguishable from never having repainted at all, because the very next
interaction is dropped.

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

#### Scenario: Foregrounded with no visibility or focus event dispatched at all

- **WHEN** the platform brings the app forward reporting itself as visible and focused, yet
  dispatches neither a visibility-change nor a focus event — the measured behaviour of an
  installed Android PWA returning from a notification tap
- **THEN** the app still returns to its ordinary foreground condition and keeps drawing, so
  the user cannot tell this arrival apart from any other

#### Scenario: The app keeps drawing after the first frame

- **WHEN** the app has been brought forward by a notification tap and the user then interacts
  with it, or content it was loading arrives
- **THEN** each of those changes appears on screen when it happens, for the rest of the
  session, with no further notification tap or app switch needed to unstick it

#### Scenario: The user must never need the background-and-return workaround

- **WHEN** the app is painted and appears normal after a notification tap
- **THEN** touch works, and switching to another app and returning is never required to
  restore it

## ADDED Requirements

### Requirement: Restoring the foreground never depends on there being something to navigate to

The work that makes the app usable again on arrival SHALL run on every signal that the app is
in front of the user, before and independently of any judgement about pending destinations,
freshness, authentication, or which screen is showing. A tap that hands over nothing — the
common case — SHALL restore the app exactly as fully as a tap that navigates.

#### Scenario: A signal that turns out to carry nothing still restores the app

- **WHEN** the app is brought forward and the hand-over check finds nothing pending, or finds
  something it declines to act on because it is stale, unrecognized, or arrives while the user
  is signed out
- **THEN** the app is nonetheless fully usable, with no dependence on that check's outcome

#### Scenario: Repeated arrivals stay safe

- **WHEN** several foreground signals arrive for the same arrival, or the user taps
  notifications repeatedly
- **THEN** each is harmless: the app is restored, nothing is duplicated on screen, and no
  navigation happens that the hand-over rules did not call for
