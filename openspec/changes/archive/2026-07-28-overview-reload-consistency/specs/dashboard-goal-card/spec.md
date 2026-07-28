## ADDED Requirements

### Requirement: An overview card that cannot refresh keeps its content and says so

Every card on the health module's 總覽 (Overview) tab SHALL distinguish two failures that are not the same thing.
Having never loaded, it has nothing to show and SHALL show the failure and a retry in place of
content. Having already loaded, it SHALL keep the content it has, say that it could not be
refreshed, and offer a retry for itself — because the reload is automatic (an import, a return
to the overview), so taking away what the user was reading is a bigger harm than the content
being a few minutes stale. Silence is not an option either: content that failed to refresh
SHALL NOT look identical to content that just refreshed — including while the user's own retry
is running, which has not refreshed anything yet.

#### Scenario: A failed refresh keeps the content and marks it
- **WHEN** a card that is already showing content fails to reload
- **THEN** it keeps showing that content, marked as not refreshed, with a retry — the overview
  does not collapse and nothing the user was reading is taken away

#### Scenario: A first load that fails shows the failure instead of content
- **WHEN** a card that has never loaded fails to load
- **THEN** it shows the failure and a retry, because it has no content to keep

#### Scenario: Retry reloads only its own card
- **WHEN** the user retries from one card
- **THEN** only that card's data is reloaded — cards each have their own source, so one
  failing says nothing about the others

#### Scenario: A refresh in flight is not a failure
- **WHEN** a card that is already showing content is reloading
- **THEN** it keeps showing that content with no failure marking

#### Scenario: A retry in flight keeps the marking
- **WHEN** the user presses a card's retry and that reload is still running
- **THEN** the marking stays on screen with its retry disabled and visibly running — a marking
  that disappears on the press reports "refreshed" about a request that has not landed and may
  yet fail, which is the same silence this requirement exists to remove

#### Scenario: A successful retry clears the marking
- **WHEN** a retry succeeds
- **THEN** the card shows the fresh content with no failure marking

#### Scenario: The whole marking is the retry
- **WHEN** the user taps the marking anywhere — its icon, its copy, or its button
- **THEN** that card reloads; the marking is one target, not a small button beside a row of dead
  space where the user aims first

#### Scenario: The marking is reachable and legible
- **WHEN** a screen-reader user reaches a card's marking, or any user reads its retry
- **THEN** the marking is one control that names the card it belongs to — four cards failing at
  once give four distinguishable retries, not four identical ones — and its retry text meets the
  WCAG AA 4.5:1 contrast floor against the card behind it

#### Scenario: A 401 is not handled by the card
- **WHEN** a card's load fails with an authentication failure
- **THEN** the card does not present its own error; the overview's re-authentication exit takes
  over, as it already does

## MODIFIED Requirements

### Requirement: Goal API errors are surfaced without crashing

The dashboard SHALL surface a load or save failure of the weight goal as an error state rather than crashing, and an authentication failure (401) SHALL surface a re-authentication exit consistent with the other screens. A load failure that leaves nothing to show SHALL take the place of the card's content; one that follows a successful load SHALL leave that content in place and be reported alongside it.

#### Scenario: A load failure shows an error state
- **WHEN** loading the weight goal fails and nothing has loaded before
- **THEN** the goal card / dashboard shows an error state rather than crashing

#### Scenario: A failed reload leaves the goal on screen
- **WHEN** loading the weight goal fails after it has already been shown
- **THEN** the goal stays on screen, reported as not refreshed, rather than being replaced by an error
