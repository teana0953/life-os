## ADDED Requirements

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

The dashboard SHALL surface a load or save failure of the weight goal as an error state rather than crashing, and an authentication failure (401) SHALL surface a re-authentication exit consistent with the other screens.

#### Scenario: A load failure shows an error state
- **WHEN** loading the weight goal fails
- **THEN** the goal card / dashboard shows an error state rather than crashing
