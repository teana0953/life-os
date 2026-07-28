## MODIFIED Requirements

### Requirement: Surface today's care on the health overview

The health module's 總覽 (Overview, the default tab) SHALL present a today-care summary at the
top of its content that reflects today's care urgency and lets the user act without leaving the
overview. When there are care schedules it SHALL also offer a way to reach care-reminder
management; when there are NO care schedules today it SHALL show a slim setup prompt that opens
care-reminder management (rather than showing nothing), so a user with no reminders can still
reach setup from the overview. It SHALL show nothing while it has never loaded — including a
first load that fails, which SHALL instead say so and offer a retry once there is a card to
put that in. Once a summary has loaded it SHALL keep showing it through a later reload,
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
