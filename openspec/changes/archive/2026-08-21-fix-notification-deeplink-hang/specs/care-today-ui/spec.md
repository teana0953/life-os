## MODIFIED Requirements

### Requirement: Errors are localized, distinguishable, and recoverable

Failures SHALL surface localized messages distinguishing a lifeos re-auth requirement from a
general failure — never a crash, never losing the list.

Waiting SHALL also end. A Today load that does not return within a bounded time SHALL resolve
into the recoverable failure state rather than leaving the screen on an indefinite loading
indicator, so the user always has a control to act on. A load that is skipped because an
earlier one is still in flight SHALL NOT be able to leave the screen loading forever: once the
bound elapses, the screen offers a retry, and retrying SHALL issue a new request rather than
being discarded.

#### Scenario: A re-auth requirement is surfaced distinctly
- **WHEN** a Today request returns lifeos 401
- **THEN** the screen surfaces a re-authentication exit distinct from a generic failure

#### Scenario: A request that never returns ends as a retryable failure
- **WHEN** a Today request has been in flight past the bound without returning
- **THEN** the screen leaves the loading state and shows the localized generic failure with a
  retry control, rather than continuing to show a loading indicator indefinitely

#### Scenario: Retrying after a stalled request actually sends a request
- **WHEN** the user retries after a stalled load
- **THEN** a new Today request is issued — the retry is not discarded because the stalled one
  is still considered in flight

## REMOVED Requirements

### Requirement: A care reminder notification lands on the actionable checklist

**Reason**: Its rule "a notification carrying no explicit target opens the Today care
checklist" is the defect behind issue #193 — every push type (budget alerts, test pushes)
arrives without a target, so every one of them landed on 今日照護, a page unrelated to what
the notification said. The requirement is replaced rather than edited because the scenario
that encoded the default is being reversed, not refined.

**Migration**: Replaced by "A care reminder notification identifies Today as its own
destination" below, which keeps the care-reminder outcome and drops the blanket default.

## ADDED Requirements

### Requirement: A care reminder notification identifies Today as its own destination

Tapping a **care reminder** push notification SHALL open the Today care checklist (the place to
act on it), not the app root. The checklist SHALL be reached because that notification
identified it as its own destination — a notification that is not about care SHALL NOT land
here, and no destination SHALL be assumed for a notification that carries none.

Arriving from a notification SHALL leave the screen in a state the user can act on: today's
slots, the localized failure state with a retry, or the re-authentication exit — never an
indefinite loading indicator, and never a page unrelated to the notification.

#### Scenario: Tapping a care notification opens Today
- **WHEN** the user taps a care reminder notification
- **THEN** the app opens the Today care checklist at the app's actual route, not the app root

#### Scenario: A notification that is not about care does not open Today
- **WHEN** the user taps a notification that is not a care reminder
- **THEN** the Today care checklist is not opened

#### Scenario: Arriving from a notification always leaves something to act on
- **WHEN** the Today checklist is opened from a notification and its load does not return
- **THEN** the screen ends on the retryable failure state rather than an indefinite loading
  indicator, so the user is never left with a screen that neither shows the checklist nor
  offers a way forward

#### Scenario: Tapping the notification again recovers a stuck screen
- **WHEN** the Today checklist opened from a notification is stuck without content, and the
  user taps the notification again
- **THEN** a fresh Today request is issued and the screen updates — the second tap is not a
  no-op
