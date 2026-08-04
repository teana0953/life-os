## MODIFIED Requirements

### Requirement: Record the day's vitals

The vitals screen SHALL let the user record, for the viewed day, their weight and body fat (each optional), and add any number of blood-pressure readings (systolic, diastolic, and an optional pulse), blood-glucose readings (a label and a value), and blood-oxygen readings (an SpO₂ percentage and an optional pulse), then save them together. Every reading SHALL also carry a time (HH:mm), shown and editable per reading via a time control that SHALL present a 24-hour clock regardless of the device locale, matching the 24-hour form the time is stored and displayed in; a newly added reading SHALL default its time to the current time. Each reading list SHALL support adding a reading, editing a reading's fields (including its time), and removing a reading. Saving SHALL upsert the whole day's record; while saving the save control SHALL be disabled; the save control SHALL be enabled only when there are unsaved edits; and a save failure SHALL be surfaced without losing the entered values.

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

#### Scenario: The time control matches the format the time is shown in

- **WHEN** a user on a 12-hour locale opens a reading's time control
- **THEN** it offers a 24-hour clock — otherwise they would pick "9:30 PM"
  and the reading would read back "21:30", with nothing indicating why

