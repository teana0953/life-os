## ADDED Requirements

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
