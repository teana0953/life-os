# vitals Specification

## Purpose
TBD - created by archiving change vitals-ui. Update Purpose after archive.
## Requirements
### Requirement: Vitals tab in the daily-log shell

The daily-log shell SHALL offer the vitals tracker via its More overflow menu (not a dedicated bottom-navigation tab), and selecting it SHALL show the vitals screen for the shell's currently viewed day. The vitals screen SHALL follow the shell's day navigation, so changing the viewed day updates the vitals screen too.

#### Scenario: The vitals tracker is reachable from the daily-log shell
- **WHEN** the user opens the daily-log shell, taps the More destination in the bottom navigation, and selects the vitals tracker
- **THEN** the vitals screen is shown for the shell's currently viewed day, and the Today, Target, and Water tabs remain reachable in the bottom navigation

### Requirement: Record the day's vitals

The vitals screen SHALL let the user record, for the viewed day, their weight and body fat (each optional), and add any number of blood-pressure readings (systolic, diastolic, and an optional pulse), blood-glucose readings (a label and a value), and blood-oxygen readings (an SpO₂ percentage and an optional pulse), then save them together. Every reading SHALL also carry a time (HH:mm), shown and editable per reading via a time control; a newly added reading SHALL default its time to the current time. Each reading list SHALL support adding a reading, editing a reading's fields (including its time), and removing a reading. Saving SHALL upsert the whole day's record; while saving the save control SHALL be disabled; the save control SHALL be enabled only when there are unsaved edits; and a save failure SHALL be surfaced without losing the entered values.

#### Scenario: Adding and saving readings
- **WHEN** the user adds a blood-pressure reading (120/80), a glucose reading ("餐前" 95), sets weight 65.5, and taps save
- **THEN** the day's record is saved with that weight, blood-pressure reading, and glucose reading, each reading carrying a time

#### Scenario: A newly added reading defaults to the current time
- **WHEN** the user adds a reading to any list
- **THEN** that reading shows a non-empty time (the current time), which the user can change via the time control

#### Scenario: Editing a reading's time counts as an unsaved edit
- **WHEN** the user changes a reading's time on a freshly loaded day
- **THEN** the save control becomes enabled

#### Scenario: Removing a reading
- **WHEN** the user removes a reading from one of the lists
- **THEN** that reading is no longer shown and is not part of the saved record

#### Scenario: Save is gated on unsaved edits
- **WHEN** the screen is showing a freshly loaded day with no edits
- **THEN** the save control is disabled until the user changes something

#### Scenario: A save failure is surfaced
- **WHEN** saving the day's vitals fails
- **THEN** the user is shown a failure message and the entered values are still present

