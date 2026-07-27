## MODIFIED Requirements

### Requirement: A care history screen listing past care records

The app SHALL provide a care history screen, reachable from the care management and Today care
screens, that presents a selectable period (e.g. 7 / 30 / 90 days) as a **list** of the period's
care slots grouped by day. The screen SHALL handle empty, loading, and re-auth states without
crashing, and SHALL offer navigation back into the care context (Today care and care management)
so it is not a dead-end leaf.

#### Scenario: Reaching the history screen
- **WHEN** the user taps the history entry on the care management or Today care screen
- **THEN** the care history screen opens

#### Scenario: The list groups slots by day
- **WHEN** the screen has loaded data
- **THEN** each day that has care slots is a group listing that day's slots with their time, title, and status

#### Scenario: Days with nothing scheduled are omitted
- **WHEN** the period contains days with no scheduled care
- **THEN** those days are not rendered as groups

#### Scenario: The screen has no chart mode
- **WHEN** the care history screen is shown
- **THEN** no list/chart mode switch is offered — adherence visualization lives on the health trends tab

#### Scenario: Leaving the history screen for the care context
- **WHEN** the user opens the screen's overflow menu
- **THEN** entries to the Today care screen and the care management screen are offered, and nothing else — no non-interactive note

#### Scenario: Switching the period reloads without blanking
- **WHEN** the user changes the period
- **THEN** the screen reloads care records for the corresponding date range (ending today, inclusive), keeping the current content visible with a progress indicator rather than dropping to a full-page spinner

#### Scenario: Empty, loading, and auth states
- **WHEN** every day in the period has no scheduled care, or the first load is in flight, or the request needs re-auth
- **THEN** the screen shows an empty guide, a loading state, or a re-auth exit respectively

#### Scenario: The empty state always offers a next step
- **WHEN** the period is empty
- **THEN** going to care management is offered at every period length — a user with no care items at all should not have to widen the period twice to reach the only action that helps them

#### Scenario: The empty state offers a longer period until the longest
- **WHEN** the period is empty and a longer period is available
- **THEN** widening the period is offered as the primary action, and it is unavailable while its own reload is in flight so a fast double tap cannot skip a period

#### Scenario: The longest empty period explains itself
- **WHEN** the period is empty and already the longest available
- **THEN** no widen action is offered and the wording says there are no care items yet, rather than describing the period as empty

#### Scenario: A failed load says which period failed
- **WHEN** the load fails
- **THEN** the error names the period that failed and is styled as an error, matching the care adherence card — so the retained period selector reads as a way out

#### Scenario: Period controls wait for the sign-in token
- **WHEN** the screen is shown before its sign-in token has resolved
- **THEN** the period selector and the widen action do not issue a request, rather than sending an unauthenticated one and dropping the user into a spurious re-authenticate exit

### Requirement: Edit a past care record from the history list

The care history screen SHALL let the user change **today's** listed slots' outcome to done or
skipped; slots from earlier days SHALL be read-only, since corrections belong on the Today care
checklist. The read-only rows SHALL say why. The change SHALL be sent to the backend and reflected
in the list without dropping the screen to a full-page loading state; a failure SHALL keep the list
and surface a localized error.

#### Scenario: Editing today's slot updates it
- **WHEN** the user picks a new outcome (done or skipped) for a slot dated today
- **THEN** the record is updated and the list reflects the new status

#### Scenario: Earlier days are read-only and say so
- **WHEN** a listed slot is dated before today
- **THEN** it offers no edit affordance, tapping it does not open the edit sheet, and its day group carries a short note that only today can be edited

#### Scenario: The edit affordance is announced
- **WHEN** an editable row is rendered
- **THEN** its edit control carries a text label for assistive technology, rather than being an unlabelled icon

#### Scenario: The edit sheet can be dismissed accessibly
- **WHEN** the edit sheet is open
- **THEN** it offers a reachable dismiss control, not only the scrim and the system back gesture

#### Scenario: Editing does not blank the screen
- **WHEN** an edit is in flight
- **THEN** the list stays visible (no full-page loading state)

#### Scenario: A failed edit is surfaced and keeps the list
- **WHEN** an edit fails for a non-auth reason
- **THEN** a localized error is surfaced and the existing list is kept

#### Scenario: A reload failing after a successful edit still keeps the list
- **WHEN** the edit itself succeeds but the follow-up refresh fails for a non-auth reason
- **THEN** the list is kept (the edit already happened) with a localized error, rather than dropping to an error state

#### Scenario: A missed record dated today can be corrected
- **WHEN** the user edits a slot recorded as missed, dated today
- **THEN** it can be set to done or skipped (missed is derived, never chosen)
