# hydration Specification

## Purpose
TBD - created by archiving change water-ui. Update Purpose after archive.
## Requirements
### Requirement: Water tab in the daily-log shell

The daily-log shell (the screen reached from the home Health space) SHALL offer a water tab in its bottom navigation alongside the existing Today and Target tabs, and selecting it SHALL show the water screen for the shell's currently viewed day. The water tab SHALL follow the shell's day navigation, so changing the viewed day updates the water screen too.

#### Scenario: The water tab is reachable from the daily-log shell
- **WHEN** the user opens the daily-log shell and taps the water destination in the bottom navigation
- **THEN** the water screen is shown for the shell's currently viewed day, and the Today and Target tabs remain reachable

### Requirement: Log water intake against a daily goal

The water screen SHALL show the day's total water intake and the day's target in millilitres with a progress indicator, and SHALL let the user add water quickly. Quick-add controls SHALL add 250ml and 500ml, and a custom control SHALL let the user enter an arbitrary amount (following the numeric empty-zero convention). A correction control SHALL let the user reduce the total, and the total SHALL never display below zero. When intake exceeds the target the screen SHALL indicate the goal is met (a filled bar) rather than showing a broken or negative bar.

#### Scenario: Quick-adding water raises the day's total
- **WHEN** the user taps the ＋250ml control twice on a day that started at 0
- **THEN** the day's total reads 500ml and the progress indicator advances toward the target

#### Scenario: A custom amount can be entered
- **WHEN** the user opens the custom-amount control and enters 320
- **THEN** 320ml is added to the day's total

#### Scenario: Correcting an over-count never goes below zero
- **WHEN** the day's total is 200ml and the user applies a 250ml correction
- **THEN** the displayed total is 0ml, not negative

#### Scenario: Exceeding the goal shows it as met
- **WHEN** the day's total is above the target
- **THEN** the progress indicator shows the goal met (full), not a negative or overflowing bar

### Requirement: Set the daily water target

The water screen SHALL let the user set the day's water target in millilitres, and after setting it the progress SHALL reflect the new target. A day with no target of its own SHALL show the target carried forward by the backend (or zero if none was ever set), consistent with how the diet portion target behaves.

#### Scenario: Setting the target updates the progress basis
- **WHEN** the user sets the water target to 2000ml with a total of 500ml logged
- **THEN** the screen shows 500 of 2000ml and the bar is one-quarter filled

