## ADDED Requirements

### Requirement: Correct a completed slot from the done section

The Today care checklist SHALL let the user correct an already-answered slot from its done
section: changing the outcome (done or skipped) and, for a completed slot, **the time it was
actually completed**. The correction SHALL be sent to the backend and reflected in the list
without dropping the screen to a full-page loading state; a failure SHALL keep the list and
surface a localized error.

#### Scenario: A done row offers a correction entry
- **WHEN** the done section is shown
- **THEN** each of its rows offers a way to correct that record

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

#### Scenario: A failed correction is surfaced and keeps the list
- **WHEN** a correction fails for a non-auth reason
- **THEN** a localized error is surfaced and the existing checklist is kept

#### Scenario: A correction dropped by the in-flight guard is not silent
- **WHEN** a correction is submitted while another one is already in flight, so it is dropped
- **THEN** the user is told it was not applied, rather than the submission appearing to do nothing

### Requirement: Show completion times in the viewer's local time

A slot's recorded completion time SHALL be shown as a local time-of-day, never as the raw
timestamp the backend serializes.

#### Scenario: A done row shows a local time
- **WHEN** a done row has a recorded completion time
- **THEN** it is displayed as a local time of day

#### Scenario: A missing or unreadable completion time falls back
- **WHEN** a done row has no recorded completion time, or one that cannot be read
- **THEN** the row falls back to the slot's scheduled time rather than showing nothing or an error
