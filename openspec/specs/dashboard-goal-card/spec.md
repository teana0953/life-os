# dashboard-goal-card Specification

## Purpose
TBD - created by archiving change dashboard-goal-card. Update Purpose after archive.
## Requirements
### Requirement: Dashboard is the health module's landing

Opening the health module SHALL show a 總覽 (Overview) dashboard — a scrollable stack of cards — as its landing screen, rather than the daily-log tab shell directly. The dashboard SHALL provide a way to open the daily-log tab shell (今日 / 目標 / 飲水 / 更多) for recording, and the shell SHALL retain all its existing behaviour.

#### Scenario: Opening the health module shows the dashboard
- **WHEN** the user opens the health space from home
- **THEN** the 總覽 dashboard is shown with its cards, and a control to open the daily-log tab shell

#### Scenario: The daily-log shell is reachable from the dashboard
- **WHEN** the user activates the dashboard's "record" entry
- **THEN** the existing tab shell (今日 / 目標 / 飲水 / 更多) is shown, unchanged

### Requirement: Goal card

The dashboard SHALL show a goal card driven by the weight-goal overview. When a target weight and a current weight are available, the card SHALL show the target weight, the current weight, and the remaining weight to target; an achievement ring reflecting the achievement rate (or an empty/indeterminate ring when the rate is null); and the BMI (or a placeholder when BMI is null). When neither height nor target weight has been set, the card SHALL show a prompt to set the goal rather than a row of empty placeholders.

#### Scenario: The card shows the goal figures
- **WHEN** the overview reports target 51, current 52, remaining 1, achievement 75, and BMI 19.1
- **THEN** the goal card shows those target/current/remaining values, a ring at 75%, and BMI 19.1

#### Scenario: An unset profile shows a prompt
- **WHEN** neither height nor target weight has been set
- **THEN** the goal card shows a "set your goal" prompt instead of empty placeholders

#### Scenario: A null achievement or BMI shows no false number
- **WHEN** the overview reports a null achievement rate and a null BMI
- **THEN** the ring is empty/indeterminate and the BMI shows a placeholder rather than a number

### Requirement: Edit height and target weight

The goal card SHALL let the user set their height and target weight through an edit form that does not let the on-screen keyboard hide the inputs. Saving SHALL persist the values (a partial update — an untouched field is left unchanged) and refresh the goal card. A non-positive value SHALL be prevented from being saved.

#### Scenario: Setting height and target weight updates the card
- **WHEN** the user opens the edit form, enters a height and a target weight, and saves
- **THEN** the values are persisted and the goal card refreshes to reflect them

#### Scenario: A non-positive value cannot be saved
- **WHEN** the user enters a zero or negative height or target weight
- **THEN** the value cannot be saved

### Requirement: Goal API errors are surfaced without crashing

The dashboard SHALL surface a load or save failure of the weight goal as an error state rather than crashing, and an authentication failure (401) SHALL surface a re-authentication exit consistent with the other screens. A load failure that leaves nothing to show SHALL take the place of the card's content; one that follows a successful load SHALL leave that content in place and be reported alongside it.

#### Scenario: A load failure shows an error state
- **WHEN** loading the weight goal fails and nothing has loaded before
- **THEN** the goal card / dashboard shows an error state rather than crashing

#### Scenario: A failed reload leaves the goal on screen
- **WHEN** loading the weight goal fails after it has already been shown
- **THEN** the goal stays on screen, reported as not refreshed, rather than being replaced by an error

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

