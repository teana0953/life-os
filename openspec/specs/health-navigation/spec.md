# health-navigation Specification

## Purpose
TBD - created by archiving change health-nav-restructure. Update Purpose after archive.
## Requirements
### Requirement: The health module uses a persistent bottom navigation

The health module SHALL present a persistent bottom navigation with four destinations — overview, record, trends, and more — over a single scaffold, so the overview and recording are always one tap apart. Entering the module SHALL land on the overview.

#### Scenario: Landing shows the overview with recording one tap away
- **WHEN** the user opens the health module
- **THEN** it lands on the overview, and the record, trends, and more destinations are each one tap away in the bottom navigation

### Requirement: The record tab is a flat tracker hub

The record destination SHALL list every day-keyed tracker — food, water, vitals, exercise, bowel, and menstrual — as a tile, each opening its screen for today, with no nested overflow menu.

#### Scenario: Every tracker is one tap from the record hub
- **WHEN** the user selects the record tab
- **THEN** a tile for each of food, water, vitals, exercise, bowel, and menstrual is shown, and tapping one opens that tracker's screen

### Requirement: The diet screen carries its own day and target

The diet screen SHALL provide its own day navigation and expose the daily portion target as an in-screen action (not a separate tab or hub tile).

#### Scenario: The daily target is reached from within the diet screen
- **WHEN** the user opens the food tracker and activates the target action
- **THEN** the daily target screen opens

