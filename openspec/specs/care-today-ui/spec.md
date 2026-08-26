# care-today-ui Specification

## Purpose
TBD - created by archiving change add-care-today-ui. Update Purpose after archive.

## Requirements

### Requirement: Reach the Today care checklist from the health module

The health 更多 (More) tab SHALL present a Today-care entry (distinct from the manage entry)
that navigates to the Today care checklist.

#### Scenario: The More tab opens the Today checklist
- **WHEN** the user taps the Today-care entry in the 更多 tab
- **THEN** the Today care checklist opens showing today's date

### Requirement: Show today's care slots as a focus + grouped checklist

The screen SHALL present today's slots with a focus card for the most-urgent slot and grouped
sections for overdue, later (pending), and done; when there are no pending or overdue slots it
SHALL show an all-done celebration; when there are no schedules today it SHALL show an
empty-state guide.

#### Scenario: The focus card shows the most-urgent slot
- **WHEN** there are overdue and/or pending slots
- **THEN** the focus card shows the earliest overdue slot, or if none is overdue, the earliest pending slot

#### Scenario: Slots are grouped by status
- **WHEN** today has slots of different statuses
- **THEN** overdue slots, pending slots, and done/skipped/missed slots appear in their respective sections

#### Scenario: All done shows a celebration
- **WHEN** no slot is pending or overdue
- **THEN** an all-done celebration is shown instead of a focus card

#### Scenario: No schedules shows a guide
- **WHEN** there are no care slots today
- **THEN** an empty-state guide is shown, not a blank page

### Requirement: Mark a slot done or skipped inline

The screen SHALL let the user mark a pending or overdue slot done or skipped inline; the change
SHALL be reflected (the slot moves to done/skipped) and SHALL stop that reminder's nag.

#### Scenario: Marking a slot done reflects and stops the nag
- **WHEN** the user taps Done on a pending or overdue slot
- **THEN** the slot is recorded done (moving to the done section) so its reminder no longer nags

#### Scenario: Marking a slot skipped is recorded
- **WHEN** the user taps Skip on a pending or overdue slot
- **THEN** the slot is recorded skipped

#### Scenario: A mark failure keeps the list and is actionable
- **WHEN** marking a slot fails for a non-auth reason
- **THEN** a localized error is shown, the existing list is kept, and the user can retry

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

### Requirement: Surface today's care on the health overview

The health module's 總覽 (Overview, the default tab) SHALL present a today-care summary at the
top of its content that reflects today's care urgency and lets the user act without leaving the
overview. When there are care schedules it SHALL also offer a way to reach care-reminder
management; when there are NO care schedules today it SHALL show a slim setup prompt that opens
care-reminder management (rather than showing nothing), so a user with no reminders can still
reach setup from the overview. It SHALL show nothing while it has never loaded and its first load
is still in flight; a first load that fails SHALL instead say so and offer a retry. Once a summary has loaded it SHALL keep showing it through a later reload,
whether that reload is in flight or has failed, so an automatic refresh never empties the
top of the overview.

#### Scenario: Overdue care shows an urgent summary
- **WHEN** today has an overdue care slot
- **THEN** the overview shows a care summary at the top marked as urgent, presenting the earliest overdue slot with inline done/skip

#### Scenario: Pending-only care shows what's next
- **WHEN** today has pending but no overdue slots
- **THEN** the overview care summary presents the earliest pending slot as "up next" with an inline done action

#### Scenario: All-done shows a celebration
- **WHEN** today has care schedules but no pending or overdue slot
- **THEN** the overview care summary shows an all-done celebration

#### Scenario: The summary offers management access
- **WHEN** the overview care summary is shown for a day that has care schedules
- **THEN** it presents a manage entry that opens care-reminder management

#### Scenario: No schedules shows a setup prompt, not nothing
- **WHEN** today has no care schedules and today's care has loaded
- **THEN** the overview shows a slim setup prompt that opens care-reminder management, instead of hiding the card entirely

#### Scenario: A first load still in flight shows nothing
- **WHEN** today's care is loading and has never loaded before
- **THEN** no care card or setup prompt is shown on the overview and the rest of the overview is unaffected

#### Scenario: A failed refresh keeps the summary and marks it
- **WHEN** today's care has loaded and a later reload fails
- **THEN** the summary stays on screen, reported as not refreshed, with a retry — the top card
  of the overview does not become silently stale, which is what it did before

#### Scenario: A day with no schedules keeps its setup prompt through a failed refresh
- **WHEN** today has no care schedules, that loaded successfully, and a later reload fails
- **THEN** the setup prompt stays on screen, reported as not refreshed — having nothing
  scheduled is loaded content, not the absence of content

#### Scenario: A first load that fails says so instead of vanishing
- **WHEN** today's care has never loaded and its first load fails
- **THEN** the overview shows that it could not be loaded, with a retry — rather than the top
  card of the overview simply not being there, which reads as "you have no care today"

#### Scenario: Marking done from the overview does not disrupt the page
- **WHEN** the user taps done on the overview care summary
- **THEN** the slot is recorded done and the summary updates without the overview dropping to a full-page loading state

#### Scenario: A failed inline mark is surfaced, not silent
- **WHEN** an inline mark from the overview summary fails for a non-auth reason
- **THEN** a localized error is surfaced (the summary is not left implying the action succeeded) and the existing summary is kept

#### Scenario: The summary opens the full checklist
- **WHEN** the user taps the overview care summary body
- **THEN** the Today care checklist opens

### Requirement: Correct a completed slot from the done section

The Today care checklist SHALL let the user correct an already-answered slot from its done
section: changing the outcome (done or skipped) and, for a completed slot, **the time it was
actually completed**. The correction SHALL be sent to the backend and reflected in the list
without dropping the screen to a full-page loading state. A failure SHALL keep the checklist and
surface a localized error. A correction that does not go through SHALL say so, SHALL NOT discard
what the user already picked, and SHALL offer a way to try again.

#### Scenario: A done row offers a correction entry
- **WHEN** the done section is shown
- **THEN** each of its rows offers a way to correct that record, carrying a text label for assistive technology rather than an unlabelled icon

#### Scenario: The correction sheet can be dismissed accessibly
- **WHEN** the correction sheet is open
- **THEN** it offers a reachable dismiss control, not only the scrim and the system back gesture

#### Scenario: Correcting the outcome
- **WHEN** the user picks a different outcome (done or skipped) for a completed slot
- **THEN** the record is updated and the row reflects the new outcome

#### Scenario: A missed slot can be corrected from the same place
- **WHEN** the row is one the system recorded as missed
- **THEN** it offers the same correction entry and can be set to done or skipped — missed is derived, never chosen, and with earlier days read-only on the history screen this is where a miss gets corrected

#### Scenario: Skipping never carries a completion time
- **WHEN** the user corrects a slot to skipped
- **THEN** no completion time is submitted with it — a skip never completed

#### Scenario: Correcting the completion time
- **WHEN** the user picks a different completion time for a completed slot
- **THEN** that time is recorded as when the slot was completed, rather than the moment of the correction

#### Scenario: The completion time is sent as an absolute instant
- **WHEN** a completion time is submitted
- **THEN** it is combined with that slot's own calendar date (not "today") and sent as an absolute instant carrying its timezone offset, so a correction made either side of midnight lands on the right day

#### Scenario: Correcting does not blank the screen
- **WHEN** a correction is in flight
- **THEN** the checklist stays visible, with only the affected row showing progress

#### Scenario: A failed correction keeps the list, keeps what the user picked, and offers a retry
- **WHEN** a correction fails for a non-auth reason
- **THEN** the existing checklist is kept, a localized error is surfaced with a way to try again, and the outcome and time the user had already chosen are not discarded

#### Scenario: A correction dropped by the in-flight guard is not silent and not reported as broken
- **WHEN** a correction is submitted while another one is already in flight, so it is dropped
- **THEN** the user is told it was not applied and offered a retry — worded as "not applied", not as something having gone wrong, since nothing failed

### Requirement: Show completion times in the viewer's local time

A slot's recorded completion time SHALL be shown as a local time-of-day, never as the raw
timestamp the backend serializes.

#### Scenario: A done row shows a local time
- **WHEN** a done row has a recorded completion time
- **THEN** it is displayed as a local time of day

#### Scenario: A missing or unreadable completion time falls back
- **WHEN** a done row has no recorded completion time, or one that cannot be read
- **THEN** the row falls back to the slot's scheduled time rather than showing nothing or an error

#### Scenario: Malformed stored values never crash the correction sheet
- **WHEN** a slot carries a scheduled time or date the app cannot parse
- **THEN** opening its correction sheet still works, falling back rather than throwing

#### Scenario: A slot whose date cannot be read submits no completion time
- **WHEN** a slot's calendar date cannot be parsed
- **THEN** the completion-time row is disabled and shows no time, and submitting sends no completion time at all — rather than pinning it to a substituted date, which would file the record under the wrong day

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

### Requirement: Today's care shows the dose quantity with the dose, for medication only

Wherever the Today care checklist (its pending queue row, its focus card, and its completed
group) or the health-overview today-care summary presents a medication slot's dose, it SHALL
present the dose quantity together with the free-text dose rather than the free-text dose
alone: the quantity as a unit-less multiplier (`×N`), followed by the free-text dose when the
slot has one. A whole-number quantity SHALL render without a trailing decimal, and no invented
unit word SHALL be added, because the stored quantity carries no unit. A medication slot with
no free-text dose SHALL still show its quantity, so the dose line is no longer omitted for
slots that only have a quantity. A non-medication slot SHALL show no dose line at all, in every
one of these presentations, because its quantity field is not user-editable and only ever
carries the backend's default value.

#### Scenario: A checklist slot shows quantity and dose together
- **WHEN** a Today slot is medication with a dose quantity of 2 and a free-text dose of `5mg`
- **THEN** the slot's dose line reads `×2 · 5mg`, in its pending-queue row, its focus card, and
  its completed-group row alike

#### Scenario: The overview summary shows quantity and dose together
- **WHEN** the overview today-care summary presents a medication slot with a dose quantity and
  a free-text dose
- **THEN** its dose line shows the quantity and the free-text dose together, in the same form
  as the checklist

#### Scenario: A medication slot with only a quantity still shows a dose line
- **WHEN** a presented medication slot has a dose quantity but no free-text dose
- **THEN** its dose line shows the quantity alone (for example `×2`), rather than being hidden

#### Scenario: A non-medication slot shows no dose line
- **WHEN** a presented slot's category is not medication
- **THEN** no dose line is shown for it, in the checklist or the overview summary, regardless
  of its stored quantity
