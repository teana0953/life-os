## ADDED Requirements

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

#### Scenario: A re-auth requirement is surfaced distinctly
- **WHEN** a Today request returns lifeos 401
- **THEN** the screen surfaces a re-authentication exit distinct from a generic failure
