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

#### Scenario: A re-auth requirement is surfaced distinctly
- **WHEN** a Today request returns lifeos 401
- **THEN** the screen surfaces a re-authentication exit distinct from a generic failure

### Requirement: Surface today's care on the health overview

The health module's 總覽 (Overview, the default tab) SHALL present a today-care summary at the
top of its content that reflects today's care urgency and lets the user act without leaving the
overview. It SHALL NOT be shown when there are no care schedules today.

#### Scenario: Overdue care shows an urgent summary
- **WHEN** today has an overdue care slot
- **THEN** the overview shows a care summary at the top marked as urgent, presenting the earliest overdue slot with inline done/skip

#### Scenario: Pending-only care shows what's next
- **WHEN** today has pending but no overdue slots
- **THEN** the overview care summary presents the earliest pending slot as "up next" with an inline done action

#### Scenario: All-done shows a celebration
- **WHEN** today has care schedules but no pending or overdue slot
- **THEN** the overview care summary shows an all-done celebration

#### Scenario: No schedules hides the summary
- **WHEN** today has no care schedules
- **THEN** no care summary is shown on the overview and the existing goal card is the first card

#### Scenario: Marking done from the overview does not disrupt the page
- **WHEN** the user taps done on the overview care summary
- **THEN** the slot is recorded done and the summary updates without the overview dropping to a full-page loading state

#### Scenario: A failed inline mark is surfaced, not silent
- **WHEN** an inline mark from the overview summary fails for a non-auth reason
- **THEN** a localized error is surfaced (the summary is not left implying the action succeeded) and the existing summary is kept

#### Scenario: The summary opens the full checklist
- **WHEN** the user taps the overview care summary body
- **THEN** the Today care checklist opens

### Requirement: A care reminder notification lands on the actionable checklist

Tapping a care reminder push notification SHALL open the Today care checklist (the place to act
on it), not the app root.

#### Scenario: Tapping a care notification opens Today
- **WHEN** the user taps a care reminder notification
- **THEN** the app opens the Today care checklist at the app's actual route (the hash form the app's URL strategy uses), not the app root

#### Scenario: A notification without an explicit target defaults to Today
- **WHEN** a notification carries no explicit target url
- **THEN** tapping it opens the Today care checklist rather than the app root

