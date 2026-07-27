## MODIFIED Requirements

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
