## ADDED Requirements

### Requirement: The food dictionary can be opened without choosing a meal first

The diet screen SHALL offer a way to open the food dictionary directly, without first
choosing which meal the food would go into. Opening it this way SHALL present search and
the user's favorites, and SHALL NOT present any recording controls until the user acts to
record something.

#### Scenario: The dictionary opens from the diet screen
- **WHEN** the user is on the diet screen and uses the dictionary entry
- **THEN** the food dictionary opens, showing search and the user's favorites

#### Scenario: Browsing shows no recording UI
- **WHEN** the user has opened the dictionary and has not chosen any food
- **THEN** no tray and no submit control are shown — the screen is for looking things up

#### Scenario: A looked-up food shows what it counts as
- **WHEN** the user searches or looks at their favorites
- **THEN** each food shows its portion amounts, which is what the user came to find out

#### Scenario: Favorites can be managed from here
- **WHEN** the user is in the dictionary
- **THEN** they can add or remove a food from their favorites

### Requirement: Recording from the dictionary picks the meal at the end

When the user chooses food from the dictionary opened without a meal, the app SHALL let
them build up a selection first and choose the target meal when submitting, rather than
requiring the meal up front. The whole selection SHALL go to the one chosen meal.

#### Scenario: Choosing a food reveals the recording controls
- **WHEN** the user picks a food while browsing the dictionary
- **THEN** the selection tray and the submit control appear, so the intent to record is the
  user's own rather than the screen's default

#### Scenario: The meal is chosen at submit time
- **WHEN** the user submits a selection built from the dictionary
- **THEN** they are asked which meal it belongs to before it is saved

#### Scenario: Nothing is recorded until a meal is chosen
- **WHEN** the user dismisses the meal choice without picking one
- **THEN** nothing is saved and the selection is still there

#### Scenario: The day being viewed is the day recorded
- **WHEN** the user opens the dictionary while viewing a past day and records something
- **THEN** it is recorded against the day they were viewing, not today

### Requirement: Opening a meal's food search is unchanged

Reaching food search from a specific meal SHALL behave exactly as before: the meal is
already known, the screen names it, and submitting saves to it without asking again.

#### Scenario: The per-meal flow still names its target
- **WHEN** the user adds food from a specific meal on the diet screen
- **THEN** the screen identifies that meal, and submitting saves to it without asking which
  meal to use
